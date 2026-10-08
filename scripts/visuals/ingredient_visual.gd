extends Control

const Art = preload("res://scripts/visuals/art_01_style.gd")
var _background := Art.panel(Art.color("cell"), Art.color("ink"))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Text changes/refills already redraw the underlying Button, including resets.
	get_parent().draw.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var id := str(get_parent().get_meta("ingredient_id", ""))
	if not Art.catalog().ingredients.has(id): return
	draw_style_box(_background, Rect2(Vector2.ZERO, size))
	var unit := minf(size.x * 0.66, size.y * 0.60)
	Art.draw_ingredient(self, Rect2(Vector2((size.x - unit) / 2, size.y * 0.07), Vector2.ONE * unit), id)
	var font_size := clampi(int(size.y * 0.19), 14, 28)
	draw_string(ThemeDB.fallback_font, Vector2(4, size.y * 0.89), Art.catalog().ingredients[id].label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, font_size, Art.color("ink"))
