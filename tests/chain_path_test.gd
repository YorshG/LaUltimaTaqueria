extends SceneTree

var failures := 0
var Chain = preload("res://scripts/board/chain_path.gd")


func _init() -> void:
	_test_chain_model()
	await _test_board_does_not_swap()

	if failures == 0:
		print("BRD-02 tests passed: orthogonal 3+, no diagonal/repeat/swap.")
		quit(0)
	else:
		push_error("BRD-02 tests failed: %d" % failures)
		quit(1)


func _test_chain_model() -> void:
	var chain = Chain.new()
	_expect(chain.try_add(Vector2i(0, 0), "tortilla"), "first cell should be accepted")
	_expect(chain.try_add(Vector2i(1, 0), "tortilla"), "orthogonal same ingredient should be accepted")
	_expect(chain.try_add(Vector2i(2, 0), "tortilla"), "third orthogonal cell should be accepted")
	_expect(chain.is_valid(), "three cells should form a valid chain")
	_expect(not chain.try_add(Vector2i(2, 1), "meat"), "different ingredient should be rejected")
	_expect(not chain.try_add(Vector2i(1, 0), "tortilla"), "repeated cell should be rejected")

	chain.reset()
	_expect(chain.try_add(Vector2i(0, 0), "tortilla"), "reset should allow a new first cell")
	_expect(not chain.try_add(Vector2i(1, 1), "tortilla"), "diagonal cell should be rejected")
	_expect(not chain.is_valid(), "single cell should not be valid")

	chain.reset()
	chain.try_add(Vector2i(0, 0), "tortilla")
	chain.try_add(Vector2i(1, 0), "tortilla")
	_expect(not chain.is_valid(), "two cells should not be valid")


func _test_board_does_not_swap() -> void:
	var packed: PackedScene = load("res://scenes/board/BoardView.tscn")
	var board = packed.instantiate()
	get_root().add_child(board)
	await process_frame

	var before: Array[String] = board.get_ingredient_snapshot()
	_expect(board.begin_chain_at(Vector2i(0, 0)), "board should start chain")
	_expect(board.extend_chain_to(Vector2i(1, 0)), "board should extend chain")
	_expect(board.extend_chain_to(Vector2i(2, 0)), "board should accept third cell")
	var completed = board.finish_chain()
	_expect(completed.size() == 3, "board should complete a 3-cell chain")
	var after: Array[String] = board.get_ingredient_snapshot()
	_expect(before == after, "capturing a chain must not swap or mutate board ingredients")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
