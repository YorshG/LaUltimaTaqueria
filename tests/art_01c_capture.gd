extends SceneTree
const Fixture = preload("res://tests/art_01c_fixture.gd")
## Staged visual evidence, not a claim of a physically played session.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var destination := args[0]
	var height := int(args[1]) if args.size() > 1 else 1920
	var mode := args[2] if args.size() > 2 else "regular"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var app = load("res://scenes/App.tscn").instantiate()
	viewport.add_child(app)
	if app.get_node("Layout").has_method("set_test_metrics"):
		app.get_node("Layout").set_test_metrics(Rect2(0, 177, 1080, height - 279), Transform2D.IDENTITY, 3.0)
	var main = app.get_session()
	var snapshot := Fixture.populate(main, mode)
	print("ART_01C_FIXTURE ", JSON.stringify({"fixture": true, "mode": mode, "seed": Fixture.BOARD_SEED, "monsters": snapshot}))
	for frame in range(8): await process_frame
	for runner in main.lane_field._runners:
		runner.advance(0)
	if mode != "unselected":
		main.board_view.begin_chain_at(Vector2i(0, 0))
		main.board_view.extend_chain_to(Vector2i(1, 0))
		main.board_view.extend_chain_to(Vector2i(2, 0))
	# Allow presentation to redraw the frozen fixture without advancing gameplay.
	for visual in main.find_children("*", "Control", true, false):
		if visual.has_method("refresh_visuals"):
			visual.refresh_visuals()
	await process_frame
	for frame in range(8): await process_frame
	if mode == "restart": app.request_restart()
	if mode == "upgrades":
		var registry = load("res://scripts/content/content_registry.gd").new()
		main.upgrade_choice.present(registry.load_and_validate().content.upgrades.slice(0, 3), 1)
		for frame in range(8): await process_frame
	if mode == "bounds":
		var overlay := Control.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		viewport.add_child(overlay)
		var zones := {"HUD": main.hud.get_global_rect(), "CARRILES": main.lane_field.get_global_rect(), "MOSTRADOR": main.get_node("Margin/Content/Counter").get_global_rect(), "TABLERO": main.board_view.get_global_rect(), "REINICIO": app.restart_button.get_global_rect()}
		overlay.draw.connect(func():
			overlay.draw_rect(Rect2(0, 0, 1080, 177), Color(0.8, 0.12, 0.2, 0.4))
			overlay.draw_rect(Rect2(0, height - 102, 1080, 102), Color(0.8, 0.12, 0.2, 0.4))
			overlay.draw_string(ThemeDB.fallback_font, Vector2(16, 70), "SAFE AREA SINTÉTICA · 177 arriba / 102 abajo", HORIZONTAL_ALIGNMENT_LEFT, 1048, 32, Color.WHITE)
			var index := 0
			for label in zones:
				var tint := Color.from_hsv(index * 0.18, 0.7, 1)
				overlay.draw_rect(zones[label], tint, false, 4)
				overlay.draw_string(ThemeDB.fallback_font, zones[label].position + Vector2(6, 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, tint)
				index += 1
		)
		print("ART_01C_BOUNDS ", JSON.stringify(zones))
		await process_frame
	var label := Label.new()
	label.text = "FIXTURE ART-01C · %s · NO PARTIDA JUGADA" % mode
	label.position = Vector2(20, 110)
	label.add_theme_font_size_override("font_size", 28)
	viewport.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(destination)
	print("ART_CAPTURE %s %dx%d result=%d" % [mode, 1080, height, result])
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
