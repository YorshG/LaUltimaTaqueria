extends SceneTree
## Pixel regression on actual Godot rendering; no generated/reconstructed UI.
const Fixture = preload("res://tests/art_01c_fixture.gd")
var failures := 0
var samples: Array[Image] = []

func _initialize() -> void:
	call_deferred("_run")

func capture(viewport: SubViewport) -> Image:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func gray(source: Image) -> Image:
	var result := source.duplicate() as Image
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var color := result.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			result.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
	return result

func _run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, height)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var app = load("res://scenes/App.tscn").instantiate()
		viewport.add_child(app)
		app.get_node("Layout").set_test_metrics(Rect2(0, 177, 1080, height - 279), Transform2D.IDENTITY, 3.0)
		var main = app.get_session()
		Fixture.populate(main)
		for frame in range(8): await process_frame
		for coord in [Vector2i.ZERO, Vector2i(3, 0), Vector2i(4, 0)]:
			var cell: Control = main.board_view.grid.get_child(coord.x)
			var rect := Rect2i(cell.get_global_rect())
			var before := await capture(viewport)
			main.board_view.begin_chain_at(coord)
			var after := await capture(viewport)
			var unit := minf(cell.size.x * 0.66, cell.size.y * 0.60)
			var token := Rect2i(cell.global_position + Vector2((cell.size.x - unit) / 2, cell.size.y * 0.07), Vector2.ONE * unit)
			var identical := before.get_region(token).get_data() == after.get_region(token).get_data()
			if not identical: failures += 1
			var small_before := before.get_region(rect)
			var small_after := after.get_region(rect)
			var side := int(minf(rect.size.x, rect.size.y) / 3)
			small_before.resize(side, side, Image.INTERPOLATE_LANCZOS)
			small_after.resize(side, side, Image.INTERPOLATE_LANCZOS)
			var gray_before := gray(small_before)
			var gray_after := gray(small_after)
			var different := 0
			for y in range(side):
				for x in range(side):
					if absf(gray_before.get_pixel(x, y).r - gray_after.get_pixel(x, y).r) > 0.10: different += 1
			if different < side: failures += 1
			print("ART_01C_PIXELS height=%d ingredient=%s token_identical=%s mobile_side=%d grayscale_changed_pixels=%d" % [height, cell.get_meta("ingredient_id"), identical, side, different])
			for sample in [small_before, small_after, gray_before, gray_after]: samples.append(sample)
			main.board_view.finish_chain()
		viewport.queue_free()
		await process_frame
	# Native mobile-scale samples remain at 1:1; enlarged copies are additional.
	var sheet := Image.create(600, 9 * 80 + 60, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("17172f"))
	for row in range(9):
		for column in range(4):
			var sample: Image = samples[row * 4 + column]
			sample.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(sample, Rect2i(Vector2i.ZERO, sample.get_size()), Vector2i(column * 145 + 14, row * 80 + 54))
	if sheet.save_png(directory.path_join("selection-mobile-pixels.png")) != OK: failures += 1
	print("ART_01C_PIXELS 9 specimens color/grayscale %d failures" % failures)
	quit(0 if failures == 0 else 1)
