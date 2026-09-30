extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
const MAIN = preload("res://scenes/Main.tscn")

# Keep the real offer/selection implementation; only pin the run seed.
class SeededSelector extends UpgradeSelector:
	var fixture_seed := 2
	func start_run(_seed: int) -> Dictionary:
		return super.start_run(fixture_seed)

var failures := 0
var checks := 0
var content: Dictionary

func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "real content validates")
	content = loaded["content"]
	await _test_each_wave_and_repeat()
	await _test_failures_and_late_ownership()
	await _test_public_run(2, ["warm_welcome", "slow_salsa_plus", "last_stand", "chain4_boost", "taco_power_1"])
	await _test_public_run(5, ["slow_salsa", "safety_shield", "steady_hands", "reputation_boost", "warm_welcome"])
	await _test_threshold_and_defenses()
	await _test_composition_and_special_effects()
	if failures == 0:
		print("UPG-02f tests passed: %d checks; encounter runs, failures, late selection, synchronous boss, strict threshold and D4 isolation." % checks)
	else:
		push_error("UPG-02f tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _create_main(seed_value: int = 2):
	var main = MAIN.instantiate()
	var selector = main.get_node("%UpgradeSelector")
	selector.set_script(SeededSelector)
	selector.fixture_seed = seed_value
	root.add_child(main)
	await process_frame
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(p: Dictionary):
		main.wave_director.get_spawned_runner(p["spawn_sequence"]).auto_advance = false)
	main.boss_started.connect(func(_p: Dictionary): main.boss_runner.auto_advance = false)
	return main

func _select_fixture(main, ids: Array) -> void:
	# Public offer fixture, not an encounter: a completion signal alone must not arm.
	for i in range(ids.size()):
		main.wave_director.wave_completed.emit({"wave_id": "fixture_%d" % i})
		_expect(main.upgrade_selector.select_upgrade(ids[i])["ok"], "fixed public offer contains %s" % ids[i])

func _spawn_target(main) -> LaneRunner:
	var target: LaneRunner = main.lane_field.spawn_runner(1, 55.0, "T", "salsa_tank", 10000.0)
	target.auto_advance = false
	return target

func _dish(main, length: int = 3, ingredient: String = "tortilla") -> Dictionary:
	var points: Array[Vector2i] = []
	for i in range(length):
		points.append(Vector2i(i % 5, i / 5))
	return main._on_chain_completed(points, ingredient)

func _start(main, wave_id: String) -> void:
	_expect(main.wave_director.start_wave(wave_id, 1.0)["ok"], "wave starts: %s" % wave_id)
	var idle := _dish(main)
	_expect(idle["ok"] and not idle["target_found"], "countdown has no service")
	main.wave_director.advance(1000.0)

func _clear_wave(main) -> void:
	while main.wave_director.get_pending_count() > 0:
		var result: Dictionary = main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 10000.0})
		_expect(result["ok"] and result["target_found"], "fixture clears remaining normal monsters")
	_expect(main.wave_director.state == WaveDirector.State.COMPLETED, "real wave is completed")

func _test_each_wave_and_repeat() -> void:
	var main = await _create_main()
	_select_fixture(main, ["warm_welcome"])
	# warm_welcome is owned before the first run; cover all five IDs and a repeated ID.
	for wave_id in ["wave_01", "wave_02", "wave_03", "wave_04", "wave_05", "wave_01"]:
		_start(main, wave_id)
		_sat(_dish(main), 60.0, "first service doubles in %s" % wave_id)
		_sat(_dish(main), 30.0, "second service is neutral in %s" % wave_id)
		_clear_wave(main)
	main.queue_free()
	await process_frame

