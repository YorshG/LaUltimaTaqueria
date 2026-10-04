extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const MAIN = preload("res://scenes/Main.tscn")
const FIELD = preload("res://scenes/lane/LaneField.tscn")

# Observe the value at entry to spawn_runner, not only at boss_started.
class ObservedLaneField extends LaneField:
	var spawn_observations: Array[Dictionary] = []

	func spawn_runner(
		lane_index: int, speed_relative: float, display_text: String = "M",
		monster_id: String = "monster", hunger_max: float = 30.0
	) -> LaneRunner:
		var value_before_spawn := global_speed_multiplier
		var runner := super.spawn_runner(lane_index, speed_relative, display_text, monster_id, hunger_max)
		spawn_observations.append({
			"id": monster_id, "before": value_before_spawn,
			"runner": runner.motion.global_speed_multiplier,
		})
		return runner


class InvalidEffectsSelector extends UpgradeSelector:
	func get_active_effects() -> Array[Dictionary]:
		return [{"upgrade_id": "broken", "effect": {}}]


var failures := 0
var checks := 0
var content: Dictionary


func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "real content must validate")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	await _test_field_contract()
	await _test_early_selection(["last_stand", "slow_salsa"], 0.9)
	await _test_early_selection(["steady_hands", "second_chance", "taco_power_1", "slow_salsa_plus"], 0.75)
	await _test_fifth_selection(["steady_hands", "second_chance", "chain5_effect_boost", "reputation_boost", "slow_salsa"], 0.9)
	await _test_fifth_selection(["steady_hands", "second_chance", "taco_power_1", "last_stand", "slow_salsa_plus"], 0.75)
	await _test_invalid_derivation()
	if failures == 0:
		print("UPG-02c tests passed: %d checks; absolute speed, active/future runners, public selections, pre-spawn boss inheritance and all phases." % checks)
	else:
		push_error("UPG-02c tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_field_contract() -> void:
	var field: LaneField = FIELD.instantiate()
	get_root().add_child(field)
	await process_frame
	_expect_float(field.global_speed_multiplier, 1.0, "new field starts neutral")
	var runners: Array[LaneRunner] = []
	for lane in range(3):
		var runner := field.spawn_runner(lane, 30.0 + lane * 25.0, "M", "normal_%d" % lane, 100.0)
		runner.auto_advance = false
		runner.motion.progress = 0.2 + lane * 0.1
		runner.set_phase_multiplier(1.25)
		runner.monster_state.apply_satisfaction(10.0)
		runners.append(runner)
		runner.advance(0.5)
		_expect_float(runner.motion.progress, 0.2 + lane * 0.1 + 0.1 * (30.0 + lane * 25.0) / 100.0 * 1.25 * 0.5, "neutral movement preserves LaneMotion formula")
	runners[1].apply_brief_stun(0.6)
	var retired := field.spawn_runner(0, 55.0)
	retired.monster_state.apply_satisfaction(1000.0)
	var retired_before := _state_without_global(retired)
	var freed := field.spawn_runner(2, 55.0)
	freed.free()
	var selected := field.select_nearest_target()
	for multiplier in [0.9, 0.9, 0.75, 0.75, 1]:
		var before: Array = []
		for runner in runners:
			before.append(_state_without_global(runner))
		_expect(field.set_global_speed_multiplier(multiplier), "positive finite numeric multiplier must succeed")
		_expect_float(field.global_speed_multiplier, multiplier, "absolute field assignment")
		for i in range(runners.size()):
			_expect_float(runners[i].motion.global_speed_multiplier, multiplier, "all existing lanes update immediately")
			_expect(_state_without_global(runners[i]) == before[i], "refresh preserves all other runner state")
		_expect(field.select_nearest_target() == selected, "refresh preserves targeting")
		_expect(_state_without_global(retired) == retired_before, "retired runner must not reactivate")
		var future := field.spawn_runner(0, 100.0)
		future.auto_advance = false
		_expect_float(future.motion.global_speed_multiplier, multiplier, "future spawn inherits field value")
		future.advance(0.5)
		_expect_float(future.motion.progress, 0.05 * multiplier, "future displacement uses inherited speed")
		future.free()
	_expect(field.set_global_speed_multiplier(0.75), "prepare rejection fixture")
	for invalid in [NAN, INF, -INF, 0, -1, -0.5, null, true, false, "0.9", [], {}]:
		var before := _state_without_global(runners[1])
		_expect(not field.set_global_speed_multiplier(invalid), "invalid value must be rejected")
		_expect_float(field.global_speed_multiplier, 0.75, "rejection preserves field value")
		for runner in runners:
			_expect_float(runner.motion.global_speed_multiplier, 0.75, "rejection preserves all runner multipliers")
		_expect(_state_without_global(runners[1]) == before, "rejection preserves stun and runner state")
	var progress := runners[1].motion.progress
	runners[1].advance(0.4)
	_expect_float(runners[1].motion.progress, progress, "speed refresh must not cancel stun")
	runners[1].advance(0.4)
	_expect_float(runners[1].motion.progress, progress + 0.055 * 1.25 * 0.75 * 0.2, "remaining frame after stun uses current multiplier")
	field.queue_free()
	await process_frame


func _test_early_selection(path: Array, multiplier: float) -> void:
	var main = await _create_main()
	var runners: Array[LaneRunner] = []
	for lane in range(3):
		var runner: LaneRunner = main.lane_field.spawn_runner(lane, 55.0)
		runner.auto_advance = false
		runner.motion.progress = 0.2
		runners.append(runner)
	# Payload does not carry the authoritative effect; an empty snapshot stays neutral.
	main.upgrade_selector.upgrade_selected.emit({"is_final_selection": true, "effect": {"value": 0.01}})
	_expect_float(main.lane_field.global_speed_multiplier, 1.0, "payload cannot invent an active effect")
	for i in range(path.size()):
		main.wave_director.wave_completed.emit({"wave_id": "wave_%02d" % (i + 1)})
		var before := _state_without_global(runners[0])
		var selection: Dictionary = main.upgrade_selector.select_upgrade(path[i])
		_expect(selection["ok"], "fixed public offer must allow %s" % path[i])
		var expected := multiplier if i == path.size() - 1 else 1.0
		_expect_float(main.lane_field.global_speed_multiplier, expected, "every selection refreshes before final-selection guard")
		for runner in runners:
			_expect_float(runner.motion.global_speed_multiplier, expected, "selection immediately updates existing normal monsters")
		_expect(_state_without_global(runners[0]) == before, "selection changes only future speed")
	_expect(not main.boss_has_started, "nonfinal selection must not start boss")
	for _repeat in range(3):
		main.upgrade_selector.upgrade_selected.emit({"is_final_selection": true, "effect": {"value": 0.01}})
		_expect_float(main.lane_field.global_speed_multiplier, multiplier, "repeated signal derives from selector, not payload or previous value")
	_expect(not main.boss_has_started, "incomplete selection guard remains intact")
	_expect(main.wave_director.start_wave("wave_05", 0.0)["ok"], "future wave starts through unchanged WaveDirector")
	main.wave_director.advance(1000.0)
	for observation in main.lane_field.spawn_observations.slice(3):
		_expect_float(observation["before"], multiplier, "WaveDirector future spawn sees current field value")
		_expect_float(observation["runner"], multiplier, "WaveDirector runner inherits current field value")
	_expect(main.wave_director.get_spawned_count() == 7, "future wave actually spawned all seven monsters")
	var progress := runners[0].motion.progress
	runners[0].advance(1.0)
	_expect_float(runners[0].motion.progress, progress + 0.055 * multiplier, "existing normal displacement changes after selection")
	main.queue_free()
	await process_frame


func _test_fifth_selection(path: Array, multiplier: float) -> void:
	var main = await _create_main()
	var starts: Array[Dictionary] = []
	main.boss_started.connect(func(payload: Dictionary): starts.append(payload))
	var final_selection: Dictionary = {}
	for i in range(5):
		var wave: Dictionary = content["waves"][i]
		_expect(main.wave_director.start_wave(wave["id"], 0.0)["ok"], "real normal wave starts")
		main.wave_director.advance(1000.0)
		for _spawn in wave["spawns"]:
			_expect(main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 1000.0})["ok"], "normal monster is resolved through LaneField")
		_expect(main.wave_director.state == WaveDirector.State.COMPLETED, "all normal wave monsters resolved")
		_expect(not main.boss_has_started, "boss waits for fifth selection")
		var selected: Dictionary = main.upgrade_selector.select_upgrade(path[i])
		_expect(selected["ok"], "real public offer must contain %s" % path[i])
		if selected["ok"]:
			final_selection = selected["selection"]
	_expect(main.boss_has_started and starts.size() == 1, "fifth selection starts exactly one boss")
	if not is_instance_valid(main.boss_runner):
		main.queue_free()
		await process_frame
		return
	var observation: Dictionary = main.lane_field.spawn_observations[-1]
	_expect(observation["id"] == content["boss"]["id"], "last observed spawn is the real boss")
	_expect_float(observation["before"], multiplier, "fifth selection updates field BEFORE entering boss spawn")
	_expect_float(observation["runner"], multiplier, "boss leaves spawn_runner with inherited value")
	var boss: LaneRunner = main.boss_runner
	for phase_index in range(3):
		if phase_index > 0:
			var threshold := float(content["boss"]["phases"][phase_index]["threshold"])
			main.lane_field.resolve_dish({"ok": true, "satisfaction_final": boss.monster_state.hunger_remaining - 300.0 * threshold})
		var phase := float(content["boss"]["phases"][phase_index]["speed_multiplier"])
		_expect(boss.monster_state.phase_index == phase_index, "boss phase advances through real satisfaction")
		_expect_float(boss.motion.phase_multiplier, phase, "phase multiplier remains independent")
		_expect_float(boss.effective_speed(), 0.025 * phase * multiplier, "global multiplier applies in every boss phase")
		var before := _state_without_global(boss)
		# Change an already active boss, then replay the selection to restore authoritative state.
		_expect(main.lane_field.set_global_speed_multiplier(1.0), "field can update an active boss")
		_expect_float(boss.motion.global_speed_multiplier, 1.0, "active boss immediately receives absolute value")
		for _repeat in range(3):
			main.upgrade_selector.upgrade_selected.emit(final_selection)
			_expect_float(boss.motion.global_speed_multiplier, multiplier, "refresh precedes boss-already-started guard and stays idempotent")
			_expect(_state_without_global(boss) == before, "duplicate selection preserves boss phase, position, hunger and identity")
		_expect(main.boss_runner == boss and starts.size() == 1, "replayed fifth selection cannot duplicate boss")
		var progress := boss.motion.progress
		boss.advance(1.0)
		_expect_float(boss.motion.progress, progress + 0.025 * phase * multiplier, "actual boss movement uses phase and global multipliers")
	main.queue_free()
	await process_frame


