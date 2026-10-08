extends Control

const Art = preload("res://scripts/visuals/art_01_style.gd")
const IngredientVisual = preload("res://scripts/visuals/ingredient_visual.gd")
var _points: Array[Vector2i] = []
var _board: BoardView

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = get_parent() as BoardView
	_board.ready.connect(_bind, CONNECT_ONE_SHOT)
	resized.connect(queue_redraw)


func _bind() -> void:
	for cell in _board.grid.get_children():
		cell.resized.connect(queue_redraw)
		var visual := IngredientVisual.new()
		visual.name = "IngredientVisual"
		cell.add_child(visual)
	_board.chain_started.connect(_on_chain)
	_board.chain_changed.connect(_on_chain)
	_board.chain_completed.connect(func(_accepted, _ingredient): _clear())
	_board.chain_cancelled.connect(_clear)


func _on_chain(points: Array[Vector2i]) -> void:
	_points = points.duplicate()
	queue_redraw()


func _clear() -> void:
	_points.clear()
	queue_redraw()


func _draw() -> void:
	if _board == null or _board.grid == null: return
	var centers := PackedVector2Array()
	for point in _points:
		var cell := _board.grid.get_child(point.y * 5 + point.x) as Control
		var rect := get_global_transform().affine_inverse() * cell.get_global_rect()
		draw_rect(rect.grow(-3), Art.color("ink"), false, 9)
		draw_rect(rect.grow(-3), Art.color("target"), false, 4)
		centers.append(rect.get_center())
	if centers.size() > 1:
		draw_polyline(centers, Art.color("ink"), 12, true)
		draw_polyline(centers, Art.color("target"), 6, true)
