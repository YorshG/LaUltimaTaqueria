extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const Reputation = preload("res://scripts/session/reputation_state.gd")
const Resolver = preload("res://scripts/recipes/recipe_resolver.gd")
const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
const Feedback = preload("res://scripts/ui/feedback_coordinator.gd")
const MAIN = preload("res://scenes/Main.tscn")
const DEFENSE_PREFIX := ["slow_salsa_plus", "taco_power_1", "warm_welcome", "last_stand"]

# The production selector still creates every offer and stores every selection.
class SeededSelector extends UpgradeSelector:
	func start_run(_seed: int) -> Dictionary:
		return super.start_run(2)


class ObservedField extends LaneField:
	var reputation: ReputationState
	var boss_spawn_snapshot: Dictionary = {}
	var boss_spawn_multiplier := 0.0

	func spawn_runner(lane: int, speed: float, label: String = "M", id: String = "monster", hunger: float = 30.0) -> LaneRunner:
		if id == "boss_big_glutton":
			boss_spawn_snapshot = reputation.snapshot()
			boss_spawn_multiplier = reputation.reputation_damage_multiplier
		return super.spawn_runner(lane, speed, label, id, hunger)


var failures := 0
var checks := 0
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
	_test_multiplier()
	_test_grants()
	_test_atomic_survival()
	_test_d6_order()
	_test_zero_and_overflow()
	_test_reentrancy()
	_test_veggie_resolution()
	await _test_public_boss("patient_service", 100.0)
	await _test_public_boss("patient_service", 30.0)
	await _test_public_boss("second_chance", 30.0)
	await _test_public_boss("second_chance", 10.0)
	await _test_early_selection()
	await _test_veggie_main()
	await _test_feedback_rearm()
	if failures == 0:
		print("UPG-02e tests passed: %d checks; patient_service, atomic second_chance, D6, reentrancy, public boss selections and veggie 6.5." % checks)
	else:
		push_error("UPG-02e tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_multiplier() -> void:
	var state := Reputation.new(content)
	_expect(state.reputation_damage_multiplier == 1.0, "new run starts with neutral multiplier")
	_expect(state.snapshot() == {"current": 100.0, "maximum": 100.0, "defeated": false,
		"shield_charges": 0, "extra_life_charges": 0}, "snapshot exposes only approved state; ratio/tracking/multiplier stay internal")
	_damage(state.apply_breach(_breach(1)), 10.0, 10.0, 10.0)
	for value in [0.85, 0.85, 0.85, 1, 1.0, 0.5, 0.85]:
		_expect(state.set_reputation_damage_multiplier(value), "positive int/float multiplier accepted")
		_expect(state.reputation_damage_multiplier == float(value), "refresh sets absolute value without compounding")
	for invalid in [0, -1, -0.85, NAN, INF, -INF, null, true, false, "0.85", [], {}]:
		var before := state.snapshot()
		_expect(not state.set_reputation_damage_multiplier(invalid), "invalid multiplier rejected")
		_expect(state.reputation_damage_multiplier == 0.85 and state.snapshot() == before, "invalid refresh has no partial state mutation")
	for fixture in [["nibbler", 10.0, 8.5], ["salsa_tank", 25.0, 21.25],
		["swift_hopper", 15.0, 12.75], ["boss_big_glutton", 40.0, 34.0]]:
		var neutral := Reputation.new(content)
		_damage(neutral.apply_breach(_breach(1, fixture[0])), fixture[1], fixture[1], fixture[1])
		var patient := Reputation.new(content)
		_expect(patient.set_reputation_damage_multiplier(_modifiers(["patient_service"])["reputation_damage_taken"]), "real patient_service derives runtime multiplier")
		_damage(patient.apply_breach(_breach(1, fixture[0])), fixture[1], fixture[2], fixture[2])
		_expect(patient.current == 100.0 - fixture[2], "patient damage retains float precision")
	# Changing the multiplier affects future arrivals of the same content ID.
	var future := Reputation.new(content)
	future.set_reputation_damage_multiplier(0.85)
	_damage(future.apply_breach(_breach(1)), 10.0, 8.5, 8.5)
	future.set_reputation_damage_multiplier(1.0)
	_damage(future.apply_breach(_breach(2)), 10.0, 10.0, 10.0)
	future.set_reputation_damage_multiplier(0.85)
	_damage(future.apply_breach(_breach(3)), 10.0, 8.5, 8.5)
	_expect(future.current == 73.0, "future breaches use current multiplier without caching per monster")


func _test_grants() -> void:
	var state := Reputation.new(content)
	var before := state.snapshot()
	for value in [0, -1, 1.5, NAN, INF, -INF, null, true, "1", [], {}, 9223372036854775808.0]:
		var effect := _life_effect(value, 0.25)
		_error(state.apply_selection_effect(1, "second_chance", effect), "INVALID_AMOUNT")
		_expect(state.snapshot() == before, "invalid life amount cannot grant or mark a selection")
	for ratio in [0, -0.25, 1.01, NAN, INF, -INF, null, true, "0.25", [], {}]:
		_error(state.apply_selection_effect(1, "second_chance", _life_effect(1, ratio)), "INVALID_RESTORE_RATIO")
		_expect(state.snapshot() == before, "invalid ratio preserves state")
	for params in [null, [], {}, {"other": 0.25}]:
		var effect := _life_effect(1, 0.25)
		effect["params"] = params
		_error(state.apply_selection_effect(1, "second_chance", effect), "INVALID_RESTORE_RATIO")
	for field in ["type", "params"]:
		var effect := _life_effect(1, 0.25)
		effect.erase(field)
		_error(state.apply_selection_effect(1, "second_chance", effect), "INVALID_EFFECT" if field == "type" else "INVALID_RESTORE_RATIO")
	for field in ["type", "operation"]:
		var effect := _life_effect(1, 0.25)
		effect[field] = "wrong"
		_error(state.apply_selection_effect(1, "second_chance", effect), "INVALID_EFFECT")
	_expect(state.apply_selection_effect(1, "second_chance", effects["second_chance"])["ok"], "valid grant succeeds after invalid attempts with same selection number")
	_expect(state.extra_life_charges == 1 and typeof(state.snapshot()["extra_life_charges"]) == TYPE_INT, "real grant stores one integer charge")
	var changed_ratio := _life_effect(1, 1.0)
	_error(state.apply_selection_effect(1, "other_id", changed_ratio), "DUPLICATE_SELECTION")
	state.apply_damage(1000.0)
	_expect(state.current == 25.0 and state.extra_life_charges == 0, "duplicate grant cannot replace stored restore ratio")
	state.apply_damage(1000.0)
	_error(state.apply_selection_effect(2, "second_chance", effects["second_chance"]), "RUN_ENDED")
	for value in [1, 1.0]:
		var fresh := Reputation.new(content)
		_expect(fresh.apply_selection_effect(1, "second_chance", _life_effect(value, 1))["ok"], "new run accepts integer int/float amount and ratio 1")
		fresh.apply_damage(1000.0)
		_expect(fresh.current == 100.0 and fresh.extra_life_charges == 0, "ratio 1 restores exactly maximum")
	var huge := Reputation.new(content)
	_expect(huge.apply_selection_effect(1, "huge", _life_effect(9223372036854775807, 0.25))["ok"], "representable int64 charge grant succeeds")
	_error(huge.apply_selection_effect(2, "overflow", effects["second_chance"]), "INVALID_AMOUNT")
	_expect(huge.extra_life_charges == 9223372036854775807, "charge sum cannot overflow")


func _test_atomic_survival() -> void:
	# Include unchanged-current rescue: D5 still emits exactly one final change.
	for fixture in [[10.0, "nibbler", 100.0, 25.0], [10.0, "boss_big_glutton", 100.0, 25.0],
		[30.0, "boss_big_glutton", 100.0, 25.0], [25.0, "boss_big_glutton", 100.0, 25.0],
		[10.0, "boss_big_glutton", 115.0, 28.75]]:
		var state := Reputation.new(content)
		state.apply_damage(100.0 - fixture[0])
		if fixture[2] > 100.0:
			state.apply_selection_effect(1, "reputation_boost", effects["reputation_boost"])
		state.apply_selection_effect(2, "second_chance", effects["second_chance"])
		var events := _record(state)
		var live: Array[Dictionary] = []
		state.extra_life_consumed.connect(func(_p: Dictionary): live.append(state.snapshot()), CONNECT_ONE_SHOT)
		state.reputation_changed.connect(func(_p: Dictionary): live.append(state.snapshot()), CONNECT_ONE_SHOT)
		var result := state.apply_breach(_breach(1, fixture[1]))
		var raw := 10.0 if fixture[1] == "nibbler" else 40.0
		_damage(result, raw, raw, maxf(fixture[0] - fixture[3], 0.0), true)
		_expect(state.current == fixture[3] and not state.defeated and state.extra_life_charges == 0, "lethal resolution restores once without exposing zero")
		_expect(_ids(events) == ["life", "current"], "D5 signal order is extra_life_consumed then one reputation_changed; no run_ended")
		_expect(result["delta"] == fixture[3] - fixture[0], "delta represents final net change, including positive or zero")
		_expect(live == [state.snapshot(), state.snapshot()], "both signal callbacks observe fully committed final state")
		for event in events:
			var payload: Dictionary = event["payload"]
			_expect(payload == result, "signal and return payload retain the same transaction")
			_expect(payload["restore_ratio"] == 0.25 and payload["restored_to"] == fixture[3], "life payload reports ratio and final restore")
			_expect(payload["spawn_sequence"] == 1 and payload["monster_id"] == fixture[1], "life payload identifies original breach")
			for key in state.snapshot():
				_expect(payload[key] == state.snapshot()[key], "final signal includes %s" % key)
		var saved := result.duplicate(true)
		_error(state.apply_breach(_breach(1, fixture[1])), "DUPLICATE_BREACH")
		_expect(events.size() == 2, "duplicate rescue cannot repeat signals")
		state.apply_breach(_breach(2, "boss_big_glutton"))
		_expect(state.defeated and state.current == 0.0 and _ids(events).count("end") == 1, "next lethal breach defeats after charge is gone")
		_error(state.apply_breach(_breach(3)), "RUN_ENDED")
		_expect(result == saved and _ids(events).count("end") == 1, "later operations cannot mutate prior result or repeat defeat")
	var nonlethal := Reputation.new(content)
	nonlethal.apply_damage(50.0)
	nonlethal.apply_selection_effect(1, "second_chance", effects["second_chance"])
	var events := _record(nonlethal)
	_damage(nonlethal.apply_breach(_breach(1)), 10.0, 10.0, 10.0)
	_expect(nonlethal.current == 40.0 and nonlethal.extra_life_charges == 1 and _ids(events) == ["current"], "nonlethal loss retains life charge")
	nonlethal.restore(10.0)
	_expect(nonlethal.extra_life_charges == 1, "restoration never consumes a life")
	# Direct losses share atomic survival; they are already final amounts, not raw breaches.
	nonlethal.set_reputation_damage_multiplier(0.85)
	var direct := nonlethal.apply_damage(1000.0)
	_expect(direct["extra_life_consumed"] and nonlethal.current == 25.0, "direct apply_damage also resolves survival atomically")
	_expect(direct["damage_after_multiplier"] == 1000.0, "direct damage is not mitigated a second time")


func _test_d6_order() -> void:
	var shielded := Reputation.new(content)
	shielded.apply_damage(90.0)
	shielded.apply_selection_effect(1, "safety_shield", effects["safety_shield"])
	shielded.apply_selection_effect(2, "second_chance", effects["second_chance"])
	shielded.set_reputation_damage_multiplier(1e308)
	var events := _record(shielded)
	var blocked := shielded.apply_breach(_breach(1, "boss_big_glutton"))
	_damage(blocked, 40.0, 0.0, 0.0)
	_expect(blocked["shield_consumed"] and blocked["prevented_damage"] == 40.0, "shield prevents RAW damage before even an overflowing multiplier")
	_expect(shielded.current == 10.0 and shielded.extra_life_charges == 1 and _ids(events) == ["shield"], "shield prevents life evaluation")
	for starting in [35.0, 30.0]:
		var state := Reputation.new(content)
		state.apply_damage(100.0 - starting)
		state.set_reputation_damage_multiplier(0.85)
		state.apply_selection_effect(1, "second_chance", effects["second_chance"])
		var result := state.apply_breach(_breach(1, "boss_big_glutton"))
		var rescued: bool = starting == 30.0
		_damage(result, 40.0, 34.0, 5.0 if rescued else 34.0, rescued)
		_expect(state.current == (25.0 if rescued else 1.0), "lethality uses mitigated 34, not raw 40")
		_expect(state.extra_life_charges == (0 if rescued else 1), "nonlethal mitigation preserves life; lethal mitigation consumes it")
	var overkill := Reputation.new(content)
	overkill.apply_damage(70.0)
	overkill.set_reputation_damage_multiplier(0.85)
	_damage(overkill.apply_breach(_breach(1, "boss_big_glutton")), 40.0, 34.0, 30.0)
	_expect(overkill.defeated, "mitigated overkill without a life defeats normally")


func _test_zero_and_overflow() -> void:
	var alternate := content.duplicate(true)
	alternate["monsters"][0]["reputation_damage"] = 0.0
	var validated := Registry.new().validate_content(alternate)
	_expect(validated["ok"], "zero damage content fixture validates")
	var state := Reputation.new(validated["content"])
	state.apply_selection_effect(1, "safety_shield", effects["safety_shield"])
	state.apply_selection_effect(2, "second_chance", effects["second_chance"])
	state.set_reputation_damage_multiplier(1e308)
	var events := _record(state)
	_damage(state.apply_breach(_breach(1, alternate["monsters"][0]["id"])), 0.0, 0.0, 0.0)
	_expect(state.current == 100.0 and state.shield_charges == 1 and state.extra_life_charges == 1 and events.is_empty(), "zero precedes shield, multiplier and life")
	var overflowing := Reputation.new(content)
	overflowing.apply_selection_effect(1, "second_chance", effects["second_chance"])
	overflowing.set_reputation_damage_multiplier(1e308)
	var before := overflowing.snapshot()
	_error(overflowing.apply_breach(_breach(1)), "INVALID_DAMAGE")
	_expect(overflowing.snapshot() == before, "nonfinite damage does not consume life or mutate reputation")
	_error(overflowing.apply_breach(_breach(1)), "DUPLICATE_BREACH")


func _test_reentrancy() -> void:
	var state := Reputation.new(content)
	state.apply_damage(90.0)
	state.apply_selection_effect(1, "second_chance", effects["second_chance"])
	var nested: Array[Dictionary] = []
	var live: Array[Dictionary] = []
	state.extra_life_consumed.connect(func(_p: Dictionary):
		live.append(state.snapshot())
		nested.append(state.apply_breach(_breach(1, "boss_big_glutton")))
		nested.append(state.apply_breach(_breach(2)))
	, CONNECT_ONE_SHOT)
	var outer := state.apply_breach(_breach(1, "boss_big_glutton"))
	_error(nested[0], "DUPLICATE_BREACH")
	_damage(nested[1], 10.0, 10.0, 10.0)
	_damage(outer, 40.0, 40.0, 0.0, true)
	_expect(live[0]["current"] == 25.0 and live[0]["extra_life_charges"] == 0, "reentrant listener sees already consumed life and restored state")
	_expect(state.current == 15.0 and outer["current"] == 25.0, "distinct reentrant breach applies normally; outer snapshot remains frozen")
	var restored := Reputation.new(content)
	restored.apply_damage(70.0)
	restored.apply_selection_effect(1, "second_chance", effects["second_chance"])
	restored.reputation_changed.connect(func(_p: Dictionary): restored.restore(6.5), CONNECT_ONE_SHOT)
	var result := restored.apply_breach(_breach(1, "boss_big_glutton"))
	_damage(result, 40.0, 40.0, 5.0, true)
	_expect(result["current"] == 25.0 and restored.current == 31.5, "reputation_changed listener cannot alter calculated outer damage")


func _test_veggie_resolution() -> void:
	var resolver := Resolver.new(content)
	var plain := resolver.resolve("veggie", 5)
	_expect(plain["special_effect_params"] == {"amount": 5.0}, "unboosted veggie remains +5")
	var source_before := content.duplicate(true)
	for ids in [["chain5_effect_boost"], ["chain5_effect_boost", "taco_power_2", "extra_bite", "chain4_boost", "warm_welcome", "last_stand"]]:
		var modifiers := _modifiers(ids)
		var modifiers_before := modifiers.duplicate(true)
		for length in [5, 6, 25]:
			var resolved := resolver.resolve("veggie", length, modifiers)
			_expect(resolved["ok"] and resolved["special_effect_params"] == {"amount": 6.5}, "only special multiplier scales every veggie 5+ restore")
			var state := Reputation.new(content)
			state.apply_damage(20.0)
			var result := state.apply_served_dish(resolved, _service())
			_expect(result["ok"] and state.current == 86.5, "successful boosted service restores 6.5")
			for failed in [{"ok": false, "target_found": true, "served": {"spawn_sequence": 1}},
				{"ok": true, "target_found": false}, {"ok": true, "target_found": true, "served": {}}]:
				_error(state.apply_served_dish(resolved, failed), "NO_RESTORE_EFFECT")
				_expect(state.current == 86.5, "failed or missing service restores nothing")
		_expect(modifiers == modifiers_before, "resolver preserves derived snapshot")
		for length in [3, 4]:
			var state := Reputation.new(content)
			state.apply_damage(20.0)
			_error(state.apply_served_dish(resolver.resolve("veggie", length, modifiers), _service()), "NO_RESTORE_EFFECT")
			_expect(state.current == 80.0, "veggie 3/4 never restores")
	_expect(content == source_before, "boosting does not mutate content")
	var overflow := resolver.resolve("veggie", 5, {"special_effect_power_multiplier": 1e308})
	_error(overflow, Resolver.INVALID_MODIFIERS)


func _test_public_boss(upgrade_id: String, starting: float) -> void:
	var main = await _create_main(true)
	var path := DEFENSE_PREFIX.duplicate()
	path.append(upgrade_id)
	var starts: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	var endings: Array[Dictionary] = []
	main.boss_started.connect(func(p: Dictionary): starts.append(p))
	main.boss_encounter_completed.connect(func(p: Dictionary): completions.append(p))
	main.run_ended.connect(func(p: Dictionary): endings.append(p))
	var final := _finish_path(main, path)
	var life := upgrade_id == "second_chance"
	_expect(starts.size() == 1 and main.boss_has_started, "real fifth defense selection creates exactly one boss")
	_expect(main.lane_field.boss_spawn_multiplier == (1.0 if life else 0.85), "patient_service active BEFORE entering boss spawn")
	_expect(main.lane_field.boss_spawn_snapshot["extra_life_charges"] == int(life), "second_chance charge active BEFORE entering boss spawn")
	for id in ["safety_shield", "patient_service", "second_chance"]:
		_expect(id not in main.upgrade_selector.get_eligible_upgrade_ids(), "real selector preserves strong-defense exclusion")
	for _repeat in range(3):
		var forged := final.duplicate(true)
		forged["effect"] = {"stat": "reputation_damage_taken", "operation": "multiply", "value": 0.01}
		main.upgrade_selector.upgrade_selected.emit(forged)
	_expect(main.reputation.reputation_damage_multiplier == (1.0 if life else 0.85), "repeated payload cannot compound or replace authoritative multiplier")
	_expect(main.reputation.extra_life_charges == int(life) and starts.size() == 1, "repeated one-shot cannot stack lives or respawn boss")
	if starting < 100.0:
		main.reputation.apply_damage(100.0 - starting)
	var events := _record(main.reputation)
	var boss: LaneRunner = main.boss_runner
	var sequence := boss.monster_state.spawn_sequence
	if life:
		# Reenter the complete Main lane wiring before the outer result is cached.
		main.reputation.extra_life_consumed.connect(func(_p: Dictionary):
			main.lane_field.monster_reached_counter.emit(_breach(sequence, "boss_big_glutton"))
		, CONNECT_ONE_SHOT)
	boss.advance(1000.0)
	var final_current := 25.0 if life else maxf(starting - 34.0, 0.0)
	var applied := maxf(starting - final_current, 0.0)
	_expect(main.reputation.current == final_current, "real boss final reputation follows selected defense")
	_expect(completions.size() == 1, "boss breach completes once")
	if completions.size() == 1:
		_expect(completions[0]["reputation_damage_on_breach"] == 40.0 and completions[0]["reputation_damage"] == applied, "boss completion preserves raw 40 and net applied damage")
	var result: Dictionary = main._breach_results_by_sequence.get(sequence, {})
	_damage(result, 40.0, 40.0 if life else 34.0, applied, life)
	_expect(endings.size() == (1 if final_current == 0.0 else 0), "only final zero emits run_ended")
	if life:
		_expect(_ids(events) == ["life", "current"], "Main rescue has no intermediate reputation or defeat signal")
		_expect(main.can_process() and not main.hud.outcome_label.visible, "rescue keeps gameplay enabled without false outcome")
	_expect(main.hud.reputation_bar.value == final_current, "HUD follows final reputation")
	var saved := result.duplicate(true)
	main.lane_field.monster_reached_counter.emit(_breach(sequence, "boss_big_glutton"))
	_expect(main._breach_results_by_sequence[sequence] == saved and completions.size() == 1, "duplicate never overwrites successful boss result")
	_expect(not main.wave_director.has_wave("wave_06") and main.wave_director.current_wave_id == "wave_05", "boss never starts wave 6")
	main.queue_free()
	await process_frame


func _test_early_selection() -> void:
	var main = await _create_main()
	# Public seed 20260921 offers second_chance immediately.
	_select(main, 1, "second_chance")
	_expect(main.reputation.extra_life_charges == 1 and not main.boss_has_started, "nonfinal life grant applies before final-selection guards")
	main.queue_free()
	await process_frame
	main = await _create_main()
	for i in range(4):
		_select(main, i + 1, ["last_stand", "slow_salsa", "taco_power_1", "patient_service"][i])
	_expect(main.reputation.reputation_damage_multiplier == 0.85 and not main.boss_has_started, "nonfinal patient selection updates runtime immediately")
	for _repeat in range(3):
		main._on_upgrade_selected({"selection_number": 4, "upgrade_id": "patient_service", "effect": {"value": 0.01}})
	_damage(main.reputation.apply_breach(_breach(900)), 10.0, 8.5, 8.5)
	_expect(main.hud.reputation_label.text == "Reputación 91.5 / 100", "HUD keeps fractional patient damage")
	main.queue_free()
	await process_frame


func _test_veggie_main() -> void:
	var main = await _create_main()
	main.reputation.apply_damage(20.0)
	var target: LaneRunner = main.lane_field.spawn_runner(1, 55.0, "M", "salsa_tank", 10000.0)
	target.auto_advance = false
	main.board_view.chain_completed.emit(_points(5), "veggie")
	_expect(main.reputation.current == 85.0, "Main unboosted veggie restores +5")
	_select(main, 1, "second_chance")
	_select(main, 2, "chain5_effect_boost")
	main.reputation.apply_damage(5.0)
	main.board_view.chain_completed.emit(_points(5), "veggie")
	_expect(main.reputation.current == 86.5 and main.hud.reputation_label.text == "Reputación 86.5 / 100", "real selection -> resolver -> service -> HUD restores +6.5")
	for length in [3, 4]:
		main.board_view.chain_completed.emit(_points(length), "veggie")
		_expect(main.reputation.current == 86.5, "Main short veggie chains do not restore")
	main.reputation.apply_selection_effect(3, "reputation_boost", effects["reputation_boost"])
	main.reputation.restore(25.5)
	_expect(main.reputation.current == 112.0, "updated maximum clamp fixture starts at 112/115")
	main.board_view.chain_completed.emit(_points(6), "veggie")
	_expect(main.reputation.current == 115.0 and main.hud.reputation_bar.max_value == 115.0, "boosted 6.5 clamps to updated maximum 115")
	target.monster_state.apply_satisfaction(10000.0)
	main.reputation.apply_damage(20.0)
	main.board_view.chain_completed.emit(_points(5), "veggie")
	_expect(main.reputation.current == 95.0, "real no-target service gives no restoration")
	main.queue_free()
	await process_frame


func _test_feedback_rearm() -> void:
	var main = await _create_main()
	_select(main, 1, "second_chance")
	var cues: Array[String] = []
	main.feedback.feedback_requested.connect(func(p: Dictionary): cues.append(p["cue_id"]))
	main.reputation.apply_damage(90.0)
	_expect(cues.count("low_reputation") == 1, "initial low crossing emits once")
	cues.clear()
	main.reputation.apply_breach(_breach(900, "boss_big_glutton"))
	_expect(main.reputation.current == 25.0 and cues == ["reputation_delta"], "rescue only presents final positive delta, no new life cue or defeat")
	main.reputation.apply_breach(_breach(901))
	_expect(main.reputation.current == 15.0 and cues.count("low_reputation") == 1, "restored ratio above 20 percent rearms the next low crossing")
	_expect(not Feedback.CUE_KEYS.has("extra_life_consumed"), "no unapproved extra-life presentation added")
	main.queue_free()
	await process_frame


func _create_main(seed_two: bool = false):
	var main = MAIN.instantiate()
	main.auto_start_run = false
	main.get_node("%LaneField").set_script(ObservedField)
	if seed_two:
		main.get_node("%UpgradeSelector").set_script(SeededSelector)
	root.add_child(main)
	await process_frame
	main.lane_field.reputation = main.reputation
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(p: Dictionary):
		main.wave_director.get_spawned_runner(p["spawn_sequence"]).auto_advance = false)
	main.boss_started.connect(func(_p: Dictionary): main.boss_runner.auto_advance = false)
	return main


