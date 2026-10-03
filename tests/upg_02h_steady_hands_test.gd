extends SceneTree

const BOARD = preload("res://scenes/board/BoardView.tscn")
const MAIN = preload("res://scenes/Main.tscn")
const SEED := 20260920

# Exercise the rejection path after successful derivation, without changing content.
class InvalidForgivenessSelector extends UpgradeSelector:
	func get_active_effects() -> Array[Dictionary]:
		return [{"upgrade_id": "fixture", "effect": {
			"type": "modify_input", "stat": "input_forgiveness",
			"operation": "add", "value": 1.5,
		}}]

var checks := 0
var failures := 0


func _init() -> void:
	_test_setter()
	_test_geometry()
	await _test_non_control_child()
	for viewport_size in [Vector2i(1080, 1620), Vector2i(1080, 1920), Vector2i(1080, 2400), Vector2i(720, 1280)]:
		var viewport := _viewport(viewport_size)
		var main = MAIN.instantiate()
		main.auto_start_run = false
		viewport.add_child(main)
		await _layout()
		_expect(main.upgrade_selector.get_selection_count() == 0, "viewport: no upgrades selected")
		await _exercise(viewport, main.board_view)
		if viewport_size.y == 1920:
			viewport.size = Vector2i(720, 1280)
			await _layout()
			await _exercise(viewport, main.board_view)
		viewport.queue_free()
		await process_frame
	await _test_transformed_viewport()
	await _test_public_selection()
	await _test_invalid_wiring()
	if failures == 0:
		print("UPG-02h tests passed: %d checks; D8 geometry, real mouse/touch, absolute runtime setter, public selection and deterministic refill." % checks)
	else:
		push_error("UPG-02h tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_setter() -> void:
	var board := BoardView.new()
	_expect(board.get_input_forgiveness() == 0.0, "setter: new run is neutral")
	for value in [0, 1, 0.0, 1.0, 0.1, 0.1]:
		_expect(board.set_input_forgiveness(value), "setter: finite numeric endpoint/value accepted")
		_expect(board.get_input_forgiveness() == float(value), "setter: absolute assignment, not accumulation")
	for value in [NAN, INF, -INF, -0.1, 1.5, "0.1", null, true, false, [], {}]:
		_expect(not board.set_input_forgiveness(value), "setter: invalid value rejected")
		_expect(board.get_input_forgiveness() == 0.1, "setter: rejection preserves valid previous value")
	board.free()


func _hit(point: Vector2, rects: Array[Rect2], f: float = 0.1) -> int:
	return BoardView.cell_index_at_canvas_position(point, rects, f)


func _test_geometry() -> void:
	var rects: Array[Rect2] = []
	for index in range(25):
		rects.append(Rect2(Vector2(index % 5, index / 5) * 108.0, Vector2(100, 100)))
	_expect(_hit(Vector2.ZERO, []) == -1, "geometry: empty grid has no candidate")
	for index in range(25):
		var rect := rects[index]
		for f in [0.0, 0.1, 1.0]:
			_expect(_hit(rect.get_center(), rects, f) == index, "geometry: exact centers always own their cells")
		_expect(_hit(rect.position, rects, 0.0) == index, "neutral: original left/top inclusive")
		_expect(_hit(rect.end, rects, 0.0) == -1, "neutral: original right/bottom exclusive in gap")
	_expect(_hit(Vector2(104, 50), rects, 0.0) == -1, "neutral: horizontal gap stays empty")
	_expect(_hit(Vector2(50, 104), rects, 0.0) == -1, "neutral: vertical gap stays empty")
	_expect(_hit(Vector2(104, 104), rects, 0.0) == -1, "neutral: corner gap stays empty")
	_expect(_hit(Vector2(-9.9, 50), rects) == 0, "margin: full 10 percent on each side, m-0.1 accepted")
	_expect(_hit(Vector2(-10, 50), rects) == 0, "margin: expanded left boundary inclusive")
	_expect(_hit(Vector2(-10.1, 50), rects) == -1, "margin: m+0.1 outside grid rejected")
	var single: Array[Rect2] = [rects[0]]
	_expect(_hit(Vector2(110, 50), single) == -1, "margin: expanded right boundary exclusive")
	_expect(_hit(Vector2(109.9, 50), single) == 0, "margin: expanded right m-0.1 accepted")
	for case in [
		[Vector2(103, 50), 0], [Vector2(105, 50), 1],
		[Vector2(50, 103), 0], [Vector2(50, 105), 5],
		[Vector2(103, 103), 0], [Vector2(105, 103), 1],
		[Vector2(103, 105), 5], [Vector2(105, 105), 6],
	]:
		_expect(_hit(case[0], rects) == case[1], "nearest: overlapping expansions choose nearest center")
	_expect(_hit(Vector2(104, 50), rects) == 0, "tie: horizontal goes left")
	_expect(_hit(Vector2(50, 104), rects) == 0, "tie: vertical goes up")
	_expect(_hit(Vector2(104, 104), rects) == 0, "tie: four equidistant cells choose lowest row-major")
	# Vector2's float precision yields a squared-distance delta about 1.6e-3.
	var near := Vector2(104.00001, 50)
	var left_distance := near.distance_squared_to(rects[0].get_center())
	var right_distance := near.distance_squared_to(rects[1].get_center())
	_expect(right_distance < left_distance and left_distance - right_distance < 0.003, "near tie: fixture has a strictly smaller distance around 1e-3")
	_expect(_hit(near, rects) == 1, "near tie: strict distance wins, no approximate equality")
	var unequal: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(108, 9.5, 81, 81)]
	var exact := Vector2(99.95, 50)
	_expect(unequal[0].has_point(exact) and unequal[1].grow(8.1).has_point(exact), "exact priority: unequal rect fixture overlaps only after expansion")
	_expect(exact.distance_squared_to(unequal[1].get_center()) < exact.distance_squared_to(unequal[0].get_center()), "exact priority: expanded neighbor center is nearer")
	_expect(_hit(exact, unequal) == 0, "exact priority: original containing rect wins over nearer expanded neighbor")
	var tall: Array[Rect2] = [Rect2(0, 0, 100, 200)]
	_expect(_hit(Vector2(-9.9, 100), tall) == 0, "unequal: uses smaller side margin")
	_expect(_hit(Vector2(-15, 100), tall) == -1, "unequal: larger side must not grow margin")
	var varying: Array[Rect2] = [Rect2(0, 0, 99, 100), Rect2(200, 0, 81, 100)]
	_expect(_hit(Vector2(-9.85, 50), varying) == 0, "unequal: 99x100 cell has margin 9.9")
	_expect(_hit(Vector2(-9.95, 50), varying) == -1, "unequal: 99x100 does not use side 100")
	_expect(_hit(Vector2(191.95, 50), varying) == 1, "unequal: second cell computes its own 8.1 margin")
	_expect(_hit(Vector2(191.85, 50), varying) == -1, "unequal: second cell does not reuse first cell margin")
	# Both expansions contain this gap point, but the distance metrics disagree.
	var metric_rects: Array[Rect2] = [Rect2(0, 0, 100, 100), Rect2(104, 60, 40, 40)]
	var metric_point := Vector2(100, 33)
	_expect(not metric_rects[0].has_point(metric_point) and not metric_rects[1].has_point(metric_point), "metric: fixture has no exact hit")
	_expect(metric_rects[0].grow(100.0).has_point(metric_point) and metric_rects[1].grow(40.0).has_point(metric_point), "metric: both candidates contain point at forgiveness 1.0")
	_expect(metric_point.distance_squared_to(metric_rects[0].get_center()) == 2789.0 and metric_point.distance_squared_to(metric_rects[1].get_center()) == 2785.0, "metric: squared Euclidean distances are A=2789, B=2785")
	var offset_a := (metric_point - metric_rects[0].get_center()).abs()
	var offset_b := (metric_point - metric_rects[1].get_center()).abs()
	_expect(offset_a.x + offset_a.y == 67.0 and offset_b.x + offset_b.y == 71.0, "metric: Manhattan instead favors A=67 over B=71")
	_expect(_hit(metric_point, metric_rects, 1.0) == 1, "metric: squared Euclidean chooses B (index 1), not Manhattan A (index 0)")


