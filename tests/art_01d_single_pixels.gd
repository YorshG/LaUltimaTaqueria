extends "res://tests/art_01c_pixels.gd"
## Explicit offscreen frame avoids depending on native-window exposure.
func capture(viewport: SubViewport) -> Image:
	for frame in range(3): await process_frame
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()