func _finish_path(main, path: Array) -> Dictionary:
	var final: Dictionary = {}
	for i in range(5):
		var wave: Dictionary = content["waves"][i]
		_expect(main.wave_director.start_wave(wave["id"], 0.0)["ok"], "real wave starts")
		main.wave_director.advance(1000.0)
		for _entry in wave["spawns"]:
			_expect(main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 1000.0})["ok"], "normal monster resolved through real LaneField")
		_expect(main.wave_director.state == WaveDirector.State.COMPLETED and not main.boss_has_started, "boss waits for completed normal waves and fifth selection")
		var selected: Dictionary = main.upgrade_selector.select_upgrade(path[i])
		_expect(selected["ok"], "pinned public offer contains %s" % path[i])
		final = selected.get("selection", {})
	return final


func _select(main, wave: int, id: String) -> void:
	main.wave_director.wave_completed.emit({"wave_id": "wave_%02d" % wave})
	_expect(main.upgrade_selector.select_upgrade(id)["ok"], "public offer allows %s" % id)


func _record(state: ReputationState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	state.extra_life_consumed.connect(func(p: Dictionary): events.append({"id": "life", "payload": p.duplicate(true)}))
	state.reputation_changed.connect(func(p: Dictionary): events.append({"id": "current", "payload": p.duplicate(true)}))
	state.shield_consumed.connect(func(p: Dictionary): events.append({"id": "shield", "payload": p.duplicate(true)}))
	state.run_ended.connect(func(p: Dictionary): events.append({"id": "end", "payload": p.duplicate(true)}))
	return events


func _ids(events: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for event in events:
		ids.append(event["id"])
	return ids


func _modifiers(ids: Array) -> Dictionary:
	var active: Array = []
	for id in ids:
		active.append({"upgrade_id": id, "effect": effects[id]})
	return Modifiers.derive(active)["modifiers"]


func _life_effect(value, ratio) -> Dictionary:
	return {"type": "grant_charge", "stat": "extra_life_charges", "operation": "add", "value": value,
		"params": {"restore_ratio": ratio}}


func _breach(sequence: int, id: String = "nibbler") -> Dictionary:
	return {"spawn_sequence": sequence, "monster_id": id}


func _service() -> Dictionary:
	return {"ok": true, "target_found": true, "served": {"spawn_sequence": 1}}


func _points(length: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for index in range(length):
		points.append(Vector2i(index % 5, index / 5))
	return points


func _damage(result: Dictionary, raw: float, mitigated: float, applied: float, rescued: bool = false) -> void:
	_expect(result.get("ok", false), "breach succeeds")
	_expect(result.get("damage_requested") == raw and result.get("damage_after_multiplier") == mitigated, "damage distinguishes raw and mitigated")
	_expect(result.get("damage_applied") == applied and applied >= 0.0, "effective damage is final nonnegative net loss")
	_expect(result.get("extra_life_consumed") == rescued, "breach reports whether life was consumed")


func _error(result: Dictionary, code: String) -> void:
	_expect(not result.get("ok", true) and result.get("error") == code, "explicit error %s: %s" % [code, result])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
