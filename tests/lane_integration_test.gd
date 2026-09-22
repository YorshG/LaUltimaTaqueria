extends SceneTree

var failures := 0
var Registry = preload("res://scripts/content/content_registry.gd")
var Resolver = preload("res://scripts/recipes/recipe_resolver.gd")


func _init() -> void:
	var registry_result: Dictionary = Registry.new().load_and_validate()
	_expect(registry_result["ok"], "content must validate before LANE-02 integration tests")
	if not registry_result["ok"]:
		quit(1)
		return
	var resolver = Resolver.new(registry_result["content"])

	await _test_board_recipe_lane_bridge()
	await _test_effects(resolver)
	await _test_rejected_base_stops_delivery()

	if failures == 0:
		print("LANE-02 integration tests passed: board bridge, events and scoped 5+ effects.")
		quit(0)
	else:
		push_error("LANE-02 integration tests failed: %d" % failures)
		quit(1)


func _test_board_recipe_lane_bridge() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main = packed.instantiate()
	get_root().add_child(main)
	await process_frame

	var runner: LaneRunner = main.lane_field.spawn_runner(1, 55.0, "N", "nibbler", 30.0)
	runner.auto_advance = false
	runner.motion.progress = 0.4
	var events: Array[String] = []
	var created_payloads: Array[Dictionary] = []
	var served_payloads: Array[Dictionary] = []
	var hunger_when_created: Array[float] = []
	main.lane_field.dish_created.connect(func(payload: Dictionary):
		events.append("dish_created")
		created_payloads.append(payload)
		hunger_when_created.append(runner.monster_state.hunger_remaining)
	)
	main.lane_field.dish_served.connect(func(payload: Dictionary):
		events.append("dish_served")
		served_payloads.append(payload)
	)
	main.lane_field.monster_satisfied.connect(func(_payload: Dictionary):
		events.append("monster_satisfied")
	)

	var invalid_points: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	main._on_chain_completed(invalid_points, "tortilla")
	_expect(created_payloads.is_empty(), "invalid resolver result must not emit dish_created")
	_expect(is_equal_approx(runner.monster_state.hunger_remaining, 30.0), "invalid resolver result must not apply satisfaction")

	_complete_initial_tortilla_chain(main.board_view)
	_expect(events == ["dish_created", "dish_served", "monster_satisfied"], "events must use stable order")
	_expect(created_payloads.size() == 1, "valid board chain must create one dish")
	if not created_payloads.is_empty():
		var payload := created_payloads[0]
		for key in ["recipe_id", "ingredient_id", "chain_length", "chain_tier", "satisfaction_final", "special_effect", "special_effect_params", "target_found"]:
			_expect(payload.has(key), "dish_created must include %s" % key)
		_expect(payload["target_found"], "first dish must report its target")
		_expect(is_equal_approx(payload["satisfaction_final"], 30.0), "LaneField must use resolver satisfaction unchanged")
	_expect(hunger_when_created == [30.0], "dish_created must emit before satisfaction is applied")
	_expect(served_payloads.size() == 1, "served dish must emit dish_served once")

	main.board_view.reset_with_seed(main.board_view.DEFAULT_BOARD_SEED)
	_complete_initial_tortilla_chain(main.board_view)
	_expect(created_payloads.size() == 2, "dish without target must still emit dish_created")
	_expect(not created_payloads[1]["target_found"], "dish without target must report target_found false")
	_expect(served_payloads.size() == 1, "dish without target must not emit dish_served")
	_expect(events.count("monster_satisfied") == 1, "monster_satisfied must emit exactly once")
	_expect(not main.lane_field.has_signal("reputation_changed"), "LANE-02 must not add reputation_changed")

	main.queue_free()
	await process_frame


