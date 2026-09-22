extends SceneTree

var failures := 0


func _init() -> void:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")
	_expect(packed != null, "LaneField scene must load")
	if packed == null:
		quit(1)
		return
	var field: LaneField = packed.instantiate()
	get_root().add_child(field)
	await process_frame

	_test_empty_and_single(field)
	_test_cross_lane_targeting(field)
	_test_same_lane_tie_and_node_order(field)
	_test_ineligible_states(field)
	_test_consecutive_resolution(field)

	if failures == 0:
		print("LANE-02 targeting tests passed: eligibility, progress, lane and spawn tie-breaks.")
		quit(0)
	else:
		push_error("LANE-02 targeting tests failed: %d" % failures)
		quit(1)


func _test_empty_and_single(field: LaneField) -> void:
	_expect(field.select_nearest_target() == null, "zero monsters must produce no target")
	var only := field.spawn_runner(0, 55.0, "A", "nibbler", 30.0)
	only.auto_advance = false
	only.motion.progress = 0.25
	_expect(field.select_nearest_target() == only, "single eligible monster must be targeted")
	only.monster_state.active = false


func _test_cross_lane_targeting(field: LaneField) -> void:
	var left := field.spawn_runner(0, 55.0, "L", "nibbler", 30.0)
	var center := field.spawn_runner(1, 55.0, "C", "nibbler", 30.0)
	var right := field.spawn_runner(2, 55.0, "R", "nibbler", 30.0)
	for runner in [left, center, right]:
		runner.auto_advance = false

	left.motion.progress = 0.4
	center.motion.progress = 0.6
	right.motion.progress = 0.8
	_expect(field.select_nearest_target() == right, "greatest progress must win across lanes")

	left.motion.progress = 0.5
	center.motion.progress = 0.5
	right.motion.progress = 0.1
	_expect(field.select_nearest_target() == center, "center must beat left on progress tie")
	right.motion.progress = 0.5
	_expect(field.select_nearest_target() == center, "center must beat right on progress tie")
	center.monster_state.active = false
	_expect(field.select_nearest_target() == left, "left must beat right on progress tie")

	left.monster_state.active = false
	right.monster_state.active = false


func _test_same_lane_tie_and_node_order(field: LaneField) -> void:
	var first := field.spawn_runner(2, 55.0, "1", "nibbler", 30.0)
	var second := field.spawn_runner(2, 55.0, "2", "nibbler", 30.0)
	first.auto_advance = false
	second.auto_advance = false
	first.motion.progress = 0.7
	second.motion.progress = 0.7
	_expect(
		first.monster_state.spawn_sequence < second.monster_state.spawn_sequence,
		"spawn sequence must be monotonic"
	)
	_expect(field.select_nearest_target() == first, "earlier spawn must win same-lane tie")
	field.get_lane_host(2).move_child(second, 0)
	_expect(field.select_nearest_target() == first, "node order must not affect targeting")
	first.monster_state.active = false
	second.monster_state.active = false


func _test_ineligible_states(field: LaneField) -> void:
	var satisfied := field.spawn_runner(0, 55.0, "S", "nibbler", 10.0)
	var inactive := field.spawn_runner(1, 55.0, "I", "nibbler", 10.0)
	var at_counter := field.spawn_runner(2, 55.0, "E", "nibbler", 10.0)
	var past_counter := field.spawn_runner(0, 55.0, "P", "nibbler", 10.0)
	for runner in [satisfied, inactive, at_counter, past_counter]:
		runner.auto_advance = false
		runner.motion.progress = 0.9

	satisfied.monster_state.apply_satisfaction(10.0)
	inactive.monster_state.active = false
	at_counter.motion.progress = 1.0
	past_counter.motion.progress = 1.1
	_expect(field.select_nearest_target() == null, "satisfied, inactive and progress >= 1 must be excluded")


func _test_consecutive_resolution(field: LaneField) -> void:
	var target := field.spawn_runner(1, 55.0, "T", "nibbler", 10.0)
	target.auto_advance = false
	target.motion.progress = 0.3
	var resolution := {
		"ok": true,
		"recipe_id": "test_recipe",
		"ingredient_id": "tortilla",
		"chain_length": 3,
		"chain_tier": "basic",
		"satisfaction_final": 10.0,
		"special_effect_triggered": false,
		"special_effect": "",
		"special_effect_params": {},
	}
	var first: Dictionary = field.resolve_dish(resolution)
	var second: Dictionary = field.resolve_dish(resolution)
	_expect(first["target_found"], "first consecutive dish must find the sole monster")
	_expect(first["monster_became_satisfied"], "first dish must satisfy the monster")
	_expect(not second["target_found"], "second dish must recalculate and find no target")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
