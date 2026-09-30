extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const Reputation = preload("res://scripts/session/reputation_state.gd")
const Feedback = preload("res://scripts/ui/feedback_coordinator.gd")
const MAIN = preload("res://scenes/Main.tscn")
const SHIELD_PATH := ["slow_salsa_plus", "taco_power_1", "warm_welcome", "last_stand", "safety_shield"]
const BOOST_PATH := ["last_stand", "slow_salsa", "taco_power_1", "patient_service", "reputation_boost"]
# Keep the unshielded/overkill regression free of active survival effects.
const CONTINUOUS_PATH := ["last_stand", "slow_salsa", "chain4_boost", "warm_welcome", "taco_power_2"]

# Only seed injection; all offers, storage and signals use the real selector.
class SeededSelector extends UpgradeSelector:
	func start_run(_seed: int) -> Dictionary:
		return super.start_run(2)


class ObservedReputation extends ReputationState:
	var selection_calls := 0

	func apply_selection_effect(number: int, upgrade_id: String, effect) -> Dictionary:
		selection_calls += 1
		return super.apply_selection_effect(number, upgrade_id, effect)


# Observe at entry to spawn, so granting after spawn would fail the test.
class ObservedField extends LaneField:
	var read_reputation: Callable
	var boss_spawn_snapshot: Dictionary = {}

	func spawn_runner(lane: int, speed: float, label: String = "M", id: String = "monster", hunger: float = 30.0) -> LaneRunner:
		if id == "boss_big_glutton":
			boss_spawn_snapshot = read_reputation.call()
		return super.spawn_runner(lane, speed, label, id, hunger)


var checks := 0
var failures := 0
var content: Dictionary
var effects: Dictionary = {}


