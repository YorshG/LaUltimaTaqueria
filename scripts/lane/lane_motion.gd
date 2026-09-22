class_name LaneMotion
extends RefCounted

const LANE_COUNT := 3
const LANE_REFERENCE_SPEED := 0.10

var lane_index := 0
var speed_relative := 55.0
var phase_multiplier := 1.0
var global_speed_multiplier := 1.0
var progress := 0.0
var stun_remaining_sec := 0.0


func _init(p_lane_index: int = 0, p_speed_relative: float = 55.0) -> void:
	configure(p_lane_index, p_speed_relative)


func configure(p_lane_index: int, p_speed_relative: float) -> void:
	assert(p_lane_index >= 0 and p_lane_index < LANE_COUNT)
	assert(p_speed_relative > 0.0)
	lane_index = p_lane_index
	speed_relative = p_speed_relative
	progress = 0.0
	stun_remaining_sec = 0.0


func effective_speed() -> float:
	if stun_remaining_sec > 0.0:
		return 0.0
	return _base_effective_speed()


func apply_brief_stun(duration_sec: float) -> bool:
	if not is_finite(duration_sec) or duration_sec <= 0.0:
		return false
	stun_remaining_sec = maxf(stun_remaining_sec, duration_sec)
	return true


func is_stunned() -> bool:
	return stun_remaining_sec > 0.0


func _base_effective_speed() -> float:
	return (
		LANE_REFERENCE_SPEED
		* speed_relative / 100.0
		* phase_multiplier
		* global_speed_multiplier
	)


func advance(delta: float) -> float:
	if delta <= 0.0:
		return progress
	var movement_delta := delta
	if stun_remaining_sec > 0.0:
		var stunned_delta := minf(stun_remaining_sec, delta)
		stun_remaining_sec = maxf(stun_remaining_sec - stunned_delta, 0.0)
		movement_delta -= stunned_delta
	progress = clampf(progress + _base_effective_speed() * movement_delta, 0.0, 1.0)
	return progress


func reset() -> void:
	progress = 0.0
	stun_remaining_sec = 0.0


func reached_counter() -> bool:
	return progress >= 1.0
