class_name WaveDirector
extends Node

signal monster_spawned(payload: Dictionary)
signal wave_completed(payload: Dictionary)

enum State {
	IDLE,
	COUNTDOWN,
	RUNNING,
	AWAITING_RESOLUTION,
	COMPLETED,
}

const NOT_CONFIGURED := "NOT_CONFIGURED"
const UNKNOWN_WAVE := "UNKNOWN_WAVE"
const INVALID_COUNTDOWN := "INVALID_COUNTDOWN"
const INVALID_DELTA := "INVALID_DELTA"
const WAVE_ALREADY_ACTIVE := "WAVE_ALREADY_ACTIVE"

var auto_advance := true
var state := State.IDLE
var paused := false
var current_wave_id := ""
var countdown_remaining_sec := 0.0
var wave_elapsed_sec := 0.0

var _lane_field: LaneField
var _waves_by_id: Dictionary = {}
var _monsters_by_id: Dictionary = {}
var _schedule: Array[Dictionary] = []
var _spawned_runners: Dictionary = {}
var _pending_sequences: Dictionary = {}
var _next_spawn_index := 0
var _scheduled_spawn_count := 0
var _resolved_count := 0
var _satisfied_count := 0
var _counter_reached_count := 0
var _completion_emitted := false
var _duration_target_sec := 0.0
var _teaches := ""


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func configure(validated_content: Dictionary, lane_field: LaneField) -> Dictionary:
	if _is_wave_active():
		return _failure(WAVE_ALREADY_ACTIVE, "cannot configure while a wave is active")
	if lane_field == null:
		return _failure(NOT_CONFIGURED, "lane_field is required")

	_disconnect_lane_field()
	_lane_field = lane_field
	_waves_by_id.clear()
	_monsters_by_id.clear()
	for wave in validated_content.get("waves", []):
		_waves_by_id[str(wave["id"])] = wave.duplicate(true)
	for monster in validated_content.get("monsters", []):
		_monsters_by_id[str(monster["id"])] = monster.duplicate(true)
	_lane_field.monster_satisfied.connect(_on_monster_satisfied)
	_lane_field.monster_reached_counter.connect(_on_monster_reached_counter)
	state = State.IDLE
	return {"ok": true, "wave_count": _waves_by_id.size()}


func start_wave(wave_id: String, countdown_sec: float) -> Dictionary:
	if _lane_field == null:
		return _failure(NOT_CONFIGURED, "configure must be called before start_wave")
	if _is_wave_active():
		return _failure(WAVE_ALREADY_ACTIVE, "another wave is still active")
	if not is_finite(countdown_sec) or countdown_sec < 0.0:
		return _failure(INVALID_COUNTDOWN, "countdown_sec must be finite and >= 0")
	if not _waves_by_id.has(wave_id):
		return _failure(UNKNOWN_WAVE, "unknown wave: %s" % wave_id)

	var wave: Dictionary = _waves_by_id[wave_id]
	current_wave_id = wave_id
	countdown_remaining_sec = countdown_sec
	wave_elapsed_sec = 0.0
	paused = false
	_next_spawn_index = 0
	_resolved_count = 0
	_satisfied_count = 0
	_counter_reached_count = 0
	_completion_emitted = false
	_duration_target_sec = float(wave["duration_target_sec"])
	_teaches = str(wave.get("teaches", ""))
	_spawned_runners.clear()
	_pending_sequences.clear()
	_schedule = _build_schedule(wave["spawns"])
	_scheduled_spawn_count = _schedule.size()
	state = State.COUNTDOWN if countdown_sec > 0.0 else State.RUNNING
	if state == State.RUNNING:
		_advance_running(0.0)
	return _success()


