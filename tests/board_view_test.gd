extends SceneTree

var failures := 0


func _init() -> void:
	var packed: PackedScene = load("res://scenes/board/BoardView.tscn")
	_expect(packed != null, "BoardView scene must load")
	if packed == null:
		quit(1)
		return

	var board = packed.instantiate()
	get_root().add_child(board)
	await process_frame

	_expect(board.get_cell_count() == 25, "BoardView must render exactly 25 cells")
	_expect(board.get_column_count() == 5, "BoardView must use exactly 5 columns")
	_expect(board.custom_minimum_size.x > 0.0 and board.custom_minimum_size.y > 0.0, "BoardView must have a usable minimum size")

	if failures == 0:
		print("BoardView tests passed: 25 cells / 5 columns.")
		quit(0)
	else:
		push_error("BoardView tests failed: %d" % failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
