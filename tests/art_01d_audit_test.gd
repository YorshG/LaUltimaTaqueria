extends SceneTree
const Fixture = preload("res://tests/art_01d_fixture.gd")
const LaneVisual = preload("res://scripts/visuals/lane_visual.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for sample in [[0.0, "0/30"], [0.000000000001, "1/30"], [0.2, "1/30"], [0.49, "1/30"], [17.5, "18/30"], [27.5, "28/30"], [29.000001, "30/30"], [29.999999999, "30/30"], [30.0, "30/30"]]:
		_expect(LaneVisual.hunger_text(sample[0], 30) == sample[1], "ceiling positive display / exact zero and maximum")
	_expect(LaneVisual.hunger_text(67.625, 70) == "68/70", "Salsa Tank fraction")
	_expect(LaneVisual.hunger_text(17.9999999, 18) == "18/18", "Swift Hopper near maximum")
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, height)
		root.add_child(viewport)
		var app = load("res://scenes/App.tscn").instantiate()
		viewport.add_child(app)
		var main = app.get_session()
		Fixture.populate(main)
		main.process_mode = Node.PROCESS_MODE_INHERIT
		main.wave_director.set_process(false)
		app.get_node("Layout").set_test_metrics(Rect2(0, 177, 1080, height - 279), Transform2D.IDENTITY, 3.0)
		for frame in range(8): await process_frame
		var board: BoardView = main.board_view
		var visual = board.get_node("BoardVisual")
		var completions: Array = []
		board.chain_completed.connect(func(points, _id): completions.append(points.duplicate()))
		for ingredient in ["tortilla", "meat", "veggie"]:
			for path in [Fixture.TURNS, Fixture.EDGE]:
				for length in [2, 3, 4, 5]:
					Fixture.arrange(board, path, ingredient)
					var geometry: Array[Rect2] = []
					for cell in board.grid.get_children(): geometry.append(cell.get_global_rect())
					var touch := InputEventScreenTouch.new()
					touch.position = geometry[path[0].y * 5 + path[0].x].get_center()
					touch.pressed = true
					viewport.push_input(touch, true)
					for point in path.slice(1, length):
						var drag := InputEventScreenDrag.new()
						drag.position = geometry[point.y * 5 + point.x].get_center()
						viewport.push_input(drag, true)
					_expect(visual._points == path.slice(0, length), "touch dispatch keeps ordered chain at both board edges")
					var segments: Array = visual.connection_segments()
					_expect(segments.size() == length - 1, "exactly N-1 visible connectors")
					for segment in segments:
						_expect((segment[0].x == segment[1].x) != (segment[0].y == segment[1].y), "every connector strictly horizontal or vertical")
					for index in range(25):
						var cell: Control = board.grid.get_child(index)
						_expect(cell.get_global_rect() == geometry[index], "selection preserves all hitboxes")
						_expect(cell.modulate == Color.WHITE, "selection preserves original ingredient colors")
					var count := completions.size()
					touch.pressed = false
					viewport.push_input(touch, true)
					_expect(visual._points.is_empty() and visual.connection_segments().is_empty(), "release clears overlay")
					_expect(completions.size() == count + (1 if length >= 3 else 0), "two cancels; 3-5 complete exactly once")
		board.reset_with_seed(20260920)
		board.begin_chain_at(Vector2i.ZERO)
		_expect(not board.extend_chain_to(Vector2i.ONE), "diagonal selection still rejected")
		_expect(visual.connection_segments().is_empty(), "no diagonal drawn")
		board.finish_chain()
		# Sub-unit positive hunger stays eligible; formatting cannot satisfy the model.
		var runner = main.lane_field.spawn_runner(1, 55, "N", "nibbler", 30)
		runner.auto_advance = false
		runner.motion.progress = 0.99
		runner.monster_state.apply_satisfaction(29.8)
		var exact: float = runner.monster_state.hunger_remaining
		var ratio: float = exact / runner.monster_state.hunger_max
		_expect(LaneVisual.hunger_text(exact, 30) == "1/30", "real sub-unit state displays one")
		_expect(runner.monster_state.hunger_remaining == exact and exact / runner.monster_state.hunger_max == ratio, "exact model and bar source unchanged")
		_expect(main.lane_field.select_nearest_target() == runner, "positive fraction remains real target")
		print("ART_01D_TOUCH height=%d 72 chains overall; real subunit=%s" % [height, exact])
		viewport.queue_free()
		await process_frame
	print("ART_01D_AUDIT %d checks %d failures" % [checks, failures])
	quit(0 if checks > 0 and failures == 0 else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ART_01D_AUDIT: " + message)
