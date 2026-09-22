class_name UpgradeSelector
extends Node

signal upgrade_selected(payload: Dictionary)

enum State {
	IDLE,
	OFFER_READY,
	SELECTION_COMPLETE,
}

const MAX_SELECTIONS := 5
const OFFER_SIZE := 3

const NOT_CONFIGURED := "NOT_CONFIGURED"
const RUN_NOT_STARTED := "RUN_NOT_STARTED"
const RUN_ALREADY_STARTED := "RUN_ALREADY_STARTED"
const INVALID_CONTENT := "INVALID_CONTENT"
const INVALID_WAVE_COMPLETION := "INVALID_WAVE_COMPLETION"
const OFFER_ALREADY_PENDING := "OFFER_ALREADY_PENDING"
const DUPLICATE_WAVE_COMPLETION := "DUPLICATE_WAVE_COMPLETION"
const SELECTION_CYCLE_COMPLETE := "SELECTION_CYCLE_COMPLETE"
const INSUFFICIENT_ELIGIBLE_UPGRADES := "INSUFFICIENT_ELIGIBLE_UPGRADES"
const NO_ACTIVE_OFFER := "NO_ACTIVE_OFFER"
const UPGRADE_NOT_IN_OFFER := "UPGRADE_NOT_IN_OFFER"

var state := State.IDLE

var _configured := false
var _run_started := false
var _rng := RandomNumberGenerator.new()
var _upgrades_by_id: Dictionary = {}
var _canonical_ids: Array[String] = []
var _selected_upgrades: Array[Dictionary] = []
var _selected_ids: Dictionary = {}
var _blocked_ids: Dictionary = {}
var _completed_wave_ids: Dictionary = {}
var _current_offer: Array[Dictionary] = []
var _current_wave_id := ""
var _strong_defense_selected := false


func configure(validated_content: Dictionary) -> Dictionary:
	if _run_started:
		return _failure(RUN_ALREADY_STARTED, "cannot configure during an active run")
	var upgrades = validated_content.get("upgrades", null)
	if typeof(upgrades) != TYPE_ARRAY:
		return _failure(INVALID_CONTENT, "validated content must include an upgrades array")

	var next_index: Dictionary = {}
	var next_ids: Array[String] = []
	for upgrade in upgrades:
		if typeof(upgrade) != TYPE_DICTIONARY:
			return _failure(INVALID_CONTENT, "every upgrade must be an object")
		var upgrade_id = upgrade.get("id", null)
		if typeof(upgrade_id) != TYPE_STRING or upgrade_id.is_empty() or next_index.has(upgrade_id):
			return _failure(INVALID_CONTENT, "every upgrade must have a unique non-empty id")
		next_index[upgrade_id] = upgrade.duplicate(true)
		next_ids.append(upgrade_id)

	next_ids.sort()
	_upgrades_by_id = next_index
	_canonical_ids = next_ids
	_configured = true
	state = State.IDLE
	return {"ok": true, "upgrade_count": _canonical_ids.size()}


func start_run(seed: int) -> Dictionary:
	if not _configured:
		return _failure(NOT_CONFIGURED, "configure must be called before start_run")
	if _run_started and state != State.SELECTION_COMPLETE:
		return _failure(RUN_ALREADY_STARTED, "cannot replace an active run")
	_rng.seed = seed
	_selected_upgrades.clear()
	_selected_ids.clear()
	_blocked_ids.clear()
	_completed_wave_ids.clear()
	_current_offer.clear()
	_current_wave_id = ""
	_strong_defense_selected = false
	_run_started = true
	state = State.IDLE
	return {"ok": true, "seed": seed, "state": get_state_name()}


