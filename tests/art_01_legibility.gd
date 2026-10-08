extends SceneTree
## Real raster tests at 32px; no claim about missing reference images.
const Art = preload("res://scripts/visuals/art_01_style.gd")

class Token extends Control:
	var id: String
	var phase: String
	var silhouette := false
	func _draw() -> void:
		Art.draw_proxy(self, Rect2(2, 2, 28, 28), id, phase, silhouette)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var specimens := [["nibbler", "calm"], ["salsa_tank", "calm"], ["swift_hopper", "calm"], ["boss_big_glutton", "calm"], ["boss_big_glutton", "phase2_transition_cue_cosmetic_only"], ["boss_big_glutton", "final_bite"]]
	var sheet := Image.create(6 * 160, 3 * 160, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("fff1d2"))
	var masks: Array[PackedByteArray] = []
	var failures := 0
	for index in range(specimens.size()):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(32, 32)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var token := Token.new()
		token.id = specimens[index][0]
		token.phase = specimens[index][1]
		viewport.add_child(token)
		await process_frame
		await RenderingServer.frame_post_draw
		var color_image := viewport.get_texture().get_image()
		var gray := color_image.duplicate() as Image
		for y in range(32):
			for x in range(32):
				var pixel := gray.get_pixel(x, y)
				var value := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
				gray.set_pixel(x, y, Color(value, value, value, pixel.a))
		token.silhouette = true
		token.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var solid := viewport.get_texture().get_image()
		var mask := PackedByteArray()
		var ink := 0
		for y in range(32):
			for x in range(32):
				var pixel := solid.get_pixel(x, y)
				mask.append(1 if pixel.a >= 0.5 else 0)
				if pixel.a >= 0.5:
					ink += 1
					if pixel.r > 0.02 or pixel.g > 0.02 or pixel.b > 0.02: failures += 1
		if ink < 100 or ink > 950: failures += 1
		if mask in masks: failures += 1
		masks.append(mask)
		print("ART_32 %s %s solid_pixels=%d distinct_mask=%s" % [token.id, token.phase, ink, masks.count(mask) == 1])
		for row in range(3):
			var sample: Image = [color_image, gray, solid][row]
			if sample.save_png(directory.path_join("token-%d-%d-32.png" % [index, row])) != OK: failures += 1
			sample.resize(128, 128, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(sample, Rect2i(0, 0, 128, 128), Vector2i(index * 160 + 16, row * 160 + 16))
		viewport.queue_free()
		await process_frame
	if sheet.save_png(directory.path_join("legibility-sheet.png")) != OK: failures += 1
	print("ART_LEGIBILITY 6 proxies 3 modes %d failures" % failures)
	quit(0 if failures == 0 else 1)
