extends RefCounted
const Base = preload("res://tests/art_01c_fixture.gd")
const TURNS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
const EDGE: Array[Vector2i] = [Vector2i(4, 4), Vector2i(3, 4), Vector2i(3, 3), Vector2i(2, 3), Vector2i(2, 2)]

static func arrange(board: BoardView, path: Array[Vector2i], ingredient: String) -> void:
	# Test-only staging through BoardState; same board is used by both references.
	var cells := board.get_ingredient_snapshot()
	for point in path: cells[point.y * 5 + point.x] = ingredient
	board._board_state.reset(Base.BOARD_SEED, cells)
	board._ingredients = board._board_state.snapshot()
	board._sync_cells()

static func populate(main, mode: String = "regular") -> Array[Dictionary]:
	var snapshot := Base.populate(main, mode)
	if mode == "subunit":
		for index in range(3):
			var state = main.lane_field._runners[index].monster_state
			state.apply_satisfaction([29.8, 2.375, 0.5][index])
			snapshot[index].remaining = state.hunger_remaining
	if mode == "turns" or mode.begins_with("chain-"):
		arrange(main.board_view, TURNS, "tortilla")
	return snapshot

static func select(board: BoardView, mode: String) -> void:
	if mode == "unselected": return
	var path: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)]
	if mode == "turns" or mode.begins_with("chain-"):
		path = TURNS.slice(0, int(mode.trim_prefix("chain-")) if mode.begins_with("chain-") else 5)
	board.begin_chain_at(path[0])
	for point in path.slice(1): board.extend_chain_to(point)