func receive_wave_completed(payload: Dictionary) -> Dictionary:
	if not _configured:
		return _failure(NOT_CONFIGURED, "configure must be called before receiving a wave completion")
	if not _run_started:
		return _failure(RUN_NOT_STARTED, "start_run must be called before receiving a wave completion")
	if state == State.SELECTION_COMPLETE:
		return _failure(SELECTION_CYCLE_COMPLETE, "all five upgrade selections are complete")
	if state == State.OFFER_READY:
		return _failure(OFFER_ALREADY_PENDING, "select the pending offer before completing another wave")

	var wave_id = payload.get("wave_id", null)
	if typeof(wave_id) != TYPE_STRING or wave_id.is_empty():
		return _failure(INVALID_WAVE_COMPLETION, "wave_completed payload must include a non-empty wave_id")
	if _completed_wave_ids.has(wave_id):
		return _failure(DUPLICATE_WAVE_COMPLETION, "wave completion was already consumed: %s" % wave_id)

	var eligible_ids := get_eligible_upgrade_ids()
	if eligible_ids.size() < OFFER_SIZE:
		return _failure(
			INSUFFICIENT_ELIGIBLE_UPGRADES,
			"need %d eligible upgrades, found %d" % [OFFER_SIZE, eligible_ids.size()]
		)

	var pool := eligible_ids.duplicate()
	var offer: Array[Dictionary] = []
	for _option_index in range(OFFER_SIZE):
		var pool_index := _rng.randi_range(0, pool.size() - 1)
		var upgrade_id: String = pool.pop_at(pool_index)
		offer.append(_upgrades_by_id[upgrade_id].duplicate(true))

	_current_offer = offer
	_current_wave_id = wave_id
	_completed_wave_ids[wave_id] = true
	state = State.OFFER_READY
	return {
		"ok": true,
		"wave_id": wave_id,
		"offer": get_current_offer(),
		"state": get_state_name(),
	}


func select_upgrade(upgrade_id: String) -> Dictionary:
	if not _configured:
		return _failure(NOT_CONFIGURED, "configure must be called before selecting an upgrade")
	if not _run_started:
		return _failure(RUN_NOT_STARTED, "start_run must be called before selecting an upgrade")
	if state != State.OFFER_READY:
		return _failure(NO_ACTIVE_OFFER, "there is no active upgrade offer")

	var selected: Dictionary = {}
	for upgrade in _current_offer:
		if upgrade["id"] == upgrade_id:
			selected = upgrade.duplicate(true)
			break
	if selected.is_empty():
		return _failure(UPGRADE_NOT_IN_OFFER, "upgrade is not present in the current offer: %s" % upgrade_id)

	_selected_upgrades.append(selected.duplicate(true))
	_selected_ids[upgrade_id] = true
	for conflict_id in selected.get("conflicts", []):
		_blocked_ids[str(conflict_id)] = true
	if "strong_defense" in selected.get("tags", []):
		_strong_defense_selected = true

	var selection_number := _selected_upgrades.size()
	var is_final := selection_number == MAX_SELECTIONS
	var selection_payload := {
		"upgrade_id": upgrade_id,
		"selection_number": selection_number,
		"wave_id": _current_wave_id,
		"rarity": selected["rarity"],
		"tags": selected["tags"].duplicate(true),
		"effect": selected["effect"].duplicate(true),
		"conflicts": selected.get("conflicts", []).duplicate(true),
		"synergies": selected.get("synergies", []).duplicate(true),
		"is_final_selection": is_final,
	}

	_current_offer.clear()
	_current_wave_id = ""
	state = State.SELECTION_COMPLETE if is_final else State.IDLE
	upgrade_selected.emit(selection_payload.duplicate(true))
	return {
		"ok": true,
		"selection": selection_payload.duplicate(true),
		"state": get_state_name(),
	}


func get_current_offer() -> Array[Dictionary]:
	return _current_offer.duplicate(true)


func get_selected_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for upgrade in _selected_upgrades:
		result.append(str(upgrade["id"]))
	return result


func get_selected_upgrades() -> Array[Dictionary]:
	return _selected_upgrades.duplicate(true)


func get_active_effects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade in _selected_upgrades:
		result.append({
			"upgrade_id": str(upgrade["id"]),
			"effect": upgrade["effect"].duplicate(true),
		})
	return result


func get_selection_count() -> int:
	return _selected_upgrades.size()


func is_selection_complete() -> bool:
	return state == State.SELECTION_COMPLETE


func get_eligible_upgrade_ids() -> Array[String]:
	var result: Array[String] = []
	for upgrade_id in _canonical_ids:
		if _selected_ids.has(upgrade_id) or _blocked_ids.has(upgrade_id):
			continue
		var upgrade: Dictionary = _upgrades_by_id[upgrade_id]
		if _strong_defense_selected and "strong_defense" in upgrade.get("tags", []):
			continue
		result.append(upgrade_id)
	return result


func get_state_name() -> String:
	return State.keys()[state]


func _failure(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error_code,
		"message": message,
		"state": get_state_name(),
	}