func _test_failures_and_late_ownership() -> void:
	var main = await _create_main()
	_select_fixture(main, ["warm_welcome"])
	_expect(main.wave_director.start_wave("wave_01", 0.0)["ok"], "failure fixture starts")
	main.wave_director.advance(2.0)
	var target: LaneRunner = main.lane_field.select_nearest_target()
	target.motion.progress = 1.0
	var missing := _dish(main)
	_expect(missing["ok"] and not missing["target_found"], "no-target ok does not mean served")
	target.motion.progress = 0.0
	_expect(not _dish(main, 2)["ok"], "invalid chain rejects before service")
	_expect(not _dish(main, 3, "unknown")["ok"], "resolver error rejects before service")
	# Real LaneField rejection after target selection, through its synchronous event.
	main.lane_field.dish_created.connect(func(_p: Dictionary): target.monster_state.active = false, CONNECT_ONE_SHOT)
	var rejected := _dish(main)
	_expect(not rejected["ok"] and rejected["target_found"], "selected target can reject actual service")
	target.monster_state.active = true
	_sat(_dish(main), 60.0, "all failed attempts preserve first service")
	# No remaining target until the next scheduled spawn; it must not rearm.
	_expect(not _dish(main)["target_found"], "gap between spawns has no target")
	main.wave_director.advance(6.0)
	_sat(_dish(main), 30.0, "later spawn in same run does not rearm")
	main.queue_free()
	await process_frame

	main = await _create_main()
	_start(main, "wave_01")
	_sat(_dish(main), 30.0, "unowned first service still consumes encounter state")
	_select_fixture(main, ["warm_welcome"])
	_sat(_dish(main), 30.0, "mid-encounter ownership cannot retroactively grant first service")
	_clear_wave(main)
	_start(main, "wave_02")
	_sat(_dish(main), 60.0, "new encounter after late selection gets bonus")
	main.queue_free()
	await process_frame

	main = await _create_main()
	_select_fixture(main, ["warm_welcome"])
	_spawn_target(main)
	_sat(_dish(main), 30.0, "direct LaneField spawn without encounter remains unarmed")
	main.queue_free()
	await process_frame

func _test_public_run(seed_value: int, path: Array) -> void:
	var main = await _create_main(seed_value)
	var starts: Array[Dictionary] = []
	main.boss_started.connect(func(p: Dictionary): starts.append(p))
	# Main's existing wave_completed callback offers first. This listener selects
	# synchronously while the final dish is still inside LaneField.resolve_dish.
	main.wave_director.wave_completed.connect(func(_p: Dictionary):
		var index: int = main.upgrade_selector.get_selection_count()
		_expect(main.upgrade_selector.select_upgrade(path[index])["ok"], "real wave offers pinned selection")
	)
	for i in range(5):
		_start(main, "wave_%02d" % (i + 1))
		var first := true
		while main.wave_director.get_pending_count() > 0:
			var owned: bool = "warm_welcome" in main.upgrade_selector.get_selected_upgrade_ids()
			var result := _dish(main)
			_sat(result, 60.0 if owned and first else 30.0, "real run wave first/nonfirst amount")
			first = false
		_expect(main.upgrade_selector.get_selection_count() == i + 1, "one selection per completed wave")
	_expect(starts.size() == 1 and main.boss_has_started, "fifth synchronous selection starts exactly one boss")
	var base := 34.5 if seed_value == 2 else 30.0
	_sat(_dish(main), base * 2.0, "finishing wave five must not consume newly armed boss bonus")
	_sat(_dish(main), base, "boss bonus consumed once")
	_expect(main.wave_director.current_wave_id == "wave_05" and not main.wave_director.has_wave("wave_06"), "boss is a separate encounter, never wave six")
	main.queue_free()
	await process_frame

