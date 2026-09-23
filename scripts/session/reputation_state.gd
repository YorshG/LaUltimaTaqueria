class_name ReputationState
extends RefCounted

signal reputation_changed(payload: Dictionary)
signal run_ended(payload: Dictionary)

const INITIAL_REPUTATION := 100.0

var current := INITIAL_REPUTATION
var maximum := INITIAL_REPUTATION
var defeated := false
var _breach_damage_by_id: Dictionary = {}
var _processed_breaches: Dictionary = {}


# One instance per run. Content must have passed ContentRegistry validation.
func _init(validated_content: Dictionary = {}) -> void:
	for monster in validated_content.get("monsters", []):
		_breach_damage_by_id[str(monster["id"])] = float(monster["reputation_damage"])
	var boss: Dictionary = validated_content.get("boss", {})
	if not boss.is_empty():
		_breach_damage_by_id[str(boss["id"])] = float(boss["reputation_damage_on_breach"])


func snapshot() -> Dictionary:
	return {"current": current, "maximum": maximum, "defeated": defeated}


func apply_breach(payload: Dictionary) -> Dictionary:
	var sequence := int(payload.get("spawn_sequence", -1))
	var monster_id := str(payload.get("monster_id", ""))
	if sequence < 0 or not _breach_damage_by_id.has(monster_id):
		return _result(current, false, "UNKNOWN_BREACH")
	if _processed_breaches.has(sequence):
		return _result(current, false, "DUPLICATE_BREACH")
	# Mark before emitting signals, including reentrant duplicate callbacks.
	_processed_breaches[sequence] = true
	return apply_damage(float(_breach_damage_by_id[monster_id]))


func apply_damage(amount: float) -> Dictionary:
	return _change(amount, false)


func restore(amount: float) -> Dictionary:
	return _change(amount, true)


# The resolver authorizes the effect; LaneField confirms successful service.
func apply_served_dish(resolution: Dictionary, service: Dictionary) -> Dictionary:
	if (
		not resolution.get("ok", false)
		or not resolution.get("special_effect_triggered", false)
		or resolution.get("special_effect", "") != "reputation_small_restore"
		or not service.get("ok", false)
		or not service.get("target_found", false)
		or service.get("served", {}).is_empty()
	):
		return _result(current, false, "NO_RESTORE_EFFECT")
	return restore(float(resolution.get("special_effect_params", {}).get("amount", 0.0)))


func _change(amount: float, restoring: bool) -> Dictionary:
	if not is_finite(amount) or amount <= 0.0:
		return _result(current, false, "INVALID_AMOUNT")
	if defeated:
		return _result(current, false, "RUN_ENDED")
	var before := current
	current = clampf(current + amount if restoring else current - amount, 0.0, maximum)
	var transitioned_to_defeat := current == 0.0
	defeated = transitioned_to_defeat
	var result := _result(before, transitioned_to_defeat)
	if current != before:
		reputation_changed.emit(result.duplicate(true))
	if transitioned_to_defeat:
		var ending := snapshot()
		ending["outcome"] = "defeat"
		ending["reason"] = "reputation_depleted"
		run_ended.emit(ending)
	return result


func _result(before: float, transitioned: bool, error: String = "") -> Dictionary:
	var result := snapshot()
	result.merge({
		"ok": error.is_empty(),
		"before": before,
		"delta": current - before,
		"transitioned_to_defeat": transitioned,
	})
	if not error.is_empty():
		result["error"] = error
	return result
