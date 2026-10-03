extends SceneTree
## A minimal probe remains safe even under the deliberate free-before-signal mutant.
const FIELD = preload("res://scenes/lane/LaneField.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var field = FIELD.instantiate()
	root.add_child(field)
	var runner = field.spawn_runner(1, 55.0, "M", "nibbler", 30.0)
	runner.auto_advance = false
	var runner_id: int = runner.get_instance_id()
	var observation := {"count": 0, "alive": false, "visible": false}
	field.monster_reached_counter.connect(func(_payload):
		observation["count"] += 1
		var observed_runner = instance_from_id(runner_id)
		observation["alive"] = is_instance_valid(observed_runner)
		if is_instance_valid(observed_runner):
			observation["visible"] = observed_runner.visible and not observed_runner.is_queued_for_deletion())
	# Invoke the field's adapter directly so the deliberately premature free mutant
	# fails object lifetime assertions rather than Godot's locked-signal protection.
	# The full retirement suite separately drives real runner.advance() breaches.
	runner.monster_state.active = false
	field._on_runner_reached_counter({"spawn_sequence": runner.monster_state.spawn_sequence}, runner)
	var ok: bool = observation["count"] == 1 and observation["alive"] and observation["visible"] and is_instance_valid(runner)
	print("VIS_EVENT_LIFETIME %s: %s" % ["PASS" if ok else "FAIL", observation])
	field.free()
	quit(0 if ok else 1)
