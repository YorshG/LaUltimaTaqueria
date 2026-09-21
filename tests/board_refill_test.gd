extends SceneTree

var failures := 0
var BoardStateModel = preload("res://scripts/board/board_state.gd")


func _init() -> void:
	_test_gravity_fill_and_seed_determinism()
	await _test_board_integration_determinism()

	if failures == 0:
		print("BRD-03 tests passed: gravity, refill, no holes, deterministic seed.")
		quit(0)
	else:
		push_error("BRD-03 tests failed: %d" % failures)
		quit(1)


func _test_gravity_fill_and_seed_determinism() -> void:
	var layout := [
		"meat", "tortilla", "veggie", "meat", "veggie",
		"veggie", "meat", "tortilla", "veggie", "meat",
		"tortilla", "veggie", "meat", "tortilla", "veggie",
		"tortilla", "meat", "veggie", "meat", "tortilla",
		"tortilla", "veggie", "meat", "veggie", "meat",
	]
	var points: Array[Vector2i] = [
		Vector2i(0, 2),
		Vector2i(0, 3),
		Vector2i(0, 4),
	]

	var first = BoardStateModel.new()
	first.reset(77, layout)
	first.resolve_chain(points)
	var first_snapshot: Array[String] = first.snapshot()

	_expect(first_snapshot.size() == 25, "resolved board must keep exactly 25 cells")
	_expect(not first.has_empty_cells(), "resolved board must not contain holes")
	_expect(first_snapshot[_index(Vector2i(0, 3))] == "meat", "gravity must move the upper meat cell down")
	_expect(first_snapshot[_index(Vector2i(0, 4))] == "veggie", "gravity must move the upper veggie cell to the bottom")

	var second = BoardStateModel.new()
	second.reset(77, layout)
	second.resolve_chain(points)
	_expect(first_snapshot == second.snapshot(), "same seed and same resolved chain must produce the same board")


func _test_board_integration_determinism() -> void:
	var packed: PackedScene = load("res://scenes/board/BoardView.tscn")
	_expect(packed != null, "BoardView scene must load for BRD-03 integration test")
	if packed == null:
		return

	var first = packed.instantiate()
	var second = packed.instantiate()
	get_root().add_child(first)
	get_root().add_child(second)
	await process_frame

	first.reset_with_seed(123456)
	second.reset_with_seed(123456)

	_resolve_placeholder_chain(first)
	_resolve_placeholder_chain(second)

	var first_snapshot: Array[String] = first.get_ingredient_snapshot()
	var second_snapshot: Array[String] = second.get_ingredient_snapshot()
	_expect(first_snapshot == second_snapshot, "same seed and same gestures must produce identical board snapshots")
	for ingredient in first_snapshot:
		_expect(not ingredient.is_empty(), "BoardView refill must leave no empty cells")


func _resolve_placeholder_chain(board) -> void:
	_expect(board.begin_chain_at(Vector2i(0, 0)), "placeholder chain should start")
	_expect(board.extend_chain_to(Vector2i(1, 0)), "placeholder chain should include second tortilla")
	_expect(board.extend_chain_to(Vector2i(2, 0)), "placeholder chain should include third tortilla")
	var completed = board.finish_chain()
	_expect(completed.size() == 3, "placeholder chain should resolve as a valid chain")


func _index(coord: Vector2i) -> int:
	return coord.y * 5 + coord.x


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
