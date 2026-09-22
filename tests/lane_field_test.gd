extends SceneTree

var failures := 0
var Motion = preload("res://scripts/lane/lane_motion.gd")


func _init() -> void:
	_test_motion_model()
	await _test_lane_field()
	await _test_satisfied_runner_stops()
	await _test_counter_arrival_is_one_shot()

	if failures == 0:
		print("LANE-01 tests passed: 3 lanes / independent configurable movement.")
		quit(0)
	else:
		push_error("LANE-01 tests failed: %d" % failures)
		quit(1)


func _test_motion_model() -> void:
	var slow = Motion.new(0, 30.0)
	var medium = Motion.new(1, 55.0)
	var fast = Motion.new(2, 90.0)

	slow.advance(1.0)
	medium.advance(1.0)
	fast.advance(1.0)

	_expect(slow.progress < medium.progress, "speed 30 must move less than speed 55")
	_expect(medium.progress < fast.progress, "speed 55 must move less than speed 90")
	_expect(is_equal_approx(slow.progress, 0.03), "speed 30 must advance 0.03 lane/s")
	_expect(is_equal_approx(medium.progress, 0.055), "speed 55 must advance 0.055 lane/s")
	_expect(is_equal_approx(fast.progress, 0.09), "speed 90 must advance 0.09 lane/s")

	var phased = Motion.new(0, 55.0)
	phased.phase_multiplier = 0.5
	_expect(is_equal_approx(phased.effective_speed(), 0.0275), "phase multiplier must scale effective speed")

	var globally_scaled = Motion.new(2, 55.0)
	globally_scaled.global_speed_multiplier = 2.0
	_expect(is_equal_approx(globally_scaled.effective_speed(), 0.11), "global multiplier must scale effective speed")

	var before_medium: float = medium.progress
	slow.global_speed_multiplier = 0.5
	slow.advance(1.0)
	_expect(is_equal_approx(medium.progress, before_medium), "changing slow runner must not move medium runner")
	_expect(is_equal_approx(slow.effective_speed(), 0.015), "global multiplier must affect only configured motion")

	var stunned = Motion.new(1, 100.0)
	stunned.phase_multiplier = 0.5
	stunned.global_speed_multiplier = 2.0
	_expect(stunned.apply_brief_stun(1.0), "positive finite stun must be accepted")
	_expect(is_zero_approx(stunned.effective_speed()), "effective speed must be zero during stun")
	stunned.advance(0.4)
	stunned.advance(0.6)
	_expect(is_zero_approx(stunned.progress), "several deltas totaling stun duration must not move")
	_expect(not stunned.is_stunned(), "stun must expire after its deterministic duration")
	stunned.advance(0.5)
	_expect(is_equal_approx(stunned.progress, 0.05), "movement must resume with existing multipliers")

	var partial_frame = Motion.new(0, 100.0)
	partial_frame.apply_brief_stun(0.25)
	partial_frame.advance(0.5)
	_expect(is_equal_approx(partial_frame.progress, 0.025), "delta remainder after stun must move deterministically")
	_expect(not partial_frame.apply_brief_stun(0.0), "zero stun duration must be rejected")
	_expect(not partial_frame.apply_brief_stun(-1.0), "negative stun duration must be rejected")


func _test_lane_field() -> void:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")
	_expect(packed != null, "LaneField scene must load")
	if packed == null:
		return
	var field = packed.instantiate()
	get_root().add_child(field)
	await process_frame

	_expect(field.lane_count() == 3, "LaneField must expose exactly 3 lanes")

	var left = field.spawn_runner(0, 30.0, "L")
	var center = field.spawn_runner(1, 55.0, "C")
	var right = field.spawn_runner(2, 90.0, "R")
	_expect(left != null and center != null and right != null, "all lanes must accept independent runners")
	if left == null or center == null or right == null:
		return

	left.auto_advance = false
	center.auto_advance = false
	right.auto_advance = false
	left.advance(1.0)
	center.advance(1.0)
	right.advance(1.0)

	_expect(left.get_parent() != center.get_parent(), "left and center must have independent lane hosts")
	_expect(center.get_parent() != right.get_parent(), "center and right must have independent lane hosts")
	_expect(left.motion.progress < center.motion.progress and center.motion.progress < right.motion.progress, "runner progress must respect configured speed")


func _test_satisfied_runner_stops() -> void:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")
	var field: LaneField = packed.instantiate()
	get_root().add_child(field)
	await process_frame

	var runner := field.spawn_runner(1, 100.0, "S", "nibbler", 10.0)
	runner.auto_advance = true
	runner.motion.progress = 0.25
	var satisfaction: Dictionary = runner.monster_state.apply_satisfaction(10.0)
	var progress_when_satisfied: float = runner.motion.progress
	runner._process(5.0)

	_expect(satisfaction["transitioned_to_satisfied"], "runner state must become satisfied")
	_expect(not runner.monster_state.active, "satisfied runner state must be inactive")
	_expect(
		is_equal_approx(runner.motion.progress, progress_when_satisfied),
		"inactive satisfied runner must not continue automatic movement"
	)
	_expect(is_instance_valid(runner) and runner.is_inside_tree(), "retired runner node may remain in scene")


func _test_counter_arrival_is_one_shot() -> void:
	var packed: PackedScene = load("res://scenes/lane/LaneField.tscn")
	var field: LaneField = packed.instantiate()
	get_root().add_child(field)
	await process_frame

	var arrivals: Array[Dictionary] = []
	field.monster_reached_counter.connect(func(payload: Dictionary): arrivals.append(payload))
	var runner := field.spawn_runner(2, 100.0, "C", "nibbler", 30.0)
	runner.auto_advance = false
	runner.advance(10.0)
	runner.advance(10.0)

	_expect(arrivals.size() == 1, "counter arrival must emit exactly once")
	_expect(not runner.monster_state.active, "counter arrival must retire monster logically")
	_expect(not runner.monster_state.satisfied, "counter arrival must not mark monster satisfied")
	_expect(is_equal_approx(runner.motion.progress, 1.0), "counter arrival must retain LaneMotion progress")
	if not arrivals.is_empty():
		_expect(arrivals[0].keys().size() == 3, "counter payload must remain minimal")
		_expect(arrivals[0]["spawn_sequence"] == runner.monster_state.spawn_sequence, "counter payload must include stable sequence")
		_expect(arrivals[0]["monster_id"] == "nibbler", "counter payload must include monster id")
		_expect(arrivals[0]["lane"] == 2, "counter payload must include lane")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
