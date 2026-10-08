extends RefCounted
## Presentation-only geometry. These tokens are not production character designs.

static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/art_01.json"))
	return _catalog


static func color(key: String) -> Color:
	return Color(catalog()[key])


static func panel(fill: Color, border: Color, width: int = 4, radius: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	# Keep existing Control/container geometry unchanged.
	box.content_margin_left = 0
	box.content_margin_top = 0
	box.content_margin_right = 0
	box.content_margin_bottom = 0
	return box


static func polygon(canvas: CanvasItem, points: PackedVector2Array, fill: Color, width: float) -> void:
	canvas.draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, color("ink"), width, true)


static func mapped(points: Array, rect: Rect2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(rect.position + Vector2(point[0], point[1]) * rect.size)
	return result


static func draw_ingredient(canvas: CanvasItem, rect: Rect2, id: String) -> void:
	var spec: Dictionary = catalog().ingredients.get(id, {})
	if spec.is_empty(): return
	var base := Color(spec.base)
	var shadow := Color(spec.shadow)
	var center := rect.get_center()
	var unit := minf(rect.size.x, rect.size.y)
	var width := maxf(3, unit * 0.065)
	match id:
		"tortilla":
			canvas.draw_circle(center, unit * 0.43, color("ink"))
			canvas.draw_circle(center, unit * 0.43 - width, shadow)
			canvas.draw_circle(center - Vector2(0, unit * 0.07), unit * 0.32, base)
			for offset in [Vector2(-0.13, -0.13), Vector2(0.14, 0.02), Vector2(-0.10, 0.16)]:
				canvas.draw_circle(center + offset * unit, unit * 0.035, shadow)
		"meat":
			polygon(canvas, mapped([[0.12,0.28],[0.37,0.10],[0.83,0.20],[0.94,0.48],[0.72,0.82],[0.34,0.91],[0.08,0.66]], rect), shadow, width)
			canvas.draw_colored_polygon(mapped([[0.17,0.30],[0.39,0.18],[0.78,0.27],[0.82,0.46],[0.53,0.60],[0.22,0.57]], rect), base)
			canvas.draw_line(rect.position + rect.size * Vector2(0.37,0.29), rect.position + rect.size * Vector2(0.29,0.47), color("paper"), width, true)
			canvas.draw_line(rect.position + rect.size * Vector2(0.59,0.30), rect.position + rect.size * Vector2(0.51,0.48), color("paper"), width, true)
		"veggie":
			polygon(canvas, mapped([[0.12,0.75],[0.08,0.35],[0.29,0.12],[0.54,0.25],[0.73,0.07],[0.92,0.26],[0.86,0.67],[0.54,0.92]], rect), base, width)
			canvas.draw_colored_polygon(mapped([[0.14,0.72],[0.54,0.62],[0.87,0.29],[0.81,0.64],[0.53,0.84]], rect), shadow)
			canvas.draw_line(rect.position + rect.size * Vector2(0.34,0.75), rect.position + rect.size * Vector2(0.70,0.31), color("ink"), width, true)


static func draw_proxy(canvas: CanvasItem, rect: Rect2, id: String, phase: String = "calm", silhouette: bool = false) -> void:
	var spec: Dictionary = catalog().monsters.get(id, {})
	if spec.is_empty(): return
	var points: Array = spec.points
	if id == "boss_big_glutton":
		points = catalog().boss_pose_points.get(phase, points)
	var contour := mapped(points, rect)
	var width := maxf(2, minf(rect.size.x, rect.size.y) * 0.055)
	if silhouette:
		canvas.draw_colored_polygon(contour, Color.BLACK)
		var outline := contour.duplicate()
		outline.append(contour[0])
		canvas.draw_polyline(outline, Color.BLACK, width, true)
		return
	polygon(canvas, contour, Color(spec.base), width)
	# Geometric stand-ins, not approved production character designs.
	var lower := PackedVector2Array([contour[0], contour[contour.size()-1], contour[contour.size()-2]])
	canvas.draw_colored_polygon(lower, Color(spec.shadow))
	if id == "boss_big_glutton":
		# Rounded teeth and raised brows keep the hungry pose anxious, not angry.
		polygon(canvas, mapped([[0.39,0.46],[0.65,0.46],[0.62,0.72],[0.43,0.72]], rect), color("paper"), width * 0.6)
		var unit := rect.size.x
		for x in [0.42, 0.62]:
			var eye := rect.position + rect.size * Vector2(x, 0.28)
			canvas.draw_circle(eye, unit * 0.048, color("paper"))
			canvas.draw_circle(eye + Vector2(0, -unit * 0.009 if phase == "phase2_transition_cue_cosmetic_only" else 0), unit * 0.023, color("ink"))
			if phase == "phase2_transition_cue_cosmetic_only":
				canvas.draw_arc(eye - Vector2(0, unit * 0.05), unit * 0.055, PI * 1.15, PI * 1.85, 10, color("ink"), width * 0.55, true)
		var mouth := rect.position + rect.size * Vector2(0.52, 0.39)
		var radius := unit * (0.065 if phase == "calm" else 0.09)
		canvas.draw_circle(mouth, radius, color("ink"))
		for offset in [-0.026, 0.026]:
			canvas.draw_circle(mouth + Vector2(unit * offset, -radius * 0.55), unit * 0.022, color("paper"))
