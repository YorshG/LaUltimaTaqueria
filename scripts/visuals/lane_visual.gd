extends Control
## Read-only projection of progress, hunger, phases and the real target selector.
const Art = preload("res://scripts/visuals/art_01_style.gd")
const Atlas = preload("res://scripts/visuals/proxy_atlas.gd")
var _field: LaneField
var _panels: Array[StyleBoxFlat] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field = get_parent() as LaneField
	for fill in Art.catalog().lanes:
		_panels.append(Art.panel(Color(fill), Art.color("ink")))
	_field.ready.connect(_bind_hosts, CONNECT_ONE_SHOT)
	resized.connect(queue_redraw)

func _bind_hosts() -> void:
	for host in _field.lane_hosts: host.resized.connect(queue_redraw)

func _process(_delta: float) -> void:
	refresh_visuals()

func refresh_visuals() -> void:
	queue_redraw()

func target_sequence() -> int:
	var target := _field.select_nearest_target()
	return target.monster_state.spawn_sequence if target != null else -1

func proxy_center(runner: LaneRunner, rect: Rect2) -> Vector2:
	return Vector2(rect.get_center().x, rect.position.y + 36 + maxf(1, rect.size.y - 178) * runner.motion.progress + 43)

func cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _field == null or not _field.is_node_ready(): return result
	for lane in range(_field.lane_count()):
		var host := _field.get_lane_host(lane)
		var area := get_global_transform().affine_inverse() * host.get_global_rect()
		var runners: Array[LaneRunner] = []
		for child in host.get_children():
			if child is LaneRunner and child.monster_state != null and child.monster_state.active and child.is_visible_in_tree():
				runners.append(child)
		for slot in range(runners.size()):
			var runner := runners[slot]
			var boss := runner.monster_state.monster_id == "boss_big_glutton"
			var width := area.size.x / runners.size()
			var unit := minf(164 if boss else 86, minf(width - 20, area.size.y - 100))
			unit = maxf(24, unit)
			# Reserve the same height for all normal clients, so their vertical
			# progress stays comparable even when one lane has more clients.
			var height := unit + (54 if boss else 86)
			var x := area.position.x + width * slot + 6
			var y := area.position.y + 32 + maxf(1, area.size.y - height - 38) * runner.motion.progress
			var rect := Rect2(x, y, width - 12, height)
			result.append({"runner": runner, "rect": rect, "unit": unit, "boss": boss, "crowded": runners.size() > 1})
	return result

func _draw() -> void:
	if _field == null or not _field.is_node_ready(): return
	var target := _field.select_nearest_target()
	for lane in range(_field.lane_count()):
		var area := get_global_transform().affine_inverse() * _field.get_lane_host(lane).get_global_rect()
		draw_style_box(_panels[lane], area)
		# Proxy status remains documented in the catalog, never in gameplay copy.
		_text(Art.catalog().labels.lane % (lane + 1), area.position + Vector2(4, 24), area.size.x - 8, 22)
		draw_line(area.position + Vector2(area.size.x / 2, 32), area.end - Vector2(area.size.x / 2, 6), Color("635773"), 2)
	var selected: Dictionary = {}
	for card in cards():
		if card.runner == target: selected = card
		else: _draw_card(card, false)
	if not selected.is_empty(): _draw_card(selected, true)

func _draw_card(card: Dictionary, selected: bool) -> void:
	var runner: LaneRunner = card.runner
	var id := runner.monster_state.monster_id
	if not Art.catalog().monsters.has(id): return
	var spec: Dictionary = Art.catalog().monsters[id]
	var rect: Rect2 = card.rect
	var unit: float = card.unit
	var image_rect := Rect2(Vector2(rect.get_center().x - unit / 2, rect.position.y), Vector2.ONE * unit)
	var phase := str(runner.monster_state.get_current_phase().get("behavior_tag", "calm"))
	if selected:
		draw_rect(image_rect.grow(4), Art.color("target"), false, 4)
	Atlas.draw_token(self, image_rect, id, phase)
	if not card.boss:
		_text(spec.token, image_rect.position + Vector2(0, unit * 0.62), unit, 28, Art.color("ink"))
	var name: String = spec.token if card.crowded else spec.label
	if card.boss: name = Art.catalog().labels.get(phase, "Calma")
	var hunger := hunger_text(runner.monster_state.hunger_remaining, runner.monster_state.hunger_max)
	var bar_y := image_rect.end.y + 68
	if card.boss:
		_fitted_text("%s %s" % [name, hunger], Vector2(rect.position.x, image_rect.end.y + 28), rect.size.x, 26)
		bar_y = image_rect.end.y + 36
	elif card.crowded:
		# One numeric line, even when the model contains fractional satisfaction.
		_fitted_text(hunger, Vector2(rect.position.x, image_rect.end.y + 42), rect.size.x, 32)
	else:
		_text(name, Vector2(rect.position.x, image_rect.end.y + 26), rect.size.x, 26)
		_fitted_text(hunger, Vector2(rect.position.x, image_rect.end.y + 60), rect.size.x, 32)
	var bar := Rect2(rect.position.x + 4, bar_y, rect.size.x - 8, 12)
	draw_rect(bar, Art.color("ink"))
	var ratio := clampf(runner.monster_state.hunger_remaining / runner.monster_state.hunger_max, 0, 1)
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * ratio, 8)), Art.color("target"))
	for quarter in range(1, 4):
		var x := bar.position.x + bar.size.x * quarter / 4
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Art.color("ink"), 2)

func _text(value: String, origin: Vector2, width: float, font_size: int, tint: Color = Color("fff1d2")) -> void:
	draw_string(ThemeDB.fallback_font, origin, value, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, tint)

static func hunger_text(current: float, maximum: float) -> String:
	# Positive fractional hunger must never read as satisfied. Presentation only;
	# MonsterState, target eligibility and the bar ratio retain their exact floats.
	return "%.0f/%.0f" % [ceil(current) if current > 0 else 0, round(maximum)]

static func text_fit(value: String, width: float, preferred_size: int = 32) -> Dictionary:
	var font := ThemeDB.fallback_font
	var font_size := preferred_size
	var available := maxf(1, width - 4)
	var measured := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if measured > available:
		# Measure only the chosen size; avoid populating a font atlas at every
		# intermediate point size for each client on every redraw.
		font_size = maxi(24, floori(preferred_size * available / measured))
		measured = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return {"font_size": font_size, "scale_x": minf(1, available / maxf(1, measured)), "width": measured}

func _fitted_text(value: String, origin: Vector2, width: float, preferred_size: int) -> void:
	var fit := text_fit(value, width, preferred_size)
	# draw_string is one line. Horizontal fit also handles out-of-content stress
	# values without clipping, wrapping or shrinking the vertical glyph height.
	draw_set_transform(origin + Vector2((width - fit.width * fit.scale_x) / 2, 0), 0, Vector2(fit.scale_x, 1))
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fit.font_size, Art.color("paper"))
	draw_set_transform(Vector2.ZERO)
