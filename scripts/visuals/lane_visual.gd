extends Control
## Observes the real runners and target selector. Never owns gameplay state.

const Art = preload("res://scripts/visuals/art_01_style.gd")
var _field: LaneField
var _panels: Array[StyleBoxFlat] = []
var _counter := Art.panel(Color("9b6455"), Art.color("ink"), 4, 6)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field = get_parent() as LaneField
	for fill in Art.catalog().lanes:
		_panels.append(Art.panel(Color(fill), Art.color("ink")))
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	refresh_visuals()


func refresh_visuals() -> void:
	queue_redraw()


func target_sequence() -> int:
	var target := _field.select_nearest_target()
	return target.monster_state.spawn_sequence if target != null else -1


func _draw() -> void:
	if _field == null or not _field.is_node_ready(): return
	var target := _field.select_nearest_target()
	for index in range(_field.lane_count()):
		var host := _field.get_lane_host(index)
		var rect := get_global_transform().affine_inverse() * host.get_global_rect()
		draw_style_box(_panels[index], rect)
		_text(Art.catalog().labels.lane % (index + 1), rect.position + Vector2(4, 27), rect.size.x - 8, 20)
		draw_line(rect.position + Vector2(rect.size.x / 2, 40), rect.end - Vector2(rect.size.x / 2, 28), Color("635773"), 3)
		var counter := Rect2(Vector2(rect.position.x, rect.end.y - 26), Vector2(rect.size.x, 26))
		draw_style_box(_counter, counter)
		_text(Art.catalog().labels.counter, counter.position + Vector2(0, 20), counter.size.x, 18)
		for child in host.get_children():
			var runner := child as LaneRunner
			if runner == null or runner.monster_state == null or not runner.is_visible_in_tree() or not runner.monster_state.active: continue
			if runner != target: _draw_runner(runner, rect, false)
		# The real primary target is drawn last so other proxies cannot cover its cue.
		if target != null and target.get_parent() == host:
			_draw_runner(target, rect, true)
	if target == null:
		_text(Art.catalog().labels.empty, Vector2(0, size.y / 2), size.x, 24)


func proxy_center(runner: LaneRunner, rect: Rect2) -> Vector2:
	var is_boss := runner.monster_state.monster_id == "boss_big_glutton"
	var top := 146.0 if is_boss else 96.0
	var bottom := 178.0 if is_boss else 112.0
	# Read the approved logical source, not container-managed Control positions.
	return Vector2(rect.get_center().x, rect.position.y + top + maxf(0, rect.size.y - top - bottom) * runner.motion.progress)


func _draw_runner(runner: LaneRunner, rect: Rect2, selected: bool) -> void:
	var id := runner.monster_state.monster_id
	if not Art.catalog().monsters.has(id): return
	var spec: Dictionary = Art.catalog().monsters[id]
	var is_boss := id == "boss_big_glutton"
	var unit := minf(168 if is_boss else 84, rect.size.x - 36)
	var center := proxy_center(runner, rect)
	var proxy_rect := Rect2(center - Vector2.ONE * unit / 2, Vector2.ONE * unit)
	var phase := str(runner.monster_state.get_current_phase().get("behavior_tag", "calm"))
	if selected:
		draw_arc(center, unit * 0.61, 0, TAU, 36, Art.color("target"), 4, true)
		_text(Art.catalog().labels.target, center - Vector2(unit, unit * 0.65 + 5), unit * 2, 20)
	Art.draw_proxy(self, proxy_rect, id, phase)
	_text(spec.token, center + Vector2(-unit / 2, 10), unit, 28, Art.color("ink"))
	_text(spec.label, center + Vector2(-rect.size.x / 2, unit * 0.61 + 26), rect.size.x, 23)
	if is_boss:
		_text(Art.catalog().labels.get(phase, ""), center + Vector2(-unit, unit * 0.61 + 50), unit * 2, 20)


func _text(value: String, origin: Vector2, width: float, font_size: int, tint: Color = Color("fff1d2")) -> void:
	draw_string(ThemeDB.fallback_font, origin, value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, tint)
