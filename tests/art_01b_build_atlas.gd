extends SceneTree
## Offline bake of our own vector proxies. Run with a renderer, then import.
const Art = preload("res://scripts/visuals/art_01_style.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	viewport.add_child(canvas)
	canvas.draw.connect(func():
		for i in range(3):
			Art.draw_proxy(canvas, Rect2(8 + i * 168, 8, 152, 152), ["nibbler", "salsa_tank", "swift_hopper"][i])
			Art.draw_proxy(canvas, Rect2(8 + i * 168, 176, 152, 152), "boss_big_glutton", ["calm", "phase2_transition_cue_cosmetic_only", "final_bite"][i])
			Art.draw_ingredient(canvas, Rect2(8 + i * 168, 344, 152, 152), ["tortilla", "meat", "veggie"][i])
	)
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png("res://assets/provisional/art_01b_atlas.png")
	print("ART_ATLAS result=", result)
	viewport.queue_free()
	await process_frame
	quit(result)
