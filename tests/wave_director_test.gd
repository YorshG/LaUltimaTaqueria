extends SceneTree

var failures := 0
var Director = preload("res://scripts/waves/wave_director.gd")
var Registry = preload("res://scripts/content/content_registry.gd")


func _init() -> void:
	await _test_public_api_countdown_pause_and_completion()
	await _test_deterministic_schedule_and_large_delta()
	await _test_homogeneous_resolution_paths()
	await _test_resolution_paths_and_one_shot_completion()
	await _test_all_five_content_waves()
	await _test_main_wiring_does_not_auto_start()

	if failures == 0:
		print("WAV-01 tests passed: countdown, schedule, resolution, pause and five waves.")
		quit(0)
	else:
		push_error("WAV-01 tests failed: %d" % failures)
		quit(1)


func _test_public_api_countdown_pause_and_completion() -> void:
	var unconfigured: WaveDirector = Director.new()
	unconfigured.auto_advance = false
	get_root().add_child(unconfigured)
	var not_configured: Dictionary = unconfigured.start_wave("wave_test", 0.0)
	_expect_error(not_configured, Director.NOT_CONFIGURED, "start before configure")
	unconfigured.queue_free()
	await process_frame

	var content := _synthetic_content([
		_wave("wave_test", 3.0, [_spawn(2.0, "alpha", 1)], "metadata_only"),
	])
	var harness: Dictionary = await _create_harness(content)
	var director: WaveDirector = harness["director"]
	var field: LaneField = harness["field"]
	var completed_payloads: Array[Dictionary] = []
	director.wave_completed.connect(func(payload: Dictionary): completed_payloads.append(payload))

	_expect_error(director.start_wave("missing", 0.0), Director.UNKNOWN_WAVE, "unknown wave")
	for invalid_countdown in [-1.0, NAN, INF, -INF]:
		_expect_error(
			director.start_wave("wave_test", invalid_countdown),
			Director.INVALID_COUNTDOWN,
			"invalid countdown"
		)

	var started: Dictionary = director.start_wave("wave_test", 1.0)
	_expect(started["ok"], "valid wave must start")
	_expect(director.state == Director.State.COUNTDOWN, "positive countdown must enter COUNTDOWN")
	_expect(is_zero_approx(director.wave_elapsed_sec), "wave clock must start at zero")
	_expect(director.get_spawned_count() == 0, "countdown must not spawn monsters")
	_expect_error(director.start_wave("wave_test", 0.0), Director.WAVE_ALREADY_ACTIVE, "parallel wave")

	var countdown_before_pause := director.countdown_remaining_sec
	director.set_paused(true)
	director.advance(10.0)
	_expect(is_equal_approx(director.countdown_remaining_sec, countdown_before_pause), "pause must freeze countdown")
	_expect(is_zero_approx(director.wave_elapsed_sec), "pause must freeze wave clock")
	director.set_paused(false)
	director.advance(0.5)
	_expect(is_equal_approx(director.countdown_remaining_sec, 0.5), "countdown must advance explicitly")
	director.advance(0.5)
	_expect(director.state == Director.State.RUNNING, "countdown boundary must enter RUNNING")
	_expect(is_zero_approx(director.wave_elapsed_sec), "countdown must not count toward wave time")

	for invalid_delta in [-1.0, NAN, INF, -INF]:
		var elapsed_before := director.wave_elapsed_sec
		_expect_error(director.advance(invalid_delta), Director.INVALID_DELTA, "invalid delta")
		_expect(is_equal_approx(director.wave_elapsed_sec, elapsed_before), "invalid delta must not advance")
	director.advance(0.0)
	_expect(director.get_spawned_count() == 0, "zero delta before boundary must not spawn")
	director.advance(1.0)
	_expect(director.get_spawned_count() == 0, "spawn before at_sec must not occur")
	director.advance(1.0)
	_expect(director.get_spawned_count() == 1, "spawn exactly at at_sec must occur")
	_expect(director.state == Director.State.AWAITING_RESOLUTION, "last spawn with pending monster must await resolution")

	director.advance(10.0)
	_expect(director.state == Director.State.AWAITING_RESOLUTION, "duration target must not complete pending wave")
	_expect(director.wave_elapsed_sec > 3.0, "wave clock may exceed duration target")
	_expect(completed_payloads.is_empty(), "pending monster must prevent completion")
	field.resolve_dish(_dish(100.0))
	_expect(director.state == Director.State.COMPLETED, "satisfied final monster must complete wave")
	_expect(completed_payloads.size() == 1, "wave_completed must emit once")
	if not completed_payloads.is_empty():
		var payload := completed_payloads[0]
		_expect(payload["wave_id"] == "wave_test", "completion must include wave id")
		_expect(payload["scheduled_spawn_count"] == 1, "completion must include scheduled count")
		_expect(payload["resolved_count"] == 1, "completion must include resolved count")
		_expect(payload["satisfied_count"] == 1, "completion must count satisfied monsters")
		_expect(payload["counter_reached_count"] == 0, "completion must separate counter arrivals")
		_expect(payload["teaches"] == "metadata_only", "teaches must remain metadata")

	var elapsed_at_completion := director.wave_elapsed_sec
	director.advance(100.0)
	_expect(is_equal_approx(director.wave_elapsed_sec, elapsed_at_completion), "completed wave clock must stop")
	_expect(completed_payloads.size() == 1, "advance after completion must not re-emit")

	_expect(director.start_wave("wave_test", 0.0)["ok"], "second wave may start after completion")
	_expect(director.state == Director.State.RUNNING, "zero countdown must start running immediately")
	await _free_harness(harness)