func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "real content validates")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	for upgrade in content["upgrades"]:
		effects[upgrade["id"]] = upgrade["effect"]
	_test_boost()
	_test_invalid_selections()
	_test_shield_and_breaches()
	_test_reentrancy()
	_test_zero_damage()
	_test_maximum_feedback()
	await _test_main_boost_and_payloads()
	await _test_boss(SHIELD_PATH, true, 100.0)
	await _test_boss(CONTINUOUS_PATH, false, 100.0)
	await _test_boss(CONTINUOUS_PATH, false, 30.0)
	await _test_inconsistent_fifth_selection()
	if failures == 0:
		print("UPG-02d tests passed: %d checks; one-shots, validation, dedupe/reentrancy, HUD/low threshold, public fifth selections and effective boss damage." % checks)
	else:
		push_error("UPG-02d tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_boost() -> void:
	for starting in [100.0, 60.0, 22.0]:
		var state := Reputation.new(content)
		_expect(state.snapshot() == {"current": 100.0, "maximum": 100.0, "defeated": false, "shield_charges": 0, "extra_life_charges": 0}, "snapshot exposes exactly run state")
		if starting < 100.0:
			state.apply_damage(100.0 - starting)
		var maxima: Array[Dictionary] = []
		var changes: Array[Dictionary] = []
		state.maximum_changed.connect(func(p: Dictionary): maxima.append(p))
		state.reputation_changed.connect(func(p: Dictionary): changes.append(p))
		var before_effect: Dictionary = effects["reputation_boost"].duplicate(true)
		var result := state.apply_selection_effect(3, "reputation_boost", effects["reputation_boost"])
		_expect(result["ok"] and state.current == starting and state.maximum == 115.0, "boost raises only maximum")
		_expect(maxima.size() == 1 and changes.is_empty(), "boost emits maximum once and no current delta")
		_expect(maxima[0]["before_maximum"] == 100.0 and maxima[0]["delta_maximum"] == 15.0, "maximum payload reports actual maximum change")
		_expect(maxima[0]["selection_number"] == 3 and maxima[0]["upgrade_id"] == "reputation_boost", "maximum payload identifies selection")
		for key in state.snapshot():
			_expect(maxima[0][key] == state.snapshot()[key], "maximum payload includes %s" % key)
		_expect(effects["reputation_boost"] == before_effect, "effect input remains intact")
		_error(state.apply_selection_effect(3, "reputation_boost", effects["reputation_boost"]), "DUPLICATE_SELECTION")
		_error(state.apply_selection_effect(3, "safety_shield", effects["safety_shield"]), "DUPLICATE_SELECTION")
		_expect(state.maximum == 115.0 and state.shield_charges == 0 and maxima.size() == 1, "dedupe is by selection number, not upgrade ID")
		var fresh := Reputation.new(content)
		_expect(fresh.apply_selection_effect(3, "reputation_boost", effects["reputation_boost"])["ok"], "selection tracking belongs to each run")
		if starting == 100.0:
			state.restore(50.0)
			_expect(state.current == 115.0, "restore uses new maximum")
	var fractional := Reputation.new(content)
	fractional.apply_damage(8.5)
	fractional.apply_selection_effect(1, "fractional", _effect("reputation_max", 0.25))
	_expect(fractional.current == 91.5 and fractional.maximum == 100.25, "boost preserves float precision without healing")


func _test_invalid_selections() -> void:
	var state := Reputation.new(content)
	var before := state.snapshot()
	_error(state.apply_selection_effect(0, "reputation_boost", effects["reputation_boost"]), "INVALID_SELECTION_NUMBER")
	_error(state.apply_selection_effect(-1, "reputation_boost", effects["reputation_boost"]), "INVALID_SELECTION_NUMBER")
	for id in ["", "  "]:
		_error(state.apply_selection_effect(1, id, effects["reputation_boost"]), "INVALID_UPGRADE_ID")
	for invalid in [null, [], "effect", 1, true]:
		_error(state.apply_selection_effect(1, "bad", invalid), "INVALID_EFFECT")
	for id in ["taco_power_2", "slow_salsa", "last_stand", "warm_welcome", "patient_service"]:
		_error(state.apply_selection_effect(1, id, effects[id]), "NOT_ONE_SHOT")
	for stat in ["reputation_max", "reputation_shield_charges"]:
		for invalid in [0, -1, NAN, INF, -INF, null, true, "1", [], {}]:
			_error(state.apply_selection_effect(1, "bad", _effect(stat, invalid)), "INVALID_AMOUNT")
			_expect(state.snapshot() == before, "invalid grant leaves state untouched")
		var wrong := _effect(stat, 1)
		wrong["operation"] = "multiply"
		_error(state.apply_selection_effect(1, "bad", wrong), "INVALID_EFFECT")
		wrong = _effect(stat, 1)
		wrong["type"] = "conditional_satisfaction"
		_error(state.apply_selection_effect(1, "bad", wrong), "INVALID_EFFECT")
	for invalid in [1.5, 9223372036854775808.0]:
		_error(state.apply_selection_effect(1, "bad", _effect("reputation_shield_charges", invalid)), "INVALID_AMOUNT")
	_expect(state.snapshot() == before, "unsupported and malformed effects do not mutate state")
	_expect(state.apply_selection_effect(1, "safety_shield", effects["safety_shield"])["ok"], "invalid inputs never reserve selection number")
	_expect(state.apply_selection_effect(2, "float_shield", _effect("reputation_shield_charges", 1.0))["ok"], "exact integer float accepted")
	_expect(state.shield_charges == 2 and typeof(state.snapshot()["shield_charges"]) == TYPE_INT, "int and float grants stored as int")
	state.apply_damage(1000.0)
	var terminal := state.snapshot()
	for id in ["reputation_boost", "safety_shield"]:
		_error(state.apply_selection_effect(3, id, effects[id]), "RUN_ENDED")
	_error(state.apply_breach(_breach(4)), "RUN_ENDED")
	_expect(state.snapshot() == terminal and state.shield_charges == 2, "terminal run never grants or consumes charges")
	var huge := Reputation.new(content)
	huge.apply_selection_effect(1, "large", _effect("reputation_max", 1e308))
	_error(huge.apply_selection_effect(2, "overflow", _effect("reputation_max", 1e308)), "INVALID_AMOUNT")
	_expect(is_finite(huge.maximum), "maximum cannot overflow")
	var int_limit := Reputation.new(content)
	_expect(int_limit.apply_selection_effect(1, "large_shield", _effect("reputation_shield_charges", 9223372036854775807))["ok"], "representable int64 grant is accepted without a lossy float roundtrip")
	_error(int_limit.apply_selection_effect(2, "overflow", effects["safety_shield"]), "INVALID_AMOUNT")
	_expect(int_limit.shield_charges == 9223372036854775807, "aggregate charges cannot overflow")
	int_limit.apply_breach(_breach(1))
	_expect(int_limit.apply_selection_effect(2, "retry", effects["safety_shield"])["ok"], "rejected overflow does not reserve selection number")


func _test_shield_and_breaches() -> void:
	var state := Reputation.new(content)
	var shields: Array[Dictionary] = []
	var changes: Array[Dictionary] = []
	var endings: Array[Dictionary] = []
	state.shield_consumed.connect(func(p: Dictionary): shields.append(p))
	state.reputation_changed.connect(func(p: Dictionary): changes.append(p))
	state.run_ended.connect(func(p: Dictionary): endings.append(p))
	_expect(state.apply_selection_effect(1, "safety_shield", effects["safety_shield"])["ok"], "shield grant succeeds")
	_error(state.apply_selection_effect(1, "safety_shield", effects["safety_shield"]), "DUPLICATE_SELECTION")
	_expect(state.shield_charges == 1 and shields.is_empty() and changes.is_empty(), "grant is silent and duplicate does not stack")
	_error(state.apply_breach({"spawn_sequence": 1, "monster_id": "unknown"}), "UNKNOWN_BREACH")
	var result := state.apply_breach(_breach(1))
	_damage(result, 10.0, 0.0, true, 10.0)
	_expect(state.current == 100.0 and state.shield_charges == 0, "first positive breach consumes shield without damage")
	_expect(shields.size() == 1 and changes.is_empty() and endings.is_empty(), "shield emits once without reputation or ending signals")
	_expect(shields[0]["spawn_sequence"] == 1 and shields[0]["monster_id"] == "nibbler", "shield payload identifies breach")
	_expect(shields[0]["shield_charges_remaining"] == 0 and shields[0]["prevented_damage"] == 10.0, "shield payload reports remaining charges and raw damage")
	for key in state.snapshot():
		_expect(shields[0][key] == state.snapshot()[key], "shield payload includes %s" % key)
	_error(state.apply_breach(_breach(1)), "DUPLICATE_BREACH")
	_expect(shields.size() == 1 and changes.is_empty(), "duplicate breach has no signals")
	_damage(state.apply_breach(_breach(2)), 10.0, 10.0, false, 0.0)
	_expect(state.current == 90.0 and changes.size() == 1, "next unique breach deals normal damage")
	state.apply_selection_effect(2, "shield_again", effects["safety_shield"])
	_error(state.apply_breach(_breach(1)), "DUPLICATE_BREACH")
	_expect(state.shield_charges == 1, "duplicate cannot consume a subsequently granted shield")
	var overkill := Reputation.new(content)
	overkill.apply_damage(95.0)
	_damage(overkill.apply_breach(_breach(1)), 10.0, 5.0, false, 0.0)
	_expect(overkill.defeated, "overkill reports only current lost before terminal zero")


func _test_reentrancy() -> void:
	var state := Reputation.new(content)
	var repeated: Array[Dictionary] = []
	var replay_selection := func(_p: Dictionary):
		repeated.append(state.apply_selection_effect(1, "reputation_boost", effects["reputation_boost"]))
	state.maximum_changed.connect(replay_selection)
	state.apply_selection_effect(1, "reputation_boost", effects["reputation_boost"])
	_error(repeated[0], "DUPLICATE_SELECTION")
	_expect(state.maximum == 115.0, "selection marked before maximum signal")
	state.maximum_changed.disconnect(replay_selection)
	state.apply_selection_effect(2, "safety_shield", effects["safety_shield"])
	var nested: Array[Dictionary] = []
	var replay_breach := func(_p: Dictionary):
		nested.append(state.apply_breach(_breach(1)))
		nested.append(state.apply_breach(_breach(2)))
	state.shield_consumed.connect(replay_breach)
	var blocked := state.apply_breach(_breach(1))
	_error(nested[0], "DUPLICATE_BREACH")
	_damage(nested[1], 10.0, 10.0, false, 0.0)
	_damage(blocked, 10.0, 0.0, true, 10.0)
	_expect(state.current == 90.0 and state.shield_charges == 0, "different reentrant breach sees already consumed shield")
	_expect(blocked["current"] == 100.0, "outer result remains its own transaction snapshot")
	state.shield_consumed.disconnect(replay_breach)
	var after_damage := func(_p: Dictionary): state.restore(5.0)
	state.reputation_changed.connect(after_damage, CONNECT_ONE_SHOT)
	_damage(state.apply_breach(_breach(3)), 10.0, 10.0, false, 0.0)
	_expect(state.current == 85.0, "damage result does not absorb a reentrant restore")


func _test_zero_damage() -> void:
	var alternate := content.duplicate(true)
	for monster in alternate["monsters"]:
		if monster["id"] == "nibbler":
			monster["reputation_damage"] = 0
	var validated := Registry.new().validate_content(alternate)
	_expect(validated["ok"], "zero-damage fixture passes the real content validator")
	var state := Reputation.new(validated["content"])
	state.apply_selection_effect(1, "safety_shield", effects["safety_shield"])
	var events: Array[String] = []
	state.shield_consumed.connect(func(_p: Dictionary): events.append("shield"))
	state.reputation_changed.connect(func(_p: Dictionary): events.append("current"))
	_damage(state.apply_breach(_breach(1)), 0.0, 0.0, false, 0.0)
	_expect(state.current == 100.0 and state.shield_charges == 1 and events.is_empty(), "zero damage is successful no-op without apply_damage(0)")
	_error(state.apply_breach(_breach(1)), "DUPLICATE_BREACH")


func _test_maximum_feedback() -> void:
	for starting in [22.0, 19.0]:
		var state := Reputation.new(content)
		state.apply_damage(100.0 - starting)
		var feedback := Feedback.new(state.snapshot())
		var cues: Array[String] = []
		feedback.feedback_requested.connect(func(p: Dictionary): cues.append(p["cue_id"]))
		state.maximum_changed.connect(feedback.on_reputation_maximum_changed)
		state.reputation_changed.connect(feedback.on_reputation_changed)
		state.apply_selection_effect(1, "reputation_boost", effects["reputation_boost"])
		_expect(cues == (["low_reputation"] if starting == 22.0 else []), "maximum crossing alerts once; already low stays quiet; no delta")
		state.apply_selection_effect(2, "another_boost", effects["reputation_boost"])
		_expect(cues.count("low_reputation") == (1 if starting == 22.0 else 0), "remaining low does not repeat")
		state.restore(50.0)
		cues.clear()
		state.apply_selection_effect(3, "large_boost", _effect("reputation_max", 300.0))
		_expect(cues == ["low_reputation"], "recovery rearms maximum crossing")


func _test_main_boost_and_payloads() -> void:
	var main = await _create_main()
	var before: Dictionary = main.reputation.snapshot()
	for number in [0, -1, 1, 5, 1.5, "1", null]:
		_error(main._on_upgrade_selected({"selection_number": number, "upgrade_id": "reputation_boost", "is_final_selection": true}), "INVALID_SELECTION")
	_expect(main.reputation.snapshot() == before and not main.boss_has_started, "invalid payload cannot invent selection or boss")
	main.wave_director.wave_completed.emit({"wave_id": "wave_01"})
	var selected: Dictionary = main.upgrade_selector.select_upgrade("last_stand")
	_expect(selected["ok"], "public conditional selection succeeds")
	var forged: Dictionary = selected["selection"].duplicate(true)
	forged["effect"] = _effect("reputation_max", 1000.0)
	_expect(main._on_upgrade_selected(forged)["ok"], "payload effect is ignored for real conditional selection")
	_expect(main.reputation.snapshot() == before and main.reputation.selection_calls == 0, "continuous/conditional selection never calls one-shot API")
	forged["upgrade_id"] = "reputation_boost"
	_error(main._on_upgrade_selected(forged), "SELECTION_ID_MISMATCH")
	_expect(main.reputation.snapshot() == before, "mismatched ID cannot mutate reputation")
	main.queue_free()
	await process_frame
	for starting in [100.0, 22.0]:
		main = await _create_main()
		if starting < 100.0:
			main.reputation.apply_damage(100.0 - starting)
		var events: Array[String] = []
		main.feedback.feedback_requested.connect(func(p: Dictionary): events.append(p["cue_id"]))
		var final := _finish_path(main, BOOST_PATH)
		_expect(main.reputation.current == starting and main.reputation.maximum == 115.0, "real fifth boost does not heal")
		_expect(main.lane_field.boss_spawn_snapshot["maximum"] == 115.0, "boost applied before entering boss spawn")
		_expect(main.hud.reputation_label.text == "Reputación %d / 115" % starting, "HUD maximum signal updates label")
		_expect(main.hud.reputation_bar.max_value == 115.0 and main.hud.reputation_bar.value == starting, "HUD bar uses new maximum without changing current")
		_expect(events.count("low_reputation") == (1 if starting == 22.0 else 0) and not "reputation_delta" in events, "Main wires maximum feedback without false delta")
		var maxima_before: Dictionary = main.reputation.snapshot()
		_error(main._on_upgrade_selected(final), "DUPLICATE_SELECTION")
		_expect(main.reputation.snapshot() == maxima_before, "replayed real boost remains idempotent")
		main.queue_free()
		await process_frame


func _test_boss(path: Array, shield: bool, starting: float) -> void:
	var main = await _create_main(shield)
	var starts: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	main.boss_started.connect(func(_p: Dictionary): starts.append(main.reputation.snapshot()))
	main.boss_encounter_completed.connect(func(p: Dictionary): completions.append(p))
	var final := _finish_path(main, path)
	_expect(starts.size() == 1 and is_instance_valid(main.boss_runner), "fifth selection spawns exactly one real boss")
	_expect(main.lane_field.boss_spawn_snapshot["shield_charges"] == int(shield), "shield is granted BEFORE boss spawn entry")
	_expect(starts[0]["shield_charges"] == int(shield), "boss_started observes granted shield")
	_expect(main.reputation.selection_calls == (1 if shield else 0), "only supported one-shot reaches reputation API")
	_expect(main.reputation.maximum == 100.0 and main.reputation.current == 100.0, "continuous fifth selection keeps reputation neutral")
	if starting < 100.0:
		main.reputation.apply_damage(100.0 - starting)
	var boss: LaneRunner = main.boss_runner
	var sequence := boss.monster_state.spawn_sequence
	var replays: Array[bool] = []
	var replay := func(_p: Dictionary):
		main.lane_field.monster_reached_counter.emit({"spawn_sequence": sequence, "monster_id": "boss_big_glutton"})
		replays.append(true)
	var damage_signal: Signal = main.reputation.shield_consumed if shield else main.reputation.reputation_changed
	damage_signal.connect(replay)
	boss.advance(1000.0)
	damage_signal.disconnect(replay)
	_expect(replays.size() == 1, "Main tolerates a duplicate lane signal before the outer breach result is cached")
	var applied := 0.0 if shield else minf(starting, 40.0)
	_expect(main.reputation.current == starting - applied and main.reputation.shield_charges == 0, "boss consumes shield or applies effective damage")
	_expect(completions.size() == 1, "boss breach completes once even when lethal")
	if completions.size() != 1:
		main.queue_free()
		await process_frame
		return
	_expect(completions[0]["reputation_damage_on_breach"] == 40.0 and completions[0]["reputation_damage"] == applied, "completion distinguishes raw and effective boss damage")
	_damage(main._breach_results_by_sequence[sequence], 40.0, applied, shield, 40.0 if shield else 0.0)
	var saved: Dictionary = main._breach_results_by_sequence[sequence].duplicate(true)
	main.lane_field.monster_reached_counter.emit({"spawn_sequence": sequence, "monster_id": "boss_big_glutton"})
	_expect(main._breach_results_by_sequence[sequence] == saved, "duplicate error never overwrites first successful result")
	main.upgrade_selector.upgrade_selected.emit(final)
	_expect(starts.size() == 1 and completions.size() == 1 and main.boss_runner == boss, "duplicate selection/breach cannot restart boss")
	_expect(main.reputation.current == starting - applied, "duplicates cannot change effective damage")
	_expect(main.wave_director.current_wave_id == "wave_05" and not main.wave_director.has_wave("wave_06"), "boss creates no wave 6")
	main.queue_free()
	await process_frame


func _test_inconsistent_fifth_selection() -> void:
	var main = await _create_main(true)
	# Temporarily deliver final callback manually to test Main's trust boundary.
	var final := _finish_path(main, SHIELD_PATH, true)
	var before: Dictionary = main.reputation.snapshot()
	var forged := final.duplicate(true)
	forged["upgrade_id"] = "reputation_boost"
	forged["effect"] = _effect("reputation_max", 1000.0)
	_error(main._on_upgrade_selected(forged), "SELECTION_ID_MISMATCH")
	_expect(main.reputation.snapshot() == before and not main.boss_has_started, "inconsistent fifth ID grants nothing and cannot spawn boss")
	final["effect"] = _effect("reputation_max", 1000.0)
	_expect(main._on_upgrade_selected(final)["ok"], "consistent identity uses real stored effect despite forged payload effect")
	_expect(main.reputation.maximum == 100.0 and main.reputation.shield_charges == 1 and main.boss_has_started, "real fifth shield takes precedence over forged boost")
	main.queue_free()
	await process_frame


func _create_main(shield_seed: bool = false):
	var main = MAIN.instantiate()
	main.get_node("%LaneField").set_script(ObservedField)
	if shield_seed:
		main.get_node("%UpgradeSelector").set_script(SeededSelector)
	root.add_child(main)
	await process_frame
	# Observe calls while preserving ReputationState's real implementation and wiring.
	var observed := ObservedReputation.new(content)
	for event in main.reputation.get_signal_list():
		for connection in main.reputation.get_signal_connection_list(event["name"]):
			observed.connect(event["name"], connection["callable"])
	main.reputation = observed
	main.lane_field.read_reputation = main.reputation.snapshot
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(p: Dictionary):
		main.wave_director.get_spawned_runner(p["spawn_sequence"]).auto_advance = false)
	main.boss_started.connect(func(_p: Dictionary): main.boss_runner.auto_advance = false)
	return main