func _test_threshold_and_defenses() -> void:
	var main = await _create_main(20260921)
	_select_fixture(main, ["last_stand", "slow_salsa", "taco_power_1", "patient_service", "reputation_boost"])
	_spawn_target(main)
	_expect(main.reputation.maximum == 115.0, "public reputation_boost sets max 115")
	main.reputation.apply_damage(77.0)
	_expect(main.reputation.current == 23.0, "exact 23/115 fixture")
	_sat(_dish(main), 34.5, "exactly 20 percent at 23/115 excludes last_stand")
	main.reputation.apply_damage(0.0115)
	_sat(_dish(main), 43.125, "19.99 percent includes last_stand")
	main.reputation.restore(10.0)
	_sat(_dish(main), 34.5, "recovery is read live on the next dish")
	var before: float = main.reputation.current
	main.reputation.apply_breach({"spawn_sequence": 900, "monster_id": "nibbler"})
	_expect(is_equal_approx(main.reputation.current, before - 8.5), "patient_service mitigates breach in same run")
	_sat(_dish(main), 34.5, "mitigated breach remains above threshold")
	main.reputation.apply_breach({"spawn_sequence": 901, "monster_id": "nibbler"})
	_sat(_dish(main), 43.125, "later mitigated breach crosses threshold")
	main.queue_free()
	await process_frame

	main = await _create_main(2)
	_select_fixture(main, ["slow_salsa_plus", "taco_power_1", "warm_welcome", "last_stand", "second_chance"])
	_spawn_target(main)
	main.reputation.apply_damage(80.0)
	_sat(_dish(main), 34.5, "exact 20/100 excludes last_stand")
	main.reputation.apply_damage(0.01)
	_sat(_dish(main), 43.125, "19.99/100 includes last_stand")
	main.reputation.apply_damage(1000.0)
	_expect(main.reputation.current == 25.0 and main.reputation.extra_life_charges == 0, "second_chance restores atomically to 25 percent")
	_sat(_dish(main), 34.5, "restored 25 percent disables last_stand immediately")
	main.queue_free()
	await process_frame

func _test_composition_and_special_effects() -> void:
	# Compare paired real services, with and without live conditions; special
	# power is tested both neutral and boosted. No injected effect snapshots.
	for boosted in [false, true]:
		for ingredient in ["tortilla", "meat", "veggie"]:
			var main = await _create_main(25)
			var path := ["patient_service", "last_stand", "warm_welcome"]
			if boosted:
				path.append("chain5_effect_boost")
				path.append("taco_power_2")
			_select_fixture(main, path)
			var effects_before: Array = main.upgrade_selector.get_active_effects()
			var snapshot_before := Modifiers.derive(effects_before)
			var target := _spawn_target(main)
			var ordinary := _dish(main, 5, ingredient)
			target.monster_state.apply_satisfaction(10000.0)
			_start(main, "wave_01")
			# High-hunger primary makes applied burst/stun/restoration observable.
			target = _spawn_target(main)
			target.motion.progress = 0.9
			main.reputation.apply_damage(81.0)
			var low := _dish(main, 5, ingredient)
			_sat(low, ordinary["dish"]["satisfaction_final"] * 2.0 * 1.25, "warm * last * taco compose multiplicatively")
			_expect(low["dish"]["special_effect_params"] == ordinary["dish"]["special_effect_params"], "conditionals do not scale %s" % ingredient)
			var power := 1.3 if boosted else 1.0
			match ingredient:
				"tortilla":
					_expect(is_equal_approx(target.motion.stun_remaining_sec, power), "actual stun only receives special power")
				"meat":
					_expect(is_equal_approx(low["served"]["satisfaction_applied"], low["dish"]["satisfaction_final"] + 12.0 * power), "actual burst is independent addition")
				"veggie":
					_expect(is_equal_approx(main.reputation.current, 19.0 + 5.0 * power), "actual veggie restoration is independent")
			var next := _dish(main, 5, ingredient)
			var remaining_multiplier := 1.0 if ingredient == "veggie" else 1.25
			_sat(next, ordinary["dish"]["satisfaction_final"] * remaining_multiplier, "next dish reevaluates reputation after veggie and consumes warm")
			_expect(main.upgrade_selector.get_active_effects() == effects_before and Modifiers.derive(effects_before) == snapshot_before, "effective snapshot never mutates owned effects or pure modifiers")
			main.queue_free()
			await process_frame

func _sat(result: Dictionary, expected: float, message: String) -> void:
	_expect(result.get("ok", false) and result.get("target_found", false) and not result.get("served", {}).is_empty(), message + ": real service")
	_expect(is_equal_approx(result.get("dish", {}).get("satisfaction_final", -1.0), expected), "%s: expected %s, got %s" % [message, expected, result.get("dish", {})])

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
