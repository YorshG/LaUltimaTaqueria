class_name BoardState
extends RefCounted

const BOARD_COLUMNS := 5
const BOARD_ROWS := 5
const INGREDIENT_IDS := ["tortilla", "meat", "veggie"]
const MINIMUM_CHAIN_LENGTH := 3
const MAXIMUM_SHUFFLE_ATTEMPTS := 16
const ORTHOGONAL_DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var _cells: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _seed := 0


func reset(seed: int, layout: Array) -> bool:
	assert(layout.size() == BOARD_COLUMNS * BOARD_ROWS)
	_seed = seed
	_rng.seed = seed
	_cells.clear()
	for value in layout:
		_cells.append(String(value))
	return ensure_playable()


func resolve_chain(points: Array[Vector2i]) -> bool:
	for point in points:
		if _is_inside(point):
			_cells[_index(point)] = ""

	for column in range(BOARD_COLUMNS):
		_collapse_and_fill_column(column)
	return ensure_playable()


func has_valid_chain() -> bool:
	var visited: Array[bool] = []
	visited.resize(_cells.size())
	visited.fill(false)

	for start_index in range(_cells.size()):
		if visited[start_index]:
			continue
		var ingredient := _cells[start_index]
		if ingredient not in INGREDIENT_IDS:
			visited[start_index] = true
			continue
		if _connected_ingredient_count(start_index, ingredient, visited) >= MINIMUM_CHAIN_LENGTH:
			return true
	return false


func is_dead_board() -> bool:
	if _cells.size() != BOARD_COLUMNS * BOARD_ROWS:
		return false
	for ingredient in _cells:
		if ingredient not in INGREDIENT_IDS:
			return false
	return not has_valid_chain()


func ensure_playable() -> bool:
	if not is_dead_board():
		return false

	for attempt in range(MAXIMUM_SHUFFLE_ATTEMPTS):
		_shuffle_cells()
		if has_valid_chain():
			return true

	_force_valid_chain()
	assert(has_valid_chain())
	return true


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


func _connected_ingredient_count(start_index: int, ingredient: String, visited: Array[bool]) -> int:
	var pending: Array[int] = [start_index]
	var count := 0
	visited[start_index] = true

	while not pending.is_empty():
		var current_index: int = pending.pop_back()
		count += 1
		if count >= MINIMUM_CHAIN_LENGTH:
			return count

		var current := Vector2i(current_index % BOARD_COLUMNS, current_index / BOARD_COLUMNS)
		for direction in ORTHOGONAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not _is_inside(neighbor):
				continue
			var neighbor_index := _index(neighbor)
			if visited[neighbor_index] or _cells[neighbor_index] != ingredient:
				continue
			visited[neighbor_index] = true
			pending.append(neighbor_index)

	return count


func _shuffle_cells() -> void:
	for current_index in range(_cells.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, current_index)
		var displaced := _cells[current_index]
		_cells[current_index] = _cells[swap_index]
		_cells[swap_index] = displaced


func _force_valid_chain() -> void:
	var chain_ingredient := ""
	for ingredient in INGREDIENT_IDS:
		if _cells.count(ingredient) >= MINIMUM_CHAIN_LENGTH:
			chain_ingredient = ingredient
			break

	assert(not chain_ingredient.is_empty())
	for target_index in range(MINIMUM_CHAIN_LENGTH):
		if _cells[target_index] == chain_ingredient:
			continue
		var source_index := _cells.find(chain_ingredient, target_index + 1)
		assert(source_index > target_index)
		var displaced := _cells[target_index]
		_cells[target_index] = _cells[source_index]
		_cells[source_index] = displaced


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