func _test_non_control_child() -> void:
	var viewport := _viewport(Vector2i(720, 1280))
	var board := BOARD.instantiate() as BoardView
	viewport.add_child(board)
	await _layout()
	var cells: Array[Control] = []
	for child in board.grid.get_children():
		cells.append(child)
	var non_control := Node.new()
	non_control.set_meta("coord", Vector2i(99, 99))
	board.grid.add_child(non_control)
	board.grid.move_child(non_control, 1)
	await _layout()
	_expect(not non_control is Control and board.grid.get_child(1) == non_control, "alignment: non-Control inserted between real cells")
	_expect(board.grid.get_child(2) == cells[1], "alignment: grid child index differs from geometric cell index")
	for f in [0.0, 0.1]:
		_expect(board.set_input_forgiveness(f), "alignment: neutral/active forgiveness accepted")
		for cell in cells:
			var local_point := board.get_global_transform().affine_inverse() * cell.get_global_rect().get_center()
			_expect(board._coord_at_position(local_point) == cell.get_meta("coord"), "alignment: exact geometry returns correct coord despite non-Control child")
		var outside := board.get_global_transform().affine_inverse() * Vector2(-1000, -1000)
		_expect(board._coord_at_position(outside) == Vector2i(-1, -1), "alignment: no candidate remains invalid with non-Control child")
	var second_rect := cells[1].get_global_rect()
	var gap := Vector2(second_rect.end.x + 1.0, second_rect.get_center().y)
	_expect(board._coord_at_position(board.get_global_transform().affine_inverse() * gap) == Vector2i(1, 0), "alignment: expanded geometric index maps to second cell coord, not grid child")
	viewport.queue_free()
	await process_frame


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	root.add_child(viewport)
	return viewport


