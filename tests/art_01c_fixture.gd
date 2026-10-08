extends RefCounted
## Frozen test staging only. Canonical stats always come from validated content.
const Registry = preload("res://scripts/content/content_registry.gd")
const IDS := ["nibbler", "salsa_tank", "swift_hopper"]
const PROGRESS := [0.28, 0.46, 0.68]
const BOARD_SEED := 20260920

static func populate(main, mode: String = "regular", count: int = 3) -> Array[Dictionary]:
	main.feedback_audio.playback_enabled = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.board_view.reset_with_seed(BOARD_SEED)
	for child in main.lane_field._runners.duplicate(): child.free()
	var content: Dictionary = Registry.new().load_and_validate().content
	var definitions := {}
	for monster in content.monsters: definitions[monster.id] = monster
	var snapshot: Array[Dictionary] = []
	var crowded := mode == "crowded"
	for index in range(9 if crowded else count):
		var id: String = IDS[index % 3]
		var spec: Dictionary = definitions[id]
		var lane := index / 3 if crowded else index % 3
		var runner = main.lane_field.spawn_runner(lane, spec.speed, ["N", "S", "H"][index % 3], id, spec.hunger)
		runner.auto_advance = false
		runner.motion.progress = 0.46 if crowded else (PROGRESS[index] if count == 3 else 0.15 + index * 0.10)
		if mode in ["fractional", "crowded"]:
			# Reproduces non-integer model values, including long binary fractions.
			runner.monster_state.apply_satisfaction([2.5, 2.375, 1.0 / 3.0][index % 3])
		runner.advance(0)
		snapshot.append({"id": id, "lane": lane, "speed": spec.speed, "maximum": spec.hunger, "remaining": runner.monster_state.hunger_remaining, "progress": runner.motion.progress, "sequence": runner.monster_state.spawn_sequence})
	return snapshot
