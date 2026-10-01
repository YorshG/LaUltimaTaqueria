extends Control

signal boss_started(payload: Dictionary)
signal boss_phase_changed(payload: Dictionary)
signal boss_encounter_completed(payload: Dictionary)
signal run_ended(payload: Dictionary)

const Registry = preload("res://scripts/content/content_registry.gd")
const Resolver = preload("res://scripts/recipes/recipe_resolver.gd")
const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
const Reputation = preload("res://scripts/session/reputation_state.gd")
const Feedback = preload("res://scripts/ui/feedback_coordinator.gd")
const DEFAULT_RUN_SEED := 20260921

@onready var board_view: BoardView = %BoardView
@onready var lane_field: LaneField = %LaneField
@onready var wave_director: WaveDirector = %WaveDirector
@onready var upgrade_selector: UpgradeSelector = %UpgradeSelector
@onready var hud: VBoxContainer = %Hud
@onready var feedback_layer: VBoxContainer = %FeedbackLayer
@onready var feedback_audio: AudioStreamPlayer = %FeedbackAudio

var recipe_resolver: RecipeResolver
var reputation: ReputationState
var feedback: FeedbackCoordinator
var boss_runner: LaneRunner
var boss_has_started := false
var boss_encounter_active := false
var _boss_content: Dictionary = {}
var _normal_wave_ids: Dictionary = {}
var _completed_normal_waves: Dictionary = {}
var _breach_results_by_sequence: Dictionary = {}
var _encounter_token := 0
var _first_dish_pending := false


func _ready() -> void:
	var content_result := Registry.new().load_and_validate()
	if not content_result.get("ok", false):
		push_error("LANE-02 temporary wiring could not load validated content")
		return
	recipe_resolver = Resolver.new(content_result["content"])
	reputation = Reputation.new(content_result["content"])
	reputation.reputation_changed.connect(hud.show_reputation)
	reputation.maximum_changed.connect(hud.show_reputation)
	reputation.run_ended.connect(_on_reputation_run_ended)
	hud.show_reputation(reputation.snapshot())
	_wire_feedback(content_result["content"]["localization"])
	# Apply breach before WaveDirector can synchronously offer the next upgrade.
	lane_field.monster_reached_counter.connect(_on_monster_reached_counter)
	var wave_result := wave_director.configure(content_result["content"], lane_field)
	if not wave_result.get("ok", false):
		push_error("WAV-01 temporary wiring could not configure WaveDirector")
		return
	var upgrade_result := upgrade_selector.configure(content_result["content"])
	if not upgrade_result.get("ok", false):
		push_error("UPG-01 temporary wiring could not configure UpgradeSelector")
		return
	var run_result := upgrade_selector.start_run(DEFAULT_RUN_SEED)
	if not run_result.get("ok", false):
		push_error("UPG-01 temporary wiring could not start UpgradeSelector run")
		return
	board_view.chain_completed.connect(_on_chain_completed)
	wave_director.monster_spawned.connect(_on_wave_monster_spawned)
	wave_director.wave_completed.connect(_on_wave_completed)
	upgrade_selector.upgrade_selected.connect(_on_upgrade_selected)
	lane_field.monster_satisfied.connect(_on_boss_satisfied)
	lane_field.monster_reached_counter.connect(_on_boss_reached_counter)
	_boss_content = content_result["content"]["boss"].duplicate(true)
	for wave in content_result["content"]["waves"]:
		_normal_wave_ids[str(wave["id"])] = true
	print("La Última Taquería — BOSS-01 temporary wiring ready.")