func _layout() -> void:
	await process_frame
	await process_frame


func _observe(board: BoardView) -> Dictionary:
	var events := {"started": [], "changed": [], "completed": [], "cancelled": []}
	board.chain_started.connect(func(p: Array[Vector2i]): events["started"].append(p.duplicate()))
	board.chain_changed.connect(func(p: Array[Vector2i]): events["changed"].append(p.duplicate()))
	board.chain_completed.connect(func(p: Array[Vector2i], ingredient: String): events["completed"].append({"points": p.duplicate(), "ingredient": ingredient}))
	board.chain_cancelled.connect(func(): events["cancelled"].append(true))
	return events


func _rect(board: BoardView, index: int = 0) -> Rect2:
	return (board.grid.get_child(index) as Control).get_global_rect()


func _tap(viewport: SubViewport, events: Dictionary, point: Vector2, touch: bool, index: int, label: String) -> void:
	events["started"].clear()
	_press(viewport, point, touch, true)
	var expected: Array = [] if index < 0 else [[Vector2i(index % 5, index / 5)]]
	_expect(events["started"] == expected, label + (" touch" if touch else " mouse"))
	_press(viewport, point, touch, false)


func _exercise(viewport: SubViewport, board: BoardView) -> void:
	var events := _observe(board)
	for touch in [false, true]:
		_expect(board.set_input_forgiveness(0.0), "viewport: neutral setter")
		for index in range(25):
			_tap(viewport, events, _rect(board, index).get_center(), touch, index, "neutral: all 25 real centers")
		var rect := _rect(board)
		var center := rect.get_center()
		for point in [Vector2(rect.position.x + 0.1, center.y), Vector2(rect.end.x - 0.1, center.y),
			Vector2(center.x, rect.position.y + 0.1), Vector2(center.x, rect.end.y - 0.1),
			rect.position + Vector2(0.1, 0.1), rect.end - Vector2(0.1, 0.1),
			Vector2(rect.end.x - 0.1, rect.position.y + 0.1), Vector2(rect.position.x + 0.1, rect.end.y - 0.1)]:
			_tap(viewport, events, point, touch, 0, "neutral: original borders and corners")
		for point in [Vector2(rect.end.x + 1, center.y), Vector2(center.x, rect.end.y + 1), rect.end + Vector2.ONE]:
			_tap(viewport, events, point, touch, -1, "neutral: gap and corner remain empty")
		_expect(board.set_input_forgiveness(0.1), "viewport: activate forgiveness")
		_expect(board.get_input_forgiveness() == 0.1, "viewport: runtime owner holds 0.10")
		for index in range(25):
			_tap(viewport, events, _rect(board, index).get_center(), touch, index, "active: exact cell owns center even with overlapping neighbors")
		_tap(viewport, events, Vector2(rect.end.x + 1, center.y), touch, 0, "active: near gap now selects first cell")
		var margin := 0.1 * minf(rect.size.x, rect.size.y)
		var inside := Vector2(rect.position.x - margin + 0.1, center.y)
		var outside := Vector2(rect.position.x - margin - 0.1, center.y)
		_expect(board._coord_at_position(board.get_global_transform().affine_inverse() * inside) == Vector2i.ZERO, "active: actual transformed rect m-0.1 reaches cell")
		_expect(board._coord_at_position(board.get_global_transform().affine_inverse() * outside) == Vector2i(-1, -1), "active: actual transformed rect m+0.1 rejected")
		# D8 accepts the exterior band outside the Control's initial press routing.
		var delivered := board.get_global_rect().has_point(inside)
		_tap(viewport, events, inside, touch, 0 if delivered else -1, "active: exterior press respects unchanged Control routing")
		_tap(viewport, events, outside, touch, -1, "active: outside expansion has no candidate")
		if not delivered:
			print("D8 accepted exterior band at %s: %.3f canvas px; geometry accepts, initial press is outside BoardView." % [viewport.size, board.get_global_rect().position.x - (rect.position.x - margin)])
		var right := _rect(board, 1)
		var below := _rect(board, 5)
		var gap_x := (rect.end.x + right.position.x) / 2.0
		var gap_y := (rect.end.y + below.position.y) / 2.0
		for case in [[Vector2(gap_x - 0.5, center.y), 0], [Vector2(gap_x + 0.5, center.y), 1],
			[Vector2(center.x, gap_y - 0.5), 0], [Vector2(center.x, gap_y + 0.5), 5],
			[Vector2(gap_x - 0.5, gap_y - 0.5), 0], [Vector2(gap_x + 0.5, gap_y + 0.5), 6]]:
			_tap(viewport, events, case[0], touch, case[1], "active: overlapping real rects choose nearer center")
		board.reset_with_seed(SEED)
		_expect(board.get_input_forgiveness() == 0.1, "run state: reset_with_seed preserves forgiveness")
		_test_chain(viewport, board, events, touch)
	await process_frame


