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
	# BoardView's legacy tint is presentation only. Keep atlas pixels unchanged;
	# selection lives in this independent outline, never in ingredient modulation.
	for cell in _board.grid.get_children():
		cell.modulate = Color.WHITE
	queue_redraw()


func _clear() -> void:
	_points.clear()
	queue_redraw()


## Geometry is read from the existing cells; drawing never moves their hitboxes.
func selection_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if _board == null or _board.grid == null: return result
	for point in _points:
		var cell := _board.grid.get_child(point.y * 5 + point.x) as Control
		result.append(get_global_transform().affine_inverse() * cell.get_global_rect())
	return result

func connection_segments() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var rects := selection_rects()
	for index in range(1, rects.size()):
		var delta := _points[index] - _points[index - 1]
		# Defensive presentation guard; ChainPath remains the selection authority.
		if absi(delta.x) + absi(delta.y) != 1: continue
		var a := rects[index - 1]
		var b := rects[index]
		if delta.x != 0:
			result.append(PackedVector2Array([Vector2(a.get_center().x + delta.x * (a.size.x / 2 - 2), a.get_center().y), Vector2(b.get_center().x - delta.x * (b.size.x / 2 - 2), a.get_center().y)]))
		else:
			result.append(PackedVector2Array([Vector2(a.get_center().x, a.get_center().y + delta.y * (a.size.y / 2 - 2)), Vector2(a.get_center().x, b.get_center().y - delta.y * (b.size.y / 2 - 2))]))
	return result

func _draw() -> void:
	var rects := selection_rects()
	for rect in rects:
		# Keep a gap between adjacent rails so only actual path edges connect.
		draw_rect(rect.grow(-2), Art.color("ink"), false, 12)
		draw_rect(rect.grow(-2), Art.color("paper"), false, 8)
	# Draw bridges over rails, only across facing margins, never ingredients.
	for segment in connection_segments():
		draw_line(segment[0], segment[1], Art.color("ink"), 18)
		draw_line(segment[0], segment[1], Art.color("paper"), 10)
	for index in range(rects.size()):
		# Left gutter is outside the unchanged ingredient image, including at 1620.
		var badge := Rect2(rects[index].position + Vector2(0, 12), Vector2(26, 36))
		draw_rect(badge, Art.color("ink"))
		draw_string(ThemeDB.fallback_font, badge.position + Vector2(0, 28), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 26 if index < 9 else 20, Art.color("paper"))