func _test_deterministic_schedule_and_large_delta() -> void:
	var content := _synthetic_content([
		_wave("wave_order", 20.0, [
			_spawn(2.0, "alpha", 0),
			_spawn(8.0, "beta", 1),
			_spawn(8.0, "alpha", 2),
			_spawn(14.0, "beta", 0),
		]),
	])
	var small_harness: Dictionary = await _create_harness(content)
	var large_harness: Dictionary = await _create_harness(content)
	var small: WaveDirector = small_harness["director"]
	var large: WaveDirector = large_harness["director"]
	var small_spawns: Array[Dictionary] = []
	var large_spawns: Array[Dictionary] = []
	small.monster_spawned.connect(func(payload: Dictionary): small_spawns.append(payload))
	large.monster_spawned.connect(func(payload: Dictionary): large_spawns.append(payload))
	small.start_wave("wave_order", 0.0)
	large.start_wave("wave_order", 0.0)
	for delta in [1.0, 1.0, 6.0, 6.0]:
		small.advance(delta)
	large.advance(1.0)
	large.advance(20.0)

	_expect(small_spawns.size() == 4 and large_spawns.size() == 4, "all crossed spawns must dispatch once")
	_expect(_spawn_signature(small_spawns) == _spawn_signature(large_spawns), "small and large delta steps must preserve spawn order")
	_expect(
		[int(small_spawns[1]["source_index"]), int(small_spawns[2]["source_index"])] == [1, 2],
		"same at_sec must preserve original source order"
	)
	_expect(small.get_pending_count() == 4 and large.get_pending_count() == 4, "all spawned monsters must remain pending until resolved")
	_expect(small.state == Director.State.AWAITING_RESOLUTION, "all dispatched with pending monsters must await")
	await _free_harness(small_harness)
	await _free_harness(large_harness)