func _test_invalid_derivation() -> void:
	var main = await _create_main()
	var runner: LaneRunner = main.lane_field.spawn_runner(1, 55.0)
	runner.auto_advance = false
	main.lane_field.set_global_speed_multiplier(0.75)
	var before := _state_without_global(runner)
	var broken := InvalidEffectsSelector.new()
	main.add_child(broken)
	main.upgrade_selector = broken
	main._on_upgrade_selected({"is_final_selection": true})
	_expect_float(main.lane_field.global_speed_multiplier, 0.75, "failed derivation preserves current field value")
	_expect_float(runner.motion.global_speed_multiplier, 0.75, "failed derivation preserves runner speed")
	_expect(_state_without_global(runner) == before and not main.boss_has_started, "failed derivation has no partial runtime effect")
	main.queue_free()
	await process_frame


func _create_main():
	var main = MAIN.instantiate()
	main.auto_start_run = false
	main.get_node("%LaneField").set_script(ObservedLaneField)
	get_root().add_child(main)
	await process_frame
	_expect(main.DEFAULT_RUN_SEED == 20260921, "public selection fixtures pin Main seed")
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(payload: Dictionary):
		main.wave_director.get_spawned_runner(payload["spawn_sequence"]).auto_advance = false
	)
	main.boss_started.connect(func(_payload: Dictionary): main.boss_runner.auto_advance = false)
	return main


func _state_without_global(runner: LaneRunner) -> Array:
	var motion := runner.motion
	var state := runner.monster_state
	return [runner.get_instance_id(), motion.get_instance_id(), state.get_instance_id(),
		motion.lane_index, motion.speed_relative, motion.progress, motion.phase_multiplier,
		motion.stun_remaining_sec, state.monster_id, state.lane, state.spawn_sequence,
		state.hunger_max, state.hunger_remaining, state.active, state.satisfied,
		state.phase_index, runner.is_targetable()]


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s: expected %s, got %s" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
