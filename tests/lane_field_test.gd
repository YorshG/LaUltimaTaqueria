extends SceneTree

var failures := 0
var Motion = preload("res://scripts/lane/lane_motion.gd")


func _init() -> void:
	_test_motion_model()
	await _test_lane_field()

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

	var before_medium: float = medium.progress
	slow.global_speed_multiplier = 0.5
	slow.advance(1.0)
	_expect(is_equal_approx(medium.progress, before_medium), "changing slow runner must not move medium runner")
	_expect(is_equal_approx(slow.effective_speed(), 0.015), "global multiplier must affect only configured motion")


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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