func _test_resolution_paths_and_one_shot_completion() -> void:
	var content := _synthetic_content([
		_wave("wave_mix", 1.0, [
			_spawn(0.0, "alpha", 1),
			_spawn(0.0, "beta", 0),
		]),
	])
	var harness: Dictionary = await _create_harness(content)
	var director: WaveDirector = harness["director"]
	var field: LaneField = harness["field"]
	var spawned: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	director.monster_spawned.connect(func(payload: Dictionary): spawned.append(payload))
	director.wave_completed.connect(func(payload: Dictionary): completed.append(payload))
	director.start_wave("wave_mix", 0.0)
	_expect(director.get_spawned_count() == 2, "at_sec zero spawns must dispatch at start")
	_expect(director.state == Director.State.AWAITING_RESOLUTION, "zero-time schedule must await resolution")

	field.resolve_dish(_dish(100.0))
	_expect(director.get_resolved_count() == 1, "satisfied monster must resolve once")
	var satisfied_sequence := -1
	var active_sequence := -1
	for payload in spawned:
		var sequence := int(payload["spawn_sequence"])
		var runner := director.get_spawned_runner(sequence)
		if runner.monster_state.satisfied:
			satisfied_sequence = sequence
		else:
			active_sequence = sequence
	_expect(satisfied_sequence >= 0 and active_sequence >= 0, "mix test must identify both runners")

	field.monster_satisfied.emit({
		"spawn_sequence": satisfied_sequence,
		"monster_id": "alpha",
		"lane": 1,
	})
	_expect(director.get_resolved_count() == 1, "duplicate resolution must not count twice")
	var active_runner := director.get_spawned_runner(active_sequence)
	active_runner.advance(1000.0)
	_expect(not active_runner.monster_state.active, "counter arrival must retire monster logically")
	_expect(not active_runner.monster_state.satisfied, "counter arrival must not mark monster satisfied")
	_expect(director.get_resolved_count() == 2, "counter arrival must resolve remaining monster")
	_expect(completed.size() == 1, "mixed resolution must complete exactly once")
	if not completed.is_empty():
		_expect(completed[0]["satisfied_count"] == 1, "mixed completion must count satisfaction")
		_expect(completed[0]["counter_reached_count"] == 1, "mixed completion must count counter arrival")
	field.monster_reached_counter.emit({
		"spawn_sequence": active_sequence,
		"monster_id": "beta",
		"lane": 0,
	})
	director.advance(1.0)
	_expect(director.get_resolved_count() == 2, "duplicate counter event must not count twice")
	_expect(completed.size() == 1, "duplicate events must not re-emit completion")
	await _free_harness(harness)


func _test_homogeneous_resolution_paths() -> void:
	var content := _synthetic_content([
		_wave("wave_all", 1.0, [
			_spawn(0.0, "alpha", 1),
			_spawn(0.0, "beta", 0),
		]),
	])

	var satisfied_harness: Dictionary = await _create_harness(content)
	var satisfied_director: WaveDirector = satisfied_harness["director"]
	var satisfied_field: LaneField = satisfied_harness["field"]
	var satisfied_completions: Array[Dictionary] = []
	satisfied_director.wave_completed.connect(
		func(payload: Dictionary): satisfied_completions.append(payload)
	)
	satisfied_director.start_wave("wave_all", 0.0)
	satisfied_field.resolve_dish(_dish(100.0))
	satisfied_field.resolve_dish(_dish(100.0))
	_expect(satisfied_director.state == Director.State.COMPLETED, "all satisfied monsters must complete wave")
	_expect(satisfied_completions.size() == 1, "all-satisfied wave must emit completion once")
	if not satisfied_completions.is_empty():
		_expect(satisfied_completions[0]["satisfied_count"] == 2, "all-satisfied count must include every monster")
		_expect(satisfied_completions[0]["counter_reached_count"] == 0, "all-satisfied wave must have no counter arrivals")
	await _free_harness(satisfied_harness)

	var counter_harness: Dictionary = await _create_harness(content)
	var counter_director: WaveDirector = counter_harness["director"]
	var counter_spawns: Array[Dictionary] = []
	var counter_completions: Array[Dictionary] = []
	counter_director.monster_spawned.connect(func(payload: Dictionary): counter_spawns.append(payload))
	counter_director.wave_completed.connect(func(payload: Dictionary): counter_completions.append(payload))
	counter_director.start_wave("wave_all", 0.0)
	for payload in counter_spawns:
		counter_director.get_spawned_runner(int(payload["spawn_sequence"])).advance(1000.0)
	_expect(counter_director.state == Director.State.COMPLETED, "all counter arrivals must complete wave")
	_expect(counter_completions.size() == 1, "all-counter wave must emit completion once")
	if not counter_completions.is_empty():
		_expect(counter_completions[0]["satisfied_count"] == 0, "all-counter wave must have no satisfactions")
		_expect(counter_completions[0]["counter_reached_count"] == 2, "all-counter count must include every monster")
	await _free_harness(counter_harness)


