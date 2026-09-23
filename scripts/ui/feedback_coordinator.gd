class_name FeedbackCoordinator
extends RefCounted

signal feedback_requested(payload: Dictionary)

# UI-only threshold: no balance rule or upgrade activation.
const LOW_REPUTATION_RATIO := 0.20
const CUE_KEYS := {
	"selection": "feedback.selection",
	"chain_valid": "feedback.chain_valid",
	"dish_created": "feedback.dish_created",
	"dish_served": "feedback.dish_served",
	"satisfied": "feedback.monster_satisfied",
	"breach": "feedback.breach",
	"low_reputation": "feedback.low_reputation",
	"upgrade": "feedback.upgrade_selected",
	"boss_phase_2": "feedback.boss_phase_2",
	"boss_phase_3": "feedback.boss_phase_3",
	"victory": "feedback.victory",
	"defeat": "feedback.defeat",
}

var _gesture_active := false
var _valid_reported := false
var _was_low := false
var _ended := false
var _reported_resolutions: Dictionary = {}
var _reported_phases: Dictionary = {}


func _init(initial_reputation: Dictionary = {}) -> void:
	_was_low = _is_low(initial_reputation)


func on_chain_started(_points: Array[Vector2i]) -> void:
	if _gesture_active:
		return
	_gesture_active = true
	_valid_reported = false
	_emit_cue("selection")


func on_chain_changed(points: Array[Vector2i]) -> void:
	if _gesture_active and not _valid_reported and points.size() >= 3:
		_valid_reported = true
		_emit_cue("chain_valid")


func on_chain_completed(_points: Array[Vector2i], _ingredient_id: String) -> void:
	on_chain_cancelled()


func on_chain_cancelled() -> void:
	_gesture_active = false
	_valid_reported = false


func on_dish_created(_payload: Dictionary) -> void:
	_emit_cue("dish_created")


func on_dish_served(_payload: Dictionary) -> void:
	_emit_cue("dish_served")


func on_monster_satisfied(payload: Dictionary) -> void:
	_report_resolution("satisfied", payload)


func on_breach(payload: Dictionary) -> void:
	_report_resolution("breach", payload)


func on_reputation_changed(payload: Dictionary) -> void:
	if _ended:
		return
	var delta := float(payload.get("delta", 0.0))
	if delta != 0.0:
		var value := String.num(delta).trim_suffix(".0")
		feedback_requested.emit({
			"cue_id": "reputation_delta",
			"text_key": "feedback.reputation_delta",
			"values": {"delta": "+" + value if delta > 0.0 else value},
			"sound_id": "",
			"terminal": false,
		})
	var low := _is_low(payload)
	if low and not _was_low:
		_emit_cue("low_reputation")
	_was_low = low


func on_upgrade_selected(_payload: Dictionary) -> void:
	_emit_cue("upgrade")


func on_boss_phase_changed(payload: Dictionary) -> void:
	var cue := ""
	match str(payload.get("behavior_tag", "")):
		"phase2_transition_cue_cosmetic_only":
			cue = "boss_phase_2"
		"final_bite":
			cue = "boss_phase_3"
	if cue.is_empty() or _reported_phases.has(cue):
		return
	_reported_phases[cue] = true
	_emit_cue(cue)


func on_boss_completed(payload: Dictionary) -> void:
	if payload.get("satisfied", false):
		_emit_cue("victory", true)


func on_run_ended(payload: Dictionary) -> void:
	if payload.get("outcome", "") == "defeat":
		_emit_cue("defeat", true)


func _report_resolution(cue: String, payload: Dictionary) -> void:
	var sequence := int(payload.get("spawn_sequence", -1))
	if sequence < 0 or _reported_resolutions.has(sequence):
		return
	_reported_resolutions[sequence] = true
	_emit_cue(cue)


func _is_low(payload: Dictionary) -> bool:
	var maximum := float(payload.get("maximum", 0.0))
	return maximum > 0.0 and float(payload.get("current", maximum)) / maximum <= LOW_REPUTATION_RATIO


func _emit_cue(cue: String, terminal: bool = false) -> void:
	if _ended:
		return
	_ended = terminal
	feedback_requested.emit({
		"cue_id": cue,
		"text_key": CUE_KEYS[cue],
		"values": {},
		"sound_id": cue,
		"terminal": terminal,
	})