func advance(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0:
		return _failure(INVALID_DELTA, "delta must be finite and >= 0")
	if paused:
		return _success()

	match state:
		State.COUNTDOWN:
			if delta < countdown_remaining_sec:
				countdown_remaining_sec -= delta
			else:
				var running_delta := delta - countdown_remaining_sec
				countdown_remaining_sec = 0.0
				state = State.RUNNING
				_advance_running(running_delta)
		State.RUNNING:
			_advance_running(delta)
		State.AWAITING_RESOLUTION:
			wave_elapsed_sec += delta
			_try_complete()
	return _success()


func set_paused(value: bool) -> void:
	paused = value


func get_state_name() -> String:
	return State.keys()[state]


func get_spawned_count() -> int:
	return _spawned_runners.size()


func get_resolved_count() -> int:
	return _resolved_count


func get_pending_count() -> int:
	return _pending_sequences.size()


func get_spawned_runner(spawn_sequence: int) -> LaneRunner:
	return _spawned_runners.get(spawn_sequence, null) as LaneRunner


func has_wave(wave_id: String) -> bool:
	return _waves_by_id.has(wave_id)


func _advance_running(delta: float) -> void:
	wave_elapsed_sec += delta
	while _next_spawn_index < _schedule.size():
		var scheduled: Dictionary = _schedule[_next_spawn_index]
		if float(scheduled["at_sec"]) > wave_elapsed_sec:
			break
		_spawn_scheduled_monster(scheduled)
		_next_spawn_index += 1
	if _next_spawn_index == _schedule.size():
		state = State.AWAITING_RESOLUTION
		_try_complete()


func _spawn_scheduled_monster(scheduled: Dictionary) -> void:
	var monster_id := str(scheduled["monster_id"])
	var monster: Dictionary = _monsters_by_id[monster_id]
	var runner := _lane_field.spawn_runner(
		int(scheduled["lane"]),
		float(monster["speed"]),
		"M",
		monster_id,
		float(monster["hunger"])
	)
	var spawn_sequence := runner.monster_state.spawn_sequence
	_spawned_runners[spawn_sequence] = runner
	_pending_sequences[spawn_sequence] = true
	monster_spawned.emit({
		"wave_id": current_wave_id,
		"source_index": int(scheduled["source_index"]),
		"at_sec": float(scheduled["at_sec"]),
		"spawn_sequence": spawn_sequence,
		"monster_id": monster_id,
		"lane": int(scheduled["lane"]),
	})


func _on_monster_satisfied(payload: Dictionary) -> void:
	_mark_resolved(int(payload.get("spawn_sequence", -1)), true)


func _on_monster_reached_counter(payload: Dictionary) -> void:
	_mark_resolved(int(payload.get("spawn_sequence", -1)), false)


func _mark_resolved(spawn_sequence: int, was_satisfied: bool) -> void:
	if not _pending_sequences.has(spawn_sequence):
		return
	_pending_sequences.erase(spawn_sequence)
	_resolved_count += 1
	if was_satisfied:
		_satisfied_count += 1
	else:
		_counter_reached_count += 1
	_try_complete()


func _try_complete() -> void:
	if _completion_emitted:
		return
	if _next_spawn_index < _scheduled_spawn_count or not _pending_sequences.is_empty():
		return
	state = State.COMPLETED
	_completion_emitted = true
	wave_completed.emit({
		"wave_id": current_wave_id,
		"scheduled_spawn_count": _scheduled_spawn_count,
		"resolved_count": _resolved_count,
		"satisfied_count": _satisfied_count,
		"counter_reached_count": _counter_reached_count,
		"wave_elapsed_sec": wave_elapsed_sec,
		"duration_target_sec": _duration_target_sec,
		"teaches": _teaches,
	})


func _build_schedule(source_spawns: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_index in range(source_spawns.size()):
		var scheduled: Dictionary = source_spawns[source_index].duplicate(true)
		scheduled["source_index"] = source_index
		result.append(scheduled)
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_time := float(a["at_sec"])
		var b_time := float(b["at_sec"])
		if a_time == b_time:
			return int(a["source_index"]) < int(b["source_index"])
		return a_time < b_time
	)
	return result


func _is_wave_active() -> bool:
	return state in [State.COUNTDOWN, State.RUNNING, State.AWAITING_RESOLUTION]


func _disconnect_lane_field() -> void:
	if _lane_field == null:
		return
	if _lane_field.monster_satisfied.is_connected(_on_monster_satisfied):
		_lane_field.monster_satisfied.disconnect(_on_monster_satisfied)
	if _lane_field.monster_reached_counter.is_connected(_on_monster_reached_counter):
		_lane_field.monster_reached_counter.disconnect(_on_monster_reached_counter)


func _success() -> Dictionary:
	return {
		"ok": true,
		"state": get_state_name(),
		"wave_id": current_wave_id,
		"countdown_remaining_sec": countdown_remaining_sec,
		"wave_elapsed_sec": wave_elapsed_sec,
		"spawned_count": get_spawned_count(),
		"resolved_count": _resolved_count,
	}


func _failure(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error_code,
		"message": message,
	}
