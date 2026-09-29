class_name ReputationState
extends RefCounted

signal reputation_changed(payload: Dictionary)
signal maximum_changed(payload: Dictionary)
signal shield_consumed(payload: Dictionary)
signal run_ended(payload: Dictionary)

const INITIAL_REPUTATION := 100.0

var current := INITIAL_REPUTATION
var maximum := INITIAL_REPUTATION
var defeated := false
var shield_charges := 0
var _breach_damage_by_id: Dictionary = {}
var _processed_breaches: Dictionary = {}
var _applied_selections: Dictionary = {}


# One instance per run. Content must have passed ContentRegistry validation.
func _init(validated_content: Dictionary = {}) -> void:
	for monster in validated_content.get("monsters", []):
		_breach_damage_by_id[str(monster["id"])] = float(monster["reputation_damage"])
	var boss: Dictionary = validated_content.get("boss", {})
	if not boss.is_empty():
		_breach_damage_by_id[str(boss["id"])] = float(boss["reputation_damage_on_breach"])


func snapshot() -> Dictionary:
	return {"current": current, "maximum": maximum, "defeated": defeated, "shield_charges": shield_charges}


# Variant effect lets the defensive API reject malformed input explicitly.
func apply_selection_effect(selection_number: int, upgrade_id: String, effect) -> Dictionary:
	if selection_number < 1:
		return _result(current, false, "INVALID_SELECTION_NUMBER")
	if upgrade_id.strip_edges().is_empty():
		return _result(current, false, "INVALID_UPGRADE_ID")
	if typeof(effect) != TYPE_DICTIONARY:
		return _result(current, false, "INVALID_EFFECT")
	if defeated:
		return _result(current, false, "RUN_ENDED")
	var stat = effect.get("stat", "")
	if stat not in ["reputation_max", "reputation_shield_charges"]:
		return _result(current, false, "NOT_ONE_SHOT")
	var expected_type := "modify_reputation" if stat == "reputation_max" else "grant_charge"
	if effect.get("operation", "") != "add" or effect.get("type", expected_type) != expected_type:
		return _result(current, false, "INVALID_EFFECT")
	var value = effect.get("value", null)
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) <= 0.0:
		return _result(current, false, "INVALID_AMOUNT")
	if stat == "reputation_max":
		if not is_finite(maximum + float(value)) or maximum + float(value) == maximum:
			return _result(current, false, "INVALID_AMOUNT")
	else:
		# Check representability before converting or adding to the int64 counter.
		if typeof(value) == TYPE_FLOAT and (value != floorf(value) or value >= 9223372036854775808.0):
			return _result(current, false, "INVALID_AMOUNT")
		if shield_charges > 9223372036854775807 - int(value):
			return _result(current, false, "INVALID_AMOUNT")
	if _applied_selections.has(selection_number):
		return _result(current, false, "DUPLICATE_SELECTION")
	# All validation precedes marking; mark before any reentrant signal listener.
	_applied_selections[selection_number] = upgrade_id
	var before_maximum := maximum
	if stat == "reputation_max":
		maximum += float(value)
	else:
		shield_charges += int(value)
	var result := _result(current, false)
	result.merge({"selection_number": selection_number, "upgrade_id": upgrade_id,
		"before_maximum": before_maximum, "delta_maximum": maximum - before_maximum})
	if maximum != before_maximum:
		maximum_changed.emit(result.duplicate(true))
	return result


func apply_breach(payload: Dictionary) -> Dictionary:
	var sequence := int(payload.get("spawn_sequence", -1))
	var monster_id := str(payload.get("monster_id", ""))
	var raw_damage := float(_breach_damage_by_id.get(monster_id, 0.0))
	if sequence < 0 or not _breach_damage_by_id.has(monster_id):
		return _breach_result(_result(current, false, "UNKNOWN_BREACH"), raw_damage)
	if _processed_breaches.has(sequence):
		return _breach_result(_result(current, false, "DUPLICATE_BREACH"), raw_damage)
	# Mark before emitting signals, including reentrant duplicate callbacks.
	_processed_breaches[sequence] = true
	if defeated:
		return _breach_result(_result(current, false, "RUN_ENDED"), raw_damage)
	if raw_damage == 0.0:
		return _breach_result(_result(current, false), raw_damage)
	# D6: dedupe -> shield -> damage multiplier -> reputation change -> second_chance.
	if shield_charges > 0:
		shield_charges -= 1
		var blocked := _breach_result(_result(current, false), raw_damage, true)
		blocked.merge({"spawn_sequence": sequence, "monster_id": monster_id,
			"shield_charges_remaining": shield_charges})
		shield_consumed.emit(blocked.duplicate(true))
		return blocked
	# UPG-02e will apply damage multipliers here, before the reputation change.
	# Its atomic second_chance belongs inside that change, before terminal signals.
	return _breach_result(apply_damage(raw_damage), raw_damage)


func _breach_result(result: Dictionary, raw_damage: float, blocked: bool = false) -> Dictionary:
	result.merge({"damage_requested": raw_damage, "damage_applied": -float(result["delta"]),
		"shield_consumed": blocked, "prevented_damage": raw_damage if blocked else 0.0})
	return result


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
