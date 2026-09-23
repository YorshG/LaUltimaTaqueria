class_name MonsterState
extends RefCounted

signal phase_changed(payload: Dictionary)

const INVALID_SATISFACTION := "INVALID_SATISFACTION"
const MONSTER_NOT_ELIGIBLE := "MONSTER_NOT_ELIGIBLE"

var monster_id: String
var lane: int
var hunger_max: float
var hunger_remaining: float
var satisfied := false
var active := true
var spawn_sequence: int
var phase_index := -1
var _phases: Array = []


func _init(
	p_monster_id: String,
	p_lane: int,
	p_hunger_max: float,
	p_spawn_sequence: int
) -> void:
	assert(not p_monster_id.is_empty())
	assert(p_lane >= 0 and p_lane < LaneMotion.LANE_COUNT)
	assert(is_finite(p_hunger_max) and p_hunger_max > 0.0)
	assert(p_spawn_sequence >= 0)
	monster_id = p_monster_id
	lane = p_lane
	hunger_max = p_hunger_max
	hunger_remaining = p_hunger_max
	spawn_sequence = p_spawn_sequence


func is_targetable(progress: float) -> bool:
	return active and not satisfied and hunger_remaining > 0.0 and progress < 1.0


# Optional phases come from ContentRegistry's validated boss content.
func configure_phases(validated_phases: Array) -> void:
	if not _phases.is_empty():
		return
	_phases = validated_phases.duplicate(true)
	_advance_phase()


func get_current_phase() -> Dictionary:
	return {} if phase_index < 0 else _phases[phase_index].duplicate(true)


func _advance_phase() -> void:
	var hunger_ratio := hunger_remaining / hunger_max
	while phase_index + 1 < _phases.size():
		var next_index := phase_index + 1
		if next_index > 0 and hunger_ratio > float(_phases[next_index]["threshold"]):
			break
		phase_index = next_index
		phase_changed.emit(get_current_phase())


func apply_satisfaction(amount: float) -> Dictionary:
	if not is_finite(amount) or amount <= 0.0:
		return _rejection(INVALID_SATISFACTION)
	if not active or satisfied or hunger_remaining <= 0.0:
		return _rejection(MONSTER_NOT_ELIGIBLE)

	var hunger_before := hunger_remaining
	hunger_remaining = clampf(hunger_remaining - amount, 0.0, hunger_max)
	var satisfaction_applied := hunger_before - hunger_remaining
	var transitioned_to_satisfied := hunger_before > 0.0 and hunger_remaining == 0.0
	if transitioned_to_satisfied:
		hunger_remaining = 0.0
		satisfied = true
		active = false
	_advance_phase()

	return {
		"ok": true,
		"satisfaction_applied": satisfaction_applied,
		"hunger_before": hunger_before,
		"hunger_remaining_after": hunger_remaining,
		"transitioned_to_satisfied": transitioned_to_satisfied,
	}


func _rejection(error_code: String) -> Dictionary:
	return {
		"ok": false,
		"error": error_code,
		"satisfaction_applied": 0.0,
		"hunger_before": hunger_remaining,
		"hunger_remaining_after": hunger_remaining,
		"transitioned_to_satisfied": false,
	}
