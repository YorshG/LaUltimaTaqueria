extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	for height in [1620, 1920, 2400]:
		for mode in ["regular", "fractional", "crowded"]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1100, height / 2 + 80)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var textures: Array[Texture2D] = []
			for prefix in ["art01b", "art01c"]:
				textures.append(ImageTexture.create_from_image(Image.load_from_file(directory.path_join("%s-%s-%d.png" % [prefix, mode, height]))))
			var canvas := Control.new()
			viewport.add_child(canvas)
			canvas.draw.connect(func():
				canvas.draw_rect(Rect2(Vector2.ZERO, viewport.size), Color("17172f"))
				for index in range(2):
					canvas.draw_string(ThemeDB.fallback_font, Vector2(index * 550 + 10, 32), ["ART-01B · antes", "ART-01C · corrección"][index], HORIZONTAL_ALIGNMENT_LEFT, 535, 28, Color("fff1d2"))
					canvas.draw_string(ThemeDB.fallback_font, Vector2(index * 550 + 10, 62), "MISMA FIXTURE CANÓNICA · " + mode, HORIZONTAL_ALIGNMENT_LEFT, 535, 20, Color("fff1d2"))
					canvas.draw_texture_rect(textures[index], Rect2(index * 550, 80, 540, height / 2), false)
			)
			for frame in range(4): await process_frame
			await RenderingServer.frame_post_draw
			if viewport.get_texture().get_image().save_png(directory.path_join("comparison-%s-%d.png" % [mode, height])) != OK:
				quit(1); return
			viewport.queue_free()
			await process_frame
	print("ART_01C_COMPARISONS PASS")
	quit(0)