func _wire_feedback(localization: Dictionary) -> void:
	feedback = Feedback.new(reputation.snapshot())
	feedback_layer.configure(localization)
	feedback.feedback_requested.connect(feedback_layer.present)
	feedback.feedback_requested.connect(feedback_audio.request)
	# Observe before synchronous gameplay callbacks so final cues arrive last.
	board_view.chain_started.connect(feedback.on_chain_started)
	board_view.chain_changed.connect(feedback.on_chain_changed)
	board_view.chain_completed.connect(feedback.on_chain_completed)
	board_view.chain_cancelled.connect(feedback.on_chain_cancelled)
	lane_field.dish_created.connect(feedback.on_dish_created)
	lane_field.dish_served.connect(feedback.on_dish_served)
	lane_field.monster_satisfied.connect(feedback.on_monster_satisfied)
	lane_field.monster_reached_counter.connect(feedback.on_breach)
	reputation.reputation_changed.connect(feedback.on_reputation_changed)
	reputation.maximum_changed.connect(feedback.on_reputation_maximum_changed)
	reputation.shield_consumed.connect(feedback.on_shield_consumed)
	upgrade_selector.upgrade_selected.connect(feedback.on_upgrade_selected)
	boss_phase_changed.connect(feedback.on_boss_phase_changed)
	boss_encounter_completed.connect(feedback.on_boss_completed)
	run_ended.connect(feedback.on_run_ended)


# Temporary BoardView -> RecipeResolver -> LaneField bridge.
# A future GameSession implementation can replace this without moving rules into Main.
func _on_chain_completed(points: Array[Vector2i], ingredient_id: String) -> Dictionary:
	if recipe_resolver == null or reputation.defeated:
		return {"ok": false, "target_found": false}
	var derived := Modifiers.derive(upgrade_selector.get_active_effects())
	if not derived.get("ok", false):
		return derived
	var effective: Dictionary = derived["modifiers"].duplicate(true)
	for conditional in derived["conditional_multipliers"]:
		var params: Dictionary = conditional["params"]
		var applies := false
		match params["condition"]:
			"first_dish_of_encounter":
				applies = _first_dish_pending
			"reputation_below_ratio":
				applies = reputation.maximum > 0.0 and reputation.current / reputation.maximum < float(params["threshold"])
		if applies:
			effective["satisfaction_multiplier"] *= float(conditional["value"])
	var resolution := recipe_resolver.resolve(ingredient_id, points.size(), effective)
	if not resolution.get("ok", false):
		return resolution
	# Resolution can synchronously finish a wave and start the next encounter.
	var serving_encounter := _encounter_token
	var service := lane_field.resolve_dish(resolution)
	if (
		serving_encounter == _encounter_token
		and service.get("ok", false)
		and service.get("target_found", false)
		and not service.get("served", {}).is_empty()
	):
		_first_dish_pending = false
	reputation.apply_served_dish(resolution, service)
	return service


func _begin_encounter() -> void:
	_encounter_token += 1
	# Track successful service even before warm_welcome is selected.
	_first_dish_pending = true


func _on_wave_monster_spawned(_payload: Dictionary) -> void:
	# Count resets on every run, including a repeated wave_id.
	if wave_director.get_spawned_count() == 1:
		_begin_encounter()


func _on_monster_reached_counter(payload: Dictionary) -> void:
	var result := reputation.apply_breach(payload)
	var sequence := int(payload.get("spawn_sequence", -1))
	if result.get("ok", false) and not _breach_results_by_sequence.has(sequence):
		_breach_results_by_sequence[sequence] = result.duplicate(true)


func _on_reputation_run_ended(payload: Dictionary) -> void:
	# Terminal stop only; no pause/resume or navigation system.
	process_mode = Node.PROCESS_MODE_DISABLED
	run_ended.emit(payload.duplicate(true))


# Temporary WaveDirector -> UpgradeSelector bridge.
# A future GameSession implementation can replace this without moving rules into Main.
func _on_wave_completed(payload: Dictionary) -> Dictionary:
	if reputation.defeated:
		return {"ok": false, "error": "RUN_ENDED"}
	var wave_id := str(payload.get("wave_id", ""))
	if (
		_normal_wave_ids.has(wave_id)
		and wave_director.current_wave_id == wave_id
		and wave_director.state == WaveDirector.State.COMPLETED
	):
		_completed_normal_waves[wave_id] = true
	return upgrade_selector.receive_wave_completed(payload)


