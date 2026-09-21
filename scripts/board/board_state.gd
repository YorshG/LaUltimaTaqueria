class_name BoardState
extends RefCounted

const BOARD_COLUMNS := 5
const BOARD_ROWS := 5
const INGREDIENT_IDS := ["tortilla", "meat", "veggie"]

var _cells: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _seed := 0


func reset(seed: int, layout: Array) -> void:
	assert(layout.size() == BOARD_COLUMNS * BOARD_ROWS)
	_seed = seed
	_rng.seed = seed
	_cells.clear()
	for value in layout:
		_cells.append(String(value))


func resolve_chain(points: Array[Vector2i]) -> void:
	for point in points:
		if _is_inside(point):
			_cells[_index(point)] = ""

	for column in range(BOARD_COLUMNS):
		_collapse_and_fill_column(column)


func ingredient_at(coord: Vector2i) -> String:
	if not _is_inside(coord):
		return ""
	return _cells[_index(coord)]


func snapshot() -> Array[String]:
	return _cells.duplicate()


func seed() -> int:
	return _seed


func has_empty_cells() -> bool:
	for ingredient in _cells:
		if ingredient.is_empty():
			return true
	return false


func _collapse_and_fill_column(column: int) -> void:
	var write_y := BOARD_ROWS - 1

	for read_y in range(BOARD_ROWS - 1, -1, -1):
		var read_index := read_y * BOARD_COLUMNS + column
		var ingredient := _cells[read_index]
		if ingredient.is_empty():
			continue

		var write_index := write_y * BOARD_COLUMNS + column
		_cells[write_index] = ingredient
		if write_index != read_index:
			_cells[read_index] = ""
		write_y -= 1

	while write_y >= 0:
		_cells[write_y * BOARD_COLUMNS + column] = _next_ingredient()
		write_y -= 1


func _next_ingredient() -> String:
	var index := _rng.randi_range(0, INGREDIENT_IDS.size() - 1)
	return INGREDIENT_IDS[index]


func _index(coord: Vector2i) -> int:
	return coord.y * BOARD_COLUMNS + coord.x


func _is_inside(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < BOARD_COLUMNS and coord.y >= 0 and coord.y < BOARD_ROWS
