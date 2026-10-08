extends Control
const Art = preload("res://scripts/visuals/art_01_style.gd")
var _panel := Art.panel(Color("a46e53"), Art.color("ink"), 4, 8)
var _text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(_delta: float) -> void:
	refresh_visuals()

func refresh_visuals() -> void:
	var field := get_parent().get_node("LaneField") as LaneField
	var target := field.select_nearest_target()
	var value := "Sin objetivo"
	if target != null:
		var spec: Dictionary = Art.catalog().monsters.get(target.monster_state.monster_id, {})
		value = "Objetivo → %s · %d" % [spec.get("label", ""), target.monster_state.lane + 1]
	if value != _text:
		_text = value
		queue_redraw()

func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	draw_string(ThemeDB.fallback_font, Vector2(16, 32), "Mostrador", HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.35, 30, Art.color("paper"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.35, 32), _text, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.65 - 16, 30, Art.color("paper"))
