extends SceneTree
const Fixture = preload("res://tests/art_01d_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func capture(viewport: SubViewport) -> Image:
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()
func luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
func _run() -> void:
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, height)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var app = load("res://scenes/App.tscn").instantiate()
		viewport.add_child(app)
		var main = app.get_session()
		Fixture.populate(main)
		app.get_node("Layout").set_test_metrics(Rect2(0, 177, 1080, height - 279), Transform2D.IDENTITY, 3.0)
		for frame in range(8): await process_frame
		var board: BoardView = main.board_view
		for ingredient in ["tortilla", "meat", "veggie"]:
			for path in [Fixture.TURNS, Fixture.EDGE]:
				Fixture.arrange(board, path, ingredient)
				var before := await capture(viewport)
				board.begin_chain_at(path[0])
				for point in path.slice(1): board.extend_chain_to(point)
				var after := await capture(viewport)
				for cell in board.grid.get_children():
					var unit := minf(cell.size.x * 0.66, cell.size.y * 0.60)
					var token := Rect2i(cell.global_position + Vector2((cell.size.x - unit) / 2, cell.size.y * 0.07), Vector2.ONE * unit)
					_expect(before.get_region(token).get_data() == after.get_region(token).get_data(), "all 25 ingredient image regions unchanged during five-cell chain")
				var visual = board.get_node("BoardVisual")
				for segment in visual.connection_segments():
					var middle: Vector2 = visual.get_global_transform() * ((segment[0] + segment[1]) / 2)
					var shoulder := middle + (Vector2(0, 14) if segment[0].y == segment[1].y else Vector2(14, 0))
					var bright := luminance(after.get_pixelv(Vector2i(middle)))
					var dark := luminance(after.get_pixelv(Vector2i(shoulder)))
					_expect(bright > 0.8 and bright - dark > 0.4, "actual bridge pixels stand out in grayscale, distinct from parallel rails")
				print("ART_01D_PIXELS height=%d ingredient=%s start=%s: 25 unchanged tokens / 4 distinct bridges" % [height, ingredient, path[0]])
				# Avoid resolving/repopulating, then clear through the existing cancel path.
				board.begin_chain_at(path[0])
				board.finish_chain()
		viewport.queue_free()
		await process_frame
	print("ART_01D_PIXELS %d checks %d failures" % [checks, failures])
	quit(0 if checks > 0 and failures == 0 else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ART_01D_PIXELS: " + message)
