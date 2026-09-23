extends Control

signal boss_started(payload: Dictionary)
signal boss_phase_changed(payload: Dictionary)
signal boss_encounter_completed(payload: Dictionary)

const Registry = preload("res://scripts/content/content_registry.gd")
const Resolver = preload("res://scripts/recipes/recipe_resolver.gd")
const DEFAULT_RUN_SEED := 20260921

@onready var board_view: BoardView = %BoardView
@onready var lane_field: LaneField = %LaneField
@onready var wave_director: WaveDirector = %WaveDirector
@onready var upgrade_selector: UpgradeSelector = %UpgradeSelector

var recipe_resolver: RecipeResolver
var boss_runner: LaneRunner
var boss_has_started := false
var boss_encounter_active := false
var _boss_content: Dictionary = {}
var _normal_wave_ids: Dictionary = {}
var _completed_normal_waves: Dictionary = {}


func _ready() -> void:
	var content_result := Registry.new().load_and_validate()
	if not content_result.get("ok", false):
		push_error("LANE-02 temporary wiring could not load validated content")
		return
	recipe_resolver = Resolver.new(content_result["content"])
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
	wave_director.wave_completed.connect(_on_wave_completed)
	upgrade_selector.upgrade_selected.connect(_on_upgrade_selected)
	lane_field.monster_satisfied.connect(_on_boss_satisfied)
	lane_field.monster_reached_counter.connect(_on_boss_reached_counter)
	_boss_content = content_result["content"]["boss"].duplicate(true)
	for wave in content_result["content"]["waves"]:
		_normal_wave_ids[str(wave["id"])] = true
	print("La Última Taquería — BOSS-01 temporary wiring ready.")


# Temporary BoardView -> RecipeResolver -> LaneField bridge.
# A future GameSession implementation can replace this without moving rules into Main.
func _on_chain_completed(points: Array[Vector2i], ingredient_id: String) -> Dictionary:
	if recipe_resolver == null:
		return {"ok": false, "target_found": false}
	var resolution := recipe_resolver.resolve(ingredient_id, points.size())
	if not resolution.get("ok", false):
		return resolution
	return lane_field.resolve_dish(resolution)


# Temporary WaveDirector -> UpgradeSelector bridge.
# A future GameSession implementation can replace this without moving rules into Main.
func _on_wave_completed(payload: Dictionary) -> Dictionary:
	var wave_id := str(payload.get("wave_id", ""))
	if (
		_normal_wave_ids.has(wave_id)
		and wave_director.current_wave_id == wave_id
		and wave_director.state == WaveDirector.State.COMPLETED
	):
		_completed_normal_waves[wave_id] = true
	return upgrade_selector.receive_wave_completed(payload)


# Minimal fifth-selection bridge; the boss is not a WaveDirector wave.
func _on_upgrade_selected(payload: Dictionary) -> void:
	if boss_has_started or not payload.get("is_final_selection", false):
		return
	if not upgrade_selector.is_selection_complete():
		return
	if upgrade_selector.get_selection_count() != UpgradeSelector.MAX_SELECTIONS:
		return
	if _completed_normal_waves.size() != _normal_wave_ids.size():
		return
	boss_has_started = true
	boss_encounter_active = true
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
	boss_encounter_active = false
	boss_encounter_completed.emit({
		"monster_id": boss_runner.monster_state.monster_id,
		"spawn_sequence": boss_runner.monster_state.spawn_sequence,
		"lane": boss_runner.monster_state.lane,
		"satisfied": was_satisfied,
		"reputation_damage_on_breach": _boss_content["reputation_damage_on_breach"],
		"reputation_damage": 0 if was_satisfied else _boss_content["reputation_damage_on_breach"],
	})
