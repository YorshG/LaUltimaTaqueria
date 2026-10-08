extends SceneTree
## Rec.709 luminance conversion of actual rendered screenshots for inspection.
func _initialize() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	for prefix in ["art01c", "art01d"]:
		for height in [1620, 1920, 2400]:
			for mode in ["unselected", "turns", "chain-2", "chain-3", "chain-4", "chain-5"]:
				var path := directory.path_join("%s-%s-%d.png" % [prefix, mode, height])
				var image := Image.load_from_file(path)
				for y in range(image.get_height()):
					for x in range(image.get_width()):
						var color := image.get_pixel(x, y)
						var gray := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
						image.set_pixel(x, y, Color(gray, gray, gray, color.a))
				if image.save_png(path.replace(".png", "-gray.png")) != OK:
					quit(1); return
	print("ART_01D_GRAYSCALE 36 images")
	quit(0)
