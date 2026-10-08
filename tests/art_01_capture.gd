extends SceneTree
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
	var main = app.get_session()
	# The fixture measures pixels only; do not exit while a synthetic cue is playing.
	main.feedback_audio.playback_enabled = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for child in main.lane_field._runners.duplicate():
		child.free()
	if mode == "regular":
		for index in range(3):
			var ids := ["nibbler", "salsa_tank", "swift_hopper"]
			var runner = main.lane_field.spawn_runner(index, 55, ["N", "S", "H"][index], ids[index], 70)
			runner.motion.progress = [0.28, 0.46, 0.68][index]
			runner.advance(0)
	else:
		var content = main._boss_content
		var boss = main.lane_field.spawn_runner(1, content.speed, "B", content.id, content.hunger)
		boss.monster_state.configure_phases(content.phases)
		if mode == "boss2": boss.monster_state.apply_satisfaction(120)
		if mode == "boss3": boss.monster_state.apply_satisfaction(210)
		boss.motion.progress = 0.45
		boss.advance(0)
		main.run_status.text = "El último cliente"
	await process_frame
	await process_frame
	for runner in main.lane_field._runners:
		runner.advance(0)
	main.board_view.begin_chain_at(Vector2i(0, 0))
	main.board_view.extend_chain_to(Vector2i(1, 0))
	main.board_view.extend_chain_to(Vector2i(2, 0))
	# Allow presentation to redraw the frozen fixture without advancing gameplay.
	for visual in main.find_children("*", "Control", true, false):
		if visual.has_method("refresh_visuals"):
			visual.refresh_visuals()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(destination)
	print("ART_CAPTURE %s %dx%d result=%d" % [mode, 1080, height, result])
	viewport.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
