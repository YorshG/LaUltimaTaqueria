class_name BoardView
extends Control

const BOARD_COLUMNS := 5
const BOARD_ROWS := 5
const PLACEHOLDER_LABELS := ["T", "M", "V"]

@onready var grid: GridContainer = %Grid


func _ready() -> void:
	_build_cells()


func _build_cells() -> void:
	for child in grid.get_children():
		child.queue_free()
	grid.columns = BOARD_COLUMNS

	for index in range(BOARD_COLUMNS * BOARD_ROWS):
		var cell := Button.new()
		cell.name = "Cell_%02d" % index
		cell.text = PLACEHOLDER_LABELS[index % PLACEHOLDER_LABELS.size()]
		cell.disabled = true
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(52.0, 52.0)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = "Placeholder visual — sin gameplay"
		grid.add_child(cell)


func get_cell_count() -> int:
	return grid.get_child_count()


func get_column_count() -> int:
	return grid.columns