func _test_chain(viewport: SubViewport, board: BoardView, events: Dictionary, touch: bool) -> void:
	for key in events:
		events[key].clear()
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var first := _rect(board)
	_press(viewport, Vector2(first.end.x + 1, first.get_center().y), touch, true)
	_drag(viewport, _rect(board, 6).get_center(), touch) # diagonal
	_drag(viewport, _rect(board, 5).get_center(), touch) # different ingredient
	_drag(viewport, _rect(board, 1).get_center(), touch)
	_drag(viewport, first.get_center(), touch) # repeated point
	var last := _rect(board, 2)
	var last_point := Vector2(last.position.x - 1, last.get_center().y)
	_drag(viewport, last_point, touch)
	_press(viewport, last_point, touch, false)
	_press(viewport, last_point, touch, false)
	_expect(events["changed"] == [points.slice(0, 2), points], "chain: orthogonal only, same ingredient, no diagonal or repetition")
	_expect(events["completed"] == [{"points": points, "ingredient": "tortilla"}], "chain: minimum three, valid chain completes exactly once")
	_expect(events["cancelled"].is_empty(), "chain: valid chain not cancelled")
	var reference := BoardState.new()
	reference.reset(SEED, BoardView.PLACEHOLDER_LAYOUT)
	reference.resolve_chain(points)
	_expect(board.get_ingredient_snapshot() == reference.snapshot(), "refill: real forgiven input equals BoardState with same seed and points")
	board.reset_with_seed(SEED)
	events["completed"].clear()
	events["cancelled"].clear()
	_press(viewport, _rect(board).get_center(), touch, true)
	_drag(viewport, _rect(board, 1).get_center(), touch)
	_press(viewport, _rect(board, 1).get_center(), touch, false)
	_expect(events["completed"].is_empty() and events["cancelled"].size() == 1, "chain: two-point chain cancelled once")
	_expect(board.get_ingredient_snapshot() == BoardView.PLACEHOLDER_LAYOUT, "chain: short chain does not refill")


func _test_transformed_viewport() -> void:
	var viewport := _viewport(Vector2i(1080, 1920))
	var host := Control.new()
	host.position = Vector2(140, 200)
	host.size = Vector2(450, 500)
	host.scale = Vector2(1.25, 0.8)
	viewport.add_child(host)
	var board := BOARD.instantiate() as BoardView
	host.add_child(board)
	await _layout()
	await _exercise(viewport, board)
	var cell := board.grid.get_child(0) as Control
	var rect := cell.get_global_rect()
	var canvas_margin := 0.1 * minf(rect.size.x, rect.size.y)
	var local_margin := 0.1 * minf(cell.size.x, cell.size.y)
	_expect(canvas_margin != local_margin, "scale: fixture distinguishes local and canvas margins")
	var offset := (canvas_margin + local_margin) / 2.0
	var point := Vector2(rect.position.x - offset, rect.get_center().y)
	var expected := 0 if canvas_margin > local_margin else -1
	_expect(board._coord_at_position(board.get_global_transform().affine_inverse() * point) == (Vector2i.ZERO if expected == 0 else Vector2i(-1, -1)), "scale: hit uses transformed min side, not local size")
	var events := _observe(board)
	for touch in [false, true]:
		_tap(viewport, events, point, touch, expected, "scale: real dispatch distinguishes canvas margin from local margin")
	print("D8 scale fixture: canvas margin %.3f, local margin %.3f." % [canvas_margin, local_margin])
	viewport.queue_free()
	await process_frame


