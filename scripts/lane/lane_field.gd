class_name LaneField
extends Control

signal dish_created(payload: Dictionary)
signal dish_served(payload: Dictionary)
signal monster_satisfied(payload: Dictionary)

const LANE_COUNT := 3
const RUNNER_SCENE := preload("res://scenes/lane/LaneRunner.tscn")
const EFFECT_BRIEF_STUN := "brief_stun"
const EFFECT_BONUS_SATISFACTION_BURST := "bonus_satisfaction_burst"

@onready var lane_hosts: Array[Control] = [%Lane0, %Lane1, %Lane2]

var _runners: Array[LaneRunner] = []
var _next_spawn_sequence := 1


func lane_count() -> int:
	return lane_hosts.size()


func spawn_runner(
	lane_index: int,
	speed_relative: float,
	display_text: String = "M",
	monster_id: String = "monster",
	hunger_max: float = 30.0
) -> LaneRunner:
	if lane_index < 0 or lane_index >= LANE_COUNT:
		push_error("lane_index must be 0, 1, or 2")
		return null
	if not is_finite(speed_relative) or speed_relative <= 0.0:
		push_error("speed_relative must be finite and > 0")
		return null
	if monster_id.is_empty():
		push_error("monster_id must be non-empty")
		return null
	if not is_finite(hunger_max) or hunger_max <= 0.0:
		push_error("hunger_max must be finite and > 0")
		return null
	var runner := RUNNER_SCENE.instantiate() as LaneRunner
	lane_hosts[lane_index].add_child(runner)
	runner.configure(
		lane_index,
		speed_relative,
		display_text,
		monster_id,
		hunger_max,
		_next_spawn_sequence
	)
	_next_spawn_sequence += 1
	_runners.append(runner)
	return runner


func select_nearest_target() -> LaneRunner:
	var selected: LaneRunner = null
	for runner in _runners:
		if not is_instance_valid(runner) or not runner.is_targetable():
			continue
		if selected == null or _is_higher_priority(runner, selected):
			selected = runner
	return selected


func resolve_dish(resolution: Dictionary) -> Dictionary:
	if not resolution.get("ok", false):
		return {"ok": false, "target_found": false}

	var target := select_nearest_target()
	var created_payload := _dish_created_payload(resolution, target != null)
	dish_created.emit(created_payload)
	if target == null:
		return {"ok": true, "target_found": false, "dish": created_payload}

	var transitioned_to_satisfied := false
	var satisfaction_applied := 0.0
	var base_result := target.monster_state.apply_satisfaction(
		float(resolution.get("satisfaction_final", 0.0))
	)
	if not base_result.get("ok", false):
		return {
			"ok": false,
			"error": base_result.get("error", "SATISFACTION_REJECTED"),
			"target_found": true,
			"dish": created_payload,
			"satisfaction_result": base_result,
		}
	satisfaction_applied += float(base_result["satisfaction_applied"])
	transitioned_to_satisfied = base_result["transitioned_to_satisfied"]

	var effect := str(resolution.get("special_effect", ""))
	var effect_params: Dictionary = resolution.get("special_effect_params", {})
	if resolution.get("special_effect_triggered", false):
		match effect:
			EFFECT_BRIEF_STUN:
				target.apply_brief_stun(float(effect_params.get("duration_sec", 0.0)))
			EFFECT_BONUS_SATISFACTION_BURST:
				var burst_result := target.monster_state.apply_satisfaction(
					float(effect_params.get("amount", 0.0))
				)
				if burst_result.get("ok", false):
					satisfaction_applied += float(burst_result["satisfaction_applied"])
					transitioned_to_satisfied = (
						transitioned_to_satisfied
						or burst_result["transitioned_to_satisfied"]
					)

	var served_payload := {
		"spawn_sequence": target.monster_state.spawn_sequence,
		"lane": target.monster_state.lane,
		"satisfaction_applied": satisfaction_applied,
		"hunger_remaining_after": target.monster_state.hunger_remaining,
	}
	dish_served.emit(served_payload)
	if transitioned_to_satisfied:
		monster_satisfied.emit({
			"spawn_sequence": target.monster_state.spawn_sequence,
			"monster_id": target.monster_state.monster_id,
			"lane": target.monster_state.lane,
		})

	return {
		"ok": base_result.get("ok", false),
		"target_found": true,
		"dish": created_payload,
		"served": served_payload,
		"monster_became_satisfied": transitioned_to_satisfied,
	}


func get_lane_host(lane_index: int) -> Control:
	if lane_index < 0 or lane_index >= LANE_COUNT:
		return null
	return lane_hosts[lane_index]


func _is_higher_priority(candidate: LaneRunner, current: LaneRunner) -> bool:
	var candidate_progress := candidate.motion.progress
	var current_progress := current.motion.progress
	if not is_equal_approx(candidate_progress, current_progress):
		return candidate_progress > current_progress

	var candidate_lane_priority := _lane_priority(candidate.monster_state.lane)
	var current_lane_priority := _lane_priority(current.monster_state.lane)
	if candidate_lane_priority != current_lane_priority:
		return candidate_lane_priority < current_lane_priority
	return candidate.monster_state.spawn_sequence < current.monster_state.spawn_sequence


func _lane_priority(lane_index: int) -> int:
	match lane_index:
		1:
			return 0
		0:
			return 1
		2:
			return 2
		_:
			return 3


func _dish_created_payload(resolution: Dictionary, target_found: bool) -> Dictionary:
	return {
		"recipe_id": str(resolution.get("recipe_id", "")),
		"ingredient_id": str(resolution.get("ingredient_id", "")),
		"chain_length": int(resolution.get("chain_length", 0)),
		"chain_tier": str(resolution.get("chain_tier", "")),
		"satisfaction_final": float(resolution.get("satisfaction_final", 0.0)),
		"special_effect": str(resolution.get("special_effect", "")),
		"special_effect_params": resolution.get("special_effect_params", {}).duplicate(true),
		"target_found": target_found,
	}
