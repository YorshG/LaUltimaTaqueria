extends RefCounted
## One shared texture; source vectors remain editable in art_01_style.gd.
const TEXTURE = preload("res://assets/provisional/art_01b_atlas.png")
const INGREDIENTS := ["tortilla", "meat", "veggie"]
const MONSTERS := ["nibbler", "salsa_tank", "swift_hopper"]
const PHASES := ["calm", "phase2_transition_cue_cosmetic_only", "final_bite"]

static func draw_token(canvas: CanvasItem, destination: Rect2, id: String, phase: String = "calm") -> void:
	var column := INGREDIENTS.find(id)
	var row := 2
	if column < 0:
		column = MONSTERS.find(id)
		row = 0
	if id == "boss_big_glutton":
		column = maxi(0, PHASES.find(phase))
		row = 1
	if column < 0: return
	# Four pixels of padding preserve outlines at the edges of vector bounds.
	var source := Rect2(column * 168 + 4, row * 168 + 4, 160, 160)
	canvas.draw_texture_rect_region(TEXTURE, destination.grow(destination.size.x * 4.0 / 152.0), source)