func _test_effects(resolver) -> void:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")

	var stun_field: LaneField = packed.instantiate()
	get_root().add_child(stun_field)
	await process_frame
	var stun_target := stun_field.spawn_runner(1, 55.0, "T", "salsa_tank", 70.0)
	var other := stun_field.spawn_runner(0, 55.0, "O", "salsa_tank", 70.0)
	stun_target.auto_advance = false
	other.auto_advance = false
	stun_target.motion.progress = 0.8
	other.motion.progress = 0.2
	stun_field.resolve_dish(resolver.resolve("tortilla", 5))
	_expect(stun_target.motion.is_stunned(), "brief_stun must affect selected target")
	_expect(not other.motion.is_stunned(), "brief_stun must not affect other monsters")
	stun_field.queue_free()
	await process_frame

	var burst_field: LaneField = packed.instantiate()
	get_root().add_child(burst_field)
	await process_frame
	var burst_target := burst_field.spawn_runner(2, 55.0, "B", "salsa_tank", 70.0)
	burst_target.auto_advance = false
	var burst_result: Dictionary = burst_field.resolve_dish(resolver.resolve("meat", 5))
	_expect(is_equal_approx(burst_result["served"]["satisfaction_applied"], 66.0), "burst must add 12 after base 54")
	_expect(is_equal_approx(burst_target.monster_state.hunger_remaining, 4.0), "burst must use same target and path")
	burst_field.queue_free()
	await process_frame

	var no_spill_field: LaneField = packed.instantiate()
	get_root().add_child(no_spill_field)
	await process_frame
	var first := no_spill_field.spawn_runner(1, 55.0, "1", "swift_hopper", 60.0)
	var second := no_spill_field.spawn_runner(0, 55.0, "2", "salsa_tank", 70.0)
	first.auto_advance = false
	second.auto_advance = false
	first.motion.progress = 0.8
	second.motion.progress = 0.4
	no_spill_field.resolve_dish(resolver.resolve("meat", 5))
	_expect(first.monster_state.satisfied, "burst oversatisfaction must transition primary target")
	_expect(is_equal_approx(second.monster_state.hunger_remaining, 70.0), "burst overflow must not spill to another monster")
	no_spill_field.queue_free()
	await process_frame

	var reputation_field: LaneField = packed.instantiate()
	get_root().add_child(reputation_field)
	await process_frame
	var reputation_target := reputation_field.spawn_runner(0, 55.0, "V", "salsa_tank", 70.0)
	reputation_target.auto_advance = false
	var reputation_created: Array[Dictionary] = []
	reputation_field.dish_created.connect(func(payload: Dictionary): reputation_created.append(payload))
	reputation_field.resolve_dish(resolver.resolve("veggie", 5))
	_expect(is_equal_approx(reputation_target.monster_state.hunger_remaining, 34.0), "reputation effect must not alter satisfaction")
	_expect(reputation_created.size() == 1, "reputation dish must emit its payload")
	if not reputation_created.is_empty():
		_expect(reputation_created[0]["special_effect"] == "reputation_small_restore", "future reputation effect must remain in payload")
		_expect(reputation_created[0]["special_effect_params"] == {"amount": 5.0}, "future reputation params must remain in payload")
	reputation_field.queue_free()
	await process_frame


func _test_rejected_base_stops_delivery() -> void:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")
	var field: LaneField = packed.instantiate()
	get_root().add_child(field)
	await process_frame

	var target := field.spawn_runner(1, 55.0, "D", "nibbler", 30.0)
	target.auto_advance = false
	target.motion.progress = 0.5
	var event_counts := {"created": 0, "served": 0, "satisfied": 0}
	field.dish_created.connect(func(_payload: Dictionary): event_counts["created"] += 1)
	field.dish_served.connect(func(_payload: Dictionary): event_counts["served"] += 1)
	field.monster_satisfied.connect(func(_payload: Dictionary): event_counts["satisfied"] += 1)
	var invalid_resolution := {
		"ok": true,
		"recipe_id": "synthetic_invalid_recipe",
		"ingredient_id": "tortilla",
		"chain_length": 5,
		"chain_tier": "chain5_plus",
		"satisfaction_final": 0.0,
		"special_effect_triggered": true,
		"special_effect": "brief_stun",
		"special_effect_params": {"duration_sec": 1.0},
	}
	var result: Dictionary = field.resolve_dish(invalid_resolution)

	_expect(not result["ok"], "rejected base satisfaction must return explicit failure")
	_expect(not result["satisfaction_result"]["ok"], "apply_satisfaction failure must remain explicit")
	_expect(result["error"] == MonsterState.INVALID_SATISFACTION, "failure must preserve MonsterState error")
	_expect(result["target_found"], "defensive failure must preserve that a target was found")
	_expect(event_counts["created"] == 1, "dish_created may precede defensive satisfaction rejection")
	_expect(event_counts["served"] == 0, "rejected base satisfaction must not emit dish_served")
	_expect(event_counts["satisfied"] == 0, "rejected base satisfaction must not emit monster_satisfied")
	_expect(is_equal_approx(target.monster_state.hunger_remaining, 30.0), "rejected base must preserve hunger")
	_expect(target.monster_state.active and not target.monster_state.satisfied, "rejected base must preserve state")
	_expect(not target.motion.is_stunned(), "rejected base must not execute brief_stun")
	field.queue_free()
	await process_frame


func _complete_initial_tortilla_chain(board: BoardView) -> void:
	_expect(board.begin_chain_at(Vector2i(0, 0)), "initial tortilla chain must start")
	_expect(board.extend_chain_to(Vector2i(1, 0)), "initial tortilla chain must extend once")
	_expect(board.extend_chain_to(Vector2i(2, 0)), "initial tortilla chain must extend twice")
	_expect(board.finish_chain().size() == 3, "initial tortilla chain must complete")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
