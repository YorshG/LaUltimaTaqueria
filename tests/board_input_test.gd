extends SceneTree

const BOARD = preload("res://scenes/board/BoardView.tscn")
const MAIN = preload("res://scenes/Main.tscn")

var checks := 0
var failures := 0


func _init() -> void:
	for viewport_size in [Vector2i(1080, 1620), Vector2i(1080, 1920), Vector2i(1080, 2400)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var main = MAIN.instantiate()
		main.auto_start_run = false
		viewport.add_child(main)
		await process_frame
		await process_frame
		_expect(main.upgrade_selector.get_selection_count() == 0, "Main input fixture has no selected upgrades")
		await _exercise(viewport, main.board_view)
		if viewport_size.y == 1920:
			viewport.size = Vector2i(1080, 1620)
			await process_frame
			await process_frame
			await _exercise(viewport, main.board_view)
		viewport.queue_free()
		await process_frame

	# Translation and nonuniform scale exercise the same local-input contract
	# without relying on Main's particular container offsets.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	root.add_child(viewport)
	var host := Control.new()
	host.position = Vector2(140, 200)
	host.size = Vector2(450, 500)
	host.scale = Vector2(1.25, 0.8)
	viewport.add_child(host)
	var board := BOARD.instantiate() as BoardView
	host.add_child(board)
	await process_frame
	await process_frame
	await _exercise(viewport, board)
	viewport.queue_free()
	await process_frame

	if failures == 0:
		print("Board input tests passed: %d checks; real viewport mouse/touch, translated/scaled layouts, borders and orthogonal chains." % checks)
	else:
		push_error("Board input tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _exercise(viewport: SubViewport, board: BoardView) -> void:
	var started: Array = []
	var completed: Array = []
	var on_started := func(points: Array[Vector2i]): started.append(points.duplicate())
	board.chain_started.connect(on_started)
	var on_completed := func(points: Array[Vector2i], ingredient: String):
		completed.append({"points": points.duplicate(), "ingredient": ingredient})
	board.chain_completed.connect(on_completed)
	_expect(board.global_position != Vector2.ZERO, "fixture has a nonzero board origin")
	for touch in [false, true]:
		for index in range(25):
			var expected := Vector2i(index % 5, index / 5)
			var point := _center(board, expected)
			started.clear()
			_press(viewport, point, touch, true)
			_expect(started == [[expected]], "%s at cell %s selects exactly that cell" % ["touch" if touch else "mouse", expected])
			_press(viewport, point, touch, false)

		# All borders/corners are tested just inside the original first-cell rect.
		# Neighboring gaps stay outside; no forgiveness or overlap rule is added.
		var rect := (board.grid.get_child(0) as Control).get_global_rect()
		var center := rect.get_center()
		var epsilon := 0.1
		var inside := [Vector2(rect.position.x + epsilon, center.y), Vector2(rect.end.x - epsilon, center.y),
			Vector2(center.x, rect.position.y + epsilon), Vector2(center.x, rect.end.y - epsilon),
			rect.position + Vector2(epsilon, epsilon), rect.end - Vector2(epsilon, epsilon),
			Vector2(rect.end.x - epsilon, rect.position.y + epsilon), Vector2(rect.position.x + epsilon, rect.end.y - epsilon)]
		for point in inside:
			started.clear()
			_press(viewport, point, touch, true)
			_expect(started == [[Vector2i.ZERO]], "inside original border/corner selects cell zero")
			_press(viewport, point, touch, false)
		var outside := [Vector2(rect.position.x - epsilon, center.y), Vector2(rect.end.x + epsilon, center.y),
			Vector2(center.x, rect.position.y - epsilon), Vector2(center.x, rect.end.y + epsilon)]
		for point in outside:
			started.clear()
			_press(viewport, point, touch, true)
			_expect(started.is_empty(), "outside original border in gap selects no cell")
			_press(viewport, point, touch, false)

		board.reset_with_seed(20260920)
		completed.clear()
		var points: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
		_press(viewport, _center(board, points[0]), touch, true)
		_drag(viewport, _center(board, Vector2i(1,1)), touch) # diagonal rejected
		_drag(viewport, _center(board, points[1]), touch)
		_drag(viewport, _center(board, points[0]), touch) # repetition rejected
		_drag(viewport, _center(board, points[2]), touch)
		_press(viewport, _center(board, points[2]), touch, false)
		_expect(completed == [{"points": points, "ingredient": "tortilla"}], "real drag completes only the orthogonal unrepeated chain")
		var reference := BoardState.new()
		reference.reset(20260920, BoardView.PLACEHOLDER_LAYOUT)
		reference.resolve_chain(points)
		_expect(board.get_ingredient_snapshot() == reference.snapshot(), "real input preserves deterministic gravity/refill")
	board.chain_started.disconnect(on_started)
	board.chain_completed.disconnect(on_completed)


func _center(board: BoardView, coord: Vector2i) -> Vector2:
	return (board.grid.get_child(coord.y * 5 + coord.x) as Control).get_global_rect().get_center()


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


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