func _test_public_selection() -> void:
	var viewport := _viewport(Vector2i(1080, 1920))
	var main = MAIN.instantiate()
	main.auto_start_run = false
	viewport.add_child(main)
	await _layout()
	var board: BoardView = main.board_view
	var events := _observe(board)
	var first := _rect(board)
	var gap := Vector2(first.end.x + 1, first.get_center().y)
	_expect(board.get_input_forgiveness() == 0.0, "wiring: before real selection is zero")
	for touch in [false, true]:
		_tap(viewport, events, gap, touch, -1, "wiring: gap fails before selection")
	main.wave_director.wave_completed.emit({"wave_id": "wave_01"})
	var result: Dictionary = main.upgrade_selector.select_upgrade("steady_hands")
	_expect(result["ok"], "wiring: real public offer selects steady_hands")
	_expect(main.upgrade_selector.get_selected_upgrade_ids() == ["steady_hands"], "wiring: real selector owns one upgrade")
	_expect(board.get_input_forgiveness() == 0.1, "wiring: selection signal refreshes BoardView immediately")
	for touch in [false, true]:
		_tap(viewport, events, gap, touch, 0, "wiring: gap succeeds immediately after selection")
	if result["ok"]:
		main.upgrade_selector.upgrade_selected.emit(result["selection"])
	_expect(board.get_input_forgiveness() == 0.1, "wiring: reemitted signal does not stack")
	_expect(board.set_input_forgiveness(0.1) and board.get_input_forgiveness() == 0.1, "wiring: repeated setter remains 0.10")
	var m := minf(first.size.x, first.size.y)
	var no_stack := Vector2(first.position.x - 0.15 * m, first.get_center().y)
	_expect(board._coord_at_position(board.get_global_transform().affine_inverse() * no_stack) == Vector2i(-1, -1), "wiring: 15 percent exterior distinguishes 0.10 from accidental 0.20")
	for touch in [false, true]:
		_tap(viewport, events, no_stack, touch, -1, "wiring: real input rejects accidental stacking band")
	board.set_input_forgiveness(0.0)
	var invalid: Dictionary = main._on_upgrade_selected({})
	_expect(invalid.get("error") == "INVALID_SELECTION" and board.get_input_forgiveness() == 0.1, "wiring: refresh precedes invalid-selection guard")
	if result["ok"]:
		board.set_input_forgiveness(0.0)
		main.boss_has_started = true
		main._on_upgrade_selected(result["selection"])
		_expect(board.get_input_forgiveness() == 0.1, "wiring: refresh precedes boss-started guard")
		board.set_input_forgiveness(0.0)
		main.reputation.apply_damage(1000.0)
		var terminal: Dictionary = main._on_upgrade_selected(result["selection"])
		_expect(terminal.get("error") == "RUN_ENDED" and board.get_input_forgiveness() == 0.1, "wiring: refresh precedes terminal guard")
	viewport.queue_free()
	await process_frame


func _test_invalid_wiring() -> void:
	var main = MAIN.instantiate()
	main.auto_start_run = false
	main.get_node("%UpgradeSelector").set_script(InvalidForgivenessSelector)
	root.add_child(main)
	await _layout()
	main.board_view.set_input_forgiveness(0.1)
	var result: Dictionary = main._on_upgrade_selected({})
	_expect(result.get("error") == "INVALID_INPUT_FORGIVENESS", "wiring: rejected derived value returns explicit error before payload guards")
	_expect(main.board_view.get_input_forgiveness() == 0.1, "wiring: rejection preserves BoardView owner state")
	main.queue_free()
	await process_frame


func _press(viewport: SubViewport, point: Vector2, touch: bool, pressed: bool) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		viewport.push_input(event, true)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)


func _drag(viewport: SubViewport, point: Vector2, touch: bool) -> void:
	if touch:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point
		viewport.push_input(event, true)
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
