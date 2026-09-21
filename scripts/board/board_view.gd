class_name BoardView
extends Control

signal chain_started(points: Array[Vector2i])
signal chain_changed(points: Array[Vector2i])
signal chain_completed(points: Array[Vector2i], ingredient_id: String)
signal chain_cancelled()

const BoardStateModel = preload("res://scripts/board/board_state.gd")

const BOARD_COLUMNS := 5
const BOARD_ROWS := 5
const DEFAULT_BOARD_SEED := 20260920
const PLACEHOLDER_LAYOUT := [
	"tortilla", "tortilla", "tortilla", "meat", "veggie",
	"meat", "veggie", "tortilla", "meat", "veggie",
	"veggie", "tortilla", "meat", "veggie", "tortilla",
	"tortilla", "meat", "veggie", "tortilla", "meat",
	"meat", "veggie", "tortilla", "meat", "veggie",
]
const LABELS := {
	"tortilla": "T",
	"meat": "M",
	"veggie": "V",
}

@onready var grid: GridContainer = %Grid

var _chain := ChainPath.new()
var _dragging := false
var _ingredients: Array[String] = []
var _board_state = BoardStateModel.new()
var _board_seed := DEFAULT_BOARD_SEED


func _ready() -> void:
	_build_cells()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_from_position(touch.position)
		else:
			_finish_chain()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_extend_from_position(drag.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_from_position(button.position)
			else:
				_finish_chain()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_extend_from_position(motion.position)


func begin_chain_at(coord: Vector2i) -> bool:
	_chain.reset()
	_dragging = false
	var ingredient := ingredient_at(coord)
	if ingredient.is_empty() or not _chain.try_add(coord, ingredient):
		return false
	_dragging = true
	_refresh_selection()
	chain_started.emit(_chain.points())
	return true


func extend_chain_to(coord: Vector2i) -> bool:
	if not _dragging:
		return false
	var ingredient := ingredient_at(coord)
	if ingredient.is_empty() or not _chain.try_add(coord, ingredient):
		return false
	_refresh_selection()
	chain_changed.emit(_chain.points())
	return true


func finish_chain() -> Array[Vector2i]:
	if not _dragging:
		return []
	_dragging = false
	var result := _chain.points()
	var ingredient := _chain.ingredient_id()
	var valid := _chain.is_valid(3)
	if valid:
		_resolve_chain(result)
		chain_completed.emit(result, ingredient)
	else:
		chain_cancelled.emit()
	_chain.reset()
	_refresh_selection()
	return result if valid else []


func ingredient_at(coord: Vector2i) -> String:
	if coord.x < 0 or coord.x >= BOARD_COLUMNS or coord.y < 0 or coord.y >= BOARD_ROWS:
		return ""
	var index := coord.y * BOARD_COLUMNS + coord.x
	if index < 0 or index >= _ingredients.size():
		return ""
	return _ingredients[index]


func get_ingredient_snapshot() -> Array[String]:
	return _ingredients.duplicate()


func get_cell_count() -> int:
	return grid.get_child_count()


func get_column_count() -> int:
	return grid.columns


func reset_with_seed(seed: int) -> void:
	_board_seed = seed
	_board_state.reset(_board_seed, PLACEHOLDER_LAYOUT)
	_ingredients = _board_state.snapshot()
	_sync_cells()


func get_board_seed() -> int:
	return _board_seed


func _build_cells() -> void:
	for child in grid.get_children():
		child.queue_free()

	_board_state.reset(_board_seed, PLACEHOLDER_LAYOUT)
	_ingredients = _board_state.snapshot()
	grid.columns = BOARD_COLUMNS

	for index in range(BOARD_COLUMNS * BOARD_ROWS):
		var coord := Vector2i(index % BOARD_COLUMNS, index / BOARD_COLUMNS)
		var ingredient := _ingredients[index]
		var cell := Button.new()
		cell.name = "Cell_%02d" % index
		cell.text = LABELS.get(ingredient, "?")
		cell.disabled = true
		cell.focus_mode = Control.FOCUS_NONE
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.custom_minimum_size = Vector2(52.0, 52.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = ingredient
		cell.set_meta("coord", coord)
		cell.set_meta("ingredient_id", ingredient)
		grid.add_child(cell)


func _resolve_chain(points: Array[Vector2i]) -> void:
	_board_state.resolve_chain(points)
	_ingredients = _board_state.snapshot()
	_sync_cells()


func _sync_cells() -> void:
	if not is_instance_valid(grid):
		return
	for child in grid.get_children():
		var coord: Vector2i = child.get_meta("coord", Vector2i(-1, -1))
		var ingredient := ingredient_at(coord)
		child.text = LABELS.get(ingredient, "?")
		child.tooltip_text = ingredient
		child.set_meta("ingredient_id", ingredient)


func _begin_from_position(position: Vector2) -> void:
	var coord := _coord_at_position(position)
	if coord.x >= 0:
		begin_chain_at(coord)


func _extend_from_position(position: Vector2) -> void:
	if not _dragging:
		return
	var coord := _coord_at_position(position)
	if coord.x >= 0:
		extend_chain_to(coord)


func _finish_chain() -> void:
	finish_chain()


func _coord_at_position(position: Vector2) -> Vector2i:
	for child in grid.get_children():
		if child is Control and (child as Control).get_global_rect().has_point(position):
			return child.get_meta("coord", Vector2i(-1, -1))
	return Vector2i(-1, -1)


func _refresh_selection() -> void:
	var selected := _chain.points()
	for child in grid.get_children():
		var coord: Vector2i = child.get_meta("coord", Vector2i(-1, -1))
		child.modulate = Color(0.75, 0.9, 1.0, 1.0) if coord in selected else Color.WHITE