# Refresh every selection before the fifth-selection bridge can spawn the boss.
func _on_upgrade_selected(payload: Dictionary) -> Dictionary:
	var derived := Modifiers.derive(upgrade_selector.get_active_effects())
	if not derived.get("ok", false):
		return derived
	if not lane_field.set_global_speed_multiplier(derived["modifiers"]["monster_speed_global"]):
		return {"ok": false, "error": "INVALID_GLOBAL_SPEED"}
	if not reputation.set_reputation_damage_multiplier(derived["modifiers"]["reputation_damage_taken"]):
		return {"ok": false, "error": "INVALID_REPUTATION_DAMAGE_MULTIPLIER"}
	var selected := upgrade_selector.get_selected_upgrades()
	var selection_number = payload.get("selection_number", null)
	if typeof(selection_number) != TYPE_INT or selection_number < 1 or selection_number > selected.size():
		return {"ok": false, "error": "INVALID_SELECTION"}
	var actual_upgrade: Dictionary = selected[selection_number - 1]
	if actual_upgrade["id"] != payload.get("upgrade_id", ""):
		return {"ok": false, "error": "SELECTION_ID_MISMATCH"}
	var effect: Dictionary = actual_upgrade["effect"]
	if effect["stat"] in ["reputation_max", "reputation_shield_charges", "extra_life_charges"]:
		var applied := reputation.apply_selection_effect(selection_number, actual_upgrade["id"], effect)
		if not applied["ok"]:
			return applied
	if reputation.defeated:
		return {"ok": false, "error": "RUN_ENDED"}
	if boss_has_started or not payload.get("is_final_selection", false):
		return {"ok": true}
	if not upgrade_selector.is_selection_complete():
		return {"ok": true}
	if upgrade_selector.get_selection_count() != UpgradeSelector.MAX_SELECTIONS:
		return {"ok": true}
	if _completed_normal_waves.size() != _normal_wave_ids.size():
		return {"ok": true}
	boss_has_started = true
	boss_encounter_active = true
	_begin_encounter()
	boss_runner = lane_field.spawn_runner(
		int(_boss_content["lane"]),
		float(_boss_content["speed"]),
		"B",
		str(_boss_content["id"]),
		float(_boss_content["hunger"])
	)
	boss_runner.monster_state.phase_changed.connect(_on_boss_phase_changed)
	boss_runner.monster_state.configure_phases(_boss_content["phases"])
	boss_started.emit({
		"monster_id": boss_runner.monster_state.monster_id,
		"spawn_sequence": boss_runner.monster_state.spawn_sequence,
		"lane": boss_runner.monster_state.lane,
	})
	return {"ok": true}


func _on_boss_phase_changed(phase: Dictionary) -> void:
	boss_runner.set_phase_multiplier(float(phase["speed_multiplier"]))
	# behavior_tag is a cue only; it does not introduce additional mechanics.
	boss_phase_changed.emit(phase.duplicate(true))


func _on_boss_satisfied(payload: Dictionary) -> void:
	_complete_boss_encounter(payload, true)


func _on_boss_reached_counter(payload: Dictionary) -> void:
	_complete_boss_encounter(payload, false)


func _complete_boss_encounter(payload: Dictionary, was_satisfied: bool) -> void:
	if not boss_encounter_active:
		return
	if int(payload.get("spawn_sequence", -1)) != boss_runner.monster_state.spawn_sequence:
		return
	var breach_result: Dictionary = _breach_results_by_sequence.get(boss_runner.monster_state.spawn_sequence, {})
	if not was_satisfied and breach_result.is_empty():
		return
	boss_encounter_active = false
	if was_satisfied and not reputation.defeated:
		hud.show_outcome("victory")
	boss_encounter_completed.emit({
		"monster_id": boss_runner.monster_state.monster_id,
		"spawn_sequence": boss_runner.monster_state.spawn_sequence,
		"lane": boss_runner.monster_state.lane,
		"satisfied": was_satisfied,
		"reputation_damage_on_breach": _boss_content["reputation_damage_on_breach"],
		"reputation_damage": 0.0 if was_satisfied else breach_result["damage_applied"],
	})
