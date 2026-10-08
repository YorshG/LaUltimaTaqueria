extends SceneTree
## Contact sheets of actual captures, no painting or reconstruction of UI.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1640, height / 2 + 70)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var textures: Array[Texture2D] = []
		for prefix in ["uat", "art01", "art01b"]:
			textures.append(ImageTexture.create_from_image(Image.load_from_file(directory.path_join("%s-%d.png" % [prefix, height]))))
		var canvas := Control.new()
		viewport.add_child(canvas)
		canvas.draw.connect(func():
			canvas.draw_rect(Rect2(Vector2.ZERO, viewport.size), Color("17172f"))
			for i in range(3):
				canvas.draw_string(ThemeDB.fallback_font, Vector2(i * 550 + 12, 42), ["uat · baseline", "ART-01 · antes", "ART-01B · propuesta"][i], HORIZONTAL_ALIGNMENT_LEFT, 516, 30, Color("fff1d2"))
				canvas.draw_texture_rect(textures[i], Rect2(i * 550, 70, 540, height / 2), false)
		)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image().save_png(directory.path_join("comparison-%d.png" % height))
		if result != OK: quit(1); return
		viewport.queue_free()
		await process_frame
	print("ART_01B_COMPARISONS PASS")
	quit(0)
