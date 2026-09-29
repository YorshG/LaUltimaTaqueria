class_name UpgradeModifiers
extends RefCounted

# Only the frozen schema constants are used; no content loading or runtime state.
const Registry = preload("res://scripts/content/content_registry.gd")
const INVALID_ACTIVE_EFFECTS := "INVALID_ACTIVE_EFFECTS"
const NEUTRAL_MODIFIERS := {
	"satisfaction_flat_bonus": 0.0,
	"chain4_satisfaction_bonus": 0.0,
	"satisfaction_multiplier": 1.0,
	"special_effect_power_multiplier": 1.0,
	"chain4_splash_satisfaction": 0.0,
	"monster_speed_global": 1.0,
	"input_forgiveness": 0.0,
	"reputation_damage_taken": 1.0,
}
const ONE_SHOT_STATS := ["reputation_max", "reputation_shield_charges", "extra_life_charges"]


# Input is the snapshot returned by UpgradeSelector.get_active_effects().
# Success owns fresh dictionaries/arrays; failure exposes no partial modifiers.
# Selection eligibility and conditional evaluation belong to other modules.
static func derive(active_effects: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for entry in active_effects:
		if typeof(entry) != TYPE_DICTIONARY:
			return _failure("every active effect must be an object")
		var upgrade_id = entry.get("upgrade_id", null)
		if typeof(upgrade_id) != TYPE_STRING or upgrade_id.is_empty():
			return _failure("every active effect must have a non-empty upgrade_id")
		if by_id.has(upgrade_id):
			return _failure("duplicate upgrade_id: %s" % upgrade_id)
		by_id[upgrade_id] = entry.get("effect", null)

	var ids := by_id.keys()
	ids.sort()
	var modifiers := NEUTRAL_MODIFIERS.duplicate(true)
	var conditional_multipliers: Array[Dictionary] = []
	for upgrade_id in ids:
		var message := _validate_effect(by_id[upgrade_id])
		if not message.is_empty():
			return _failure("upgrade %s: %s" % [upgrade_id, message])
		var effect: Dictionary = by_id[upgrade_id]
		var stat: String = effect["stat"]
		if stat in ONE_SHOT_STATS:
			# Applied in a later PR through selection_number, never through snapshots.
			continue
		if effect["type"] == "conditional_satisfaction":
			var params := {"condition": effect["params"]["condition"]}
			if params["condition"] == "reputation_below_ratio":
				# Preserve the threshold; do not evaluate or conflate it with UI's <=.
				params["threshold"] = float(effect["params"]["threshold"])
			conditional_multipliers.append({
				"upgrade_id": upgrade_id,
				"stat": stat,
				"operation": effect["operation"],
				"value": float(effect["value"]),
				"params": params,
			})
			continue
		if not modifiers.has(stat):
			return _failure("unsupported continuous stat: %s" % stat)
		if effect["operation"] == "add":
			modifiers[stat] += float(effect["value"])
		else:
			modifiers[stat] *= float(effect["value"])
		if not _is_finite_number(modifiers[stat]):
			return _failure("aggregate must remain finite: %s" % stat)

	return {"ok": true, "modifiers": modifiers, "conditional_multipliers": conditional_multipliers}


static func _validate_effect(effect) -> String:
	if typeof(effect) != TYPE_DICTIONARY:
		return "effect must be an object"
	var effect_type = effect.get("type", null)
	if not Registry.EFFECT_RULES.has(effect_type):
		return "unsupported effect.type"
	var stat = effect.get("stat", null)
	var operation = effect.get("operation", null)
	if [stat, operation] not in Registry.EFFECT_RULES[effect_type]["pairs"]:
		return "invalid stat/operation for effect.type"
	if not _is_finite_number(effect.get("value", null)):
		return "effect.value must be finite"
	var params = effect.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		return "effect.params must be an object"
	if effect_type == "conditional_satisfaction":
		var condition = params.get("condition", null)
		if condition not in Registry.CONDITIONS:
			return "unsupported condition"
		if condition == "reputation_below_ratio":
			if not _is_ratio(params.get("threshold", null)):
				return "threshold must be in [0, 1]"
		elif params.has("threshold"):
			return "threshold is only valid with reputation_below_ratio"
	elif effect_type == "grant_charge":
		if stat == "extra_life_charges":
			if not _is_ratio(params.get("restore_ratio", null)):
				return "restore_ratio must be in [0, 1]"
		elif params.has("restore_ratio"):
			return "restore_ratio is only valid for extra_life_charges"
	elif not params.is_empty():
		return "effect.params is not allowed for this effect.type"
	return ""


static func _is_finite_number(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _is_ratio(value) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0 and float(value) <= 1.0


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": INVALID_ACTIVE_EFFECTS, "message": message}