func _test_all_five_content_waves() -> void:
	var registry_result: Dictionary = Registry.new().load_and_validate()
	_expect(registry_result["ok"], "default content must validate before wave tests")
	if not registry_result["ok"]:
		return
	var content: Dictionary = registry_result["content"]
	var harness: Dictionary = await _create_harness(content)
	var director: WaveDirector = harness["director"]
	var expected_counts := [4, 4, 5, 5, 7]
	var total_spawned := 0
	for index in range(5):
		var wave_id := "wave_%02d" % (index + 1)
		var spawned: Array[Dictionary] = []
		var callback := func(payload: Dictionary):
			if payload["wave_id"] == wave_id:
				spawned.append(payload)
		director.monster_spawned.connect(callback)
		_expect(director.start_wave(wave_id, 0.0)["ok"], "%s must start" % wave_id)
		director.advance(1000.0)
		_expect(spawned.size() == expected_counts[index], "%s must use unchanged spawn count" % wave_id)
		_expect(director.state == Director.State.AWAITING_RESOLUTION, "%s must await spawned monsters" % wave_id)
		for payload in spawned:
			var runner := director.get_spawned_runner(int(payload["spawn_sequence"]))
			var monster: Dictionary = registry_result["indexes"]["monsters"][payload["monster_id"]]
			_expect(is_equal_approx(runner.motion.speed_relative, float(monster["speed"])), "spawn speed must come from content")
			_expect(is_equal_approx(runner.monster_state.hunger_max, float(monster["hunger"])), "spawn hunger must come from content")
			runner.advance(1000.0)
		_expect(director.state == Director.State.COMPLETED, "%s must complete after all arrivals" % wave_id)
		total_spawned += spawned.size()
		director.monster_spawned.disconnect(callback)
	_expect(total_spawned == 25, "five existing waves must schedule exactly 25 monsters")
	await _free_harness(harness)


func _test_main_wiring_does_not_auto_start() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main = packed.instantiate()
	get_root().add_child(main)
	await process_frame
	_expect(main.wave_director.state == Director.State.IDLE, "Main must configure but not auto-start waves")
	_expect(main.wave_director.has_wave("wave_01"), "Main must reuse validated wave content")
	_expect(main.wave_director.get_spawned_count() == 0, "Main must not spawn a wave automatically")
	main.queue_free()
	await process_frame


func _create_harness(content: Dictionary) -> Dictionary:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")
	var field: LaneField = packed.instantiate()
	get_root().add_child(field)
	var director: WaveDirector = Director.new()
	director.auto_advance = false
	get_root().add_child(director)
	await process_frame
	var configured: Dictionary = director.configure(content, field)
	_expect(configured["ok"], "WaveDirector harness must configure")
	return {"field": field, "director": director}


func _free_harness(harness: Dictionary) -> void:
	(harness["director"] as Node).queue_free()
	(harness["field"] as Node).queue_free()
	await process_frame


func _synthetic_content(waves: Array) -> Dictionary:
	return {
		"waves": waves,
		"monsters": [
			{"id": "alpha", "speed": 100.0, "hunger": 10.0},
			{"id": "beta", "speed": 50.0, "hunger": 20.0},
		],
	}


func _wave(id: String, duration: float, spawns: Array, teaches: String = "test") -> Dictionary:
	return {
		"id": id,
		"duration_target_sec": duration,
		"spawns": spawns,
		"teaches": teaches,
	}


func _spawn(at_sec: float, monster_id: String, lane: int) -> Dictionary:
	return {"at_sec": at_sec, "monster_id": monster_id, "lane": lane}


func _dish(satisfaction: float) -> Dictionary:
	return {
		"ok": true,
		"recipe_id": "test_recipe",
		"ingredient_id": "tortilla",
		"chain_length": 3,
		"chain_tier": "basic",
		"satisfaction_final": satisfaction,
		"special_effect_triggered": false,
		"special_effect": "",
		"special_effect_params": {},
	}


func _spawn_signature(payloads: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for payload in payloads:
		result.append("%s:%s:%s:%s" % [
			payload["source_index"],
			payload["monster_id"],
			payload["lane"],
			payload["spawn_sequence"],
		])
	return result


func _expect_error(result: Dictionary, error_code: String, label: String) -> void:
	_expect(not result.get("ok", true), "%s must fail" % label)
	_expect(result.get("error") == error_code, "%s must return %s" % [label, error_code])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