func _finish_path(main, path: Array, hold_final: bool = false) -> Dictionary:
	var final: Dictionary = {}
	for i in range(5):
		var wave: Dictionary = content["waves"][i]
		_expect(main.wave_director.start_wave(wave["id"], 0.0)["ok"], "real normal wave starts")
		main.wave_director.advance(1000.0)
		for _entry in wave["spawns"]:
			_expect(main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 1000.0})["ok"], "normal monster resolved by real LaneField")
		_expect(main.wave_director.state == WaveDirector.State.COMPLETED, "real wave completed before offering")
		_expect(not main.boss_has_started, "boss awaits fifth selection")
		if i == 4 and hold_final:
			main.upgrade_selector.upgrade_selected.disconnect(main._on_upgrade_selected)
		var selected: Dictionary = main.upgrade_selector.select_upgrade(path[i])
		_expect(selected["ok"], "pinned public offer contains %s" % path[i])
		final = selected.get("selection", {})
	return final


func _breach(sequence: int) -> Dictionary:
	return {"spawn_sequence": sequence, "monster_id": "nibbler"}


func _effect(stat: String, value) -> Dictionary:
	return {"stat": stat, "operation": "add", "value": value}


func _damage(result: Dictionary, requested: float, applied: float, blocked: bool, prevented: float) -> void:
	_expect(result["ok"], "breach result succeeds")
	_expect(result["damage_requested"] == requested and result["damage_applied"] == applied, "breach explicitly reports requested and effective damage")
	_expect(result["shield_consumed"] == blocked and result["prevented_damage"] == prevented, "breach explicitly reports absorption")


func _error(result: Dictionary, code: String) -> void:
	_expect(not result["ok"] and result.get("error", "") == code, "explicit error %s: %s" % [code, result])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
