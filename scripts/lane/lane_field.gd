class_name LaneField
extends Control

const LANE_COUNT := 3
const RUNNER_SCENE := preload("res://scenes/lane/LaneRunner.tscn")

@onready var lane_hosts: Array[Control] = [%Lane0, %Lane1, %Lane2]


func lane_count() -> int:
	return lane_hosts.size()


func spawn_runner(lane_index: int, speed_relative: float, display_text: String = "M") -> LaneRunner:
	if lane_index < 0 or lane_index >= LANE_COUNT:
		push_error("lane_index must be 0, 1, or 2")
		return null
	if speed_relative <= 0.0:
		push_error("speed_relative must be > 0")
		return null
	var runner := RUNNER_SCENE.instantiate() as LaneRunner
	lane_hosts[lane_index].add_child(runner)
	runner.configure(lane_index, speed_relative, display_text)
	return runner


func get_lane_host(lane_index: int) -> Control:
	if lane_index < 0 or lane_index >= LANE_COUNT:
		return null
	return lane_hosts[lane_index]
