extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const MAIN_SCENE = preload("res://scenes/Main.tscn")

var failures := 0
var content: Dictionary


func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "BOSS-01 must use validated content")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	await _test_selection_requires_completed_waves()
	await _test_full_encounter()
	await _test_breach()
	_test_phase_jumps_and_no_regression()
	if failures == 0:
		print("BOSS-01 tests passed: fifth selection, one boss, phases, satisfaction, breach, no Wave 6.")
		quit(0)
	else:
		push_error("BOSS-01 tests failed: %d" % failures)
		quit(1)


func _create_main():
	var main = MAIN_SCENE.instantiate()
	get_root().add_child(main)
	await process_frame
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(payload: Dictionary):
		main.wave_director.get_spawned_runner(int(payload["spawn_sequence"])).auto_advance = false
	)
	main.boss_started.connect(func(_payload: Dictionary): main.boss_runner.auto_advance = false)
	return main


func _test_selection_requires_completed_waves() -> void:
	var main = await _create_main()
	main.upgrade_selector.upgrade_selected.emit({"is_final_selection": true})
	_expect(not main.boss_has_started, "a final-selection signal alone must not start boss")
	# A selector can accept arbitrary completion payloads; Main requires real resolved waves.
	for wave in content["waves"]:
		main.wave_director.wave_completed.emit({"wave_id": wave["id"]})
		_choose_first(main)
	_expect(main.upgrade_selector.is_selection_complete(), "fixture must complete five selections")
	_expect(not main.boss_has_started, "five choices without actual completed waves must not start boss")
	main.queue_free()
	await process_frame


func _finish_five_waves_and_select(main) -> Dictionary:
	var final_selection: Dictionary = {}
	for wave in content["waves"]:
		_expect(not main.boss_has_started, "boss must not exist before normal waves finish")
		_expect(main.wave_director.start_wave(str(wave["id"]), 0.0)["ok"], "normal wave must start")
		main.wave_director.advance(1000.0)
		_expect(main.wave_director.state == WaveDirector.State.AWAITING_RESOLUTION, "wave must await all monsters")
		_expect(not main.boss_has_started, "boss must not start while a normal wave remains unresolved")
		for _spawn in wave["spawns"]:
			_expect(main.lane_field.resolve_dish(_dish(1000.0))["ok"], "normal monster must resolve")
		_expect(main.wave_director.state == WaveDirector.State.COMPLETED, "normal wave must complete")
		_expect(not main.boss_has_started, "wave completion including Wave 5 must not start boss before choice")
		var result := _choose_first(main)
		final_selection = result.get("selection", {})
		if main.upgrade_selector.get_selection_count() < 5:
			_expect(not main.boss_has_started, "first four selections must not start boss")
	_expect(main.boss_has_started and main.boss_encounter_active, "fifth selection must synchronously start boss")
	return final_selection


func _test_full_encounter() -> void:
	var main = await _create_main()
	var starts: Array[Dictionary] = []
	var phases: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	var waves: Array[Dictionary] = []
	main.boss_started.connect(func(payload: Dictionary): starts.append(payload))
	main.boss_phase_changed.connect(func(payload: Dictionary): phases.append(payload))
	main.boss_encounter_completed.connect(func(payload: Dictionary): completions.append(payload))
	main.wave_director.wave_completed.connect(func(payload: Dictionary): waves.append(payload))
	var final_selection := _finish_five_waves_and_select(main)
	var boss: LaneRunner = main.boss_runner
	var state := boss.monster_state
	_expect(starts.size() == 1, "boss must start exactly once")
	_expect(state.monster_id == "boss_big_glutton", "boss id must match contract")
	_expect(state.lane == 1 and boss.get_parent() == main.lane_field.get_lane_host(1), "boss must spawn in lane 1")
	_expect(state.hunger_max == 300.0 and state.hunger_remaining == 300.0, "boss must start with hunger 300")
	_expect(boss.motion.speed_relative == float(content["boss"]["speed"]), "boss speed must come from content")
	_expect(boss.motion.phase_multiplier == 1.0, "boss must start with phase multiplier 1.0")
	_expect(state.get_current_phase()["behavior_tag"] == "calm", "initial cue must be calm")
	_expect(is_equal_approx(boss.effective_speed(), 0.025), "boss must use existing movement formula")
	boss.advance(2.0)
	_expect(is_equal_approx(boss.motion.progress, 0.05), "boss must advance using existing lane motion")
	main.upgrade_selector.upgrade_selected.emit(final_selection)
	_expect(starts.size() == 1 and main.boss_runner == boss, "duplicate fifth selection must not respawn boss")

	main.lane_field.resolve_dish(_dish(119.0))
	_expect(state.phase_index == 0, "181 hunger must remain calm")
	main.lane_field.resolve_dish(_dish(1.0))
	_expect(state.hunger_remaining == 180.0 and state.phase_index == 1, "exact 60 percent boundary must enter phase 2")
	_expect(boss.motion.phase_multiplier == 1.25, "phase 2 must apply multiplier 1.25 immediately")
	_expect(state.get_current_phase()["behavior_tag"] == "phase2_transition_cue_cosmetic_only", "phase 2 tag must remain metadata")
	_expect(is_equal_approx(boss.effective_speed(), 0.03125), "phase 2 must use existing movement formula")
	main.lane_field.resolve_dish(_dish(89.0))
	_expect(state.phase_index == 1, "91 hunger must remain phase 2")
	main.lane_field.resolve_dish(_dish(1.0))
	_expect(state.hunger_remaining == 90.0 and state.phase_index == 2, "exact 30 percent boundary must enter phase 3")
	_expect(boss.motion.phase_multiplier == 1.4, "phase 3 must apply multiplier 1.4 immediately")
	_expect(state.get_current_phase()["behavior_tag"] == "final_bite", "final bite must remain metadata")
	boss.set_global_speed_multiplier(0.8)
	_expect(is_equal_approx(boss.effective_speed(), 0.028), "existing global multiplier must also affect boss")
	_expect(boss.motion.stun_remaining_sec == 0.0, "phase tags must not add stun or other mechanics")
	_expect(phases == content["boss"]["phases"], "phase cues must be emitted once in content order")

	# Finish through the real BoardView -> RecipeResolver -> LaneField bridge.
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	for _dish_index in range(30):
		if state.satisfied:
			break
		main.board_view.chain_completed.emit(points, "tortilla")
	_expect(state.hunger_remaining == 0.0 and state.satisfied and not state.active, "boss must retire satisfied at zero hunger")
	_expect(not boss.is_targetable(), "satisfied boss must leave targeting")
	_expect(not main.boss_encounter_active and completions.size() == 1, "satisfaction must end encounter once")
	if completions.size() == 1:
		_expect(completions[0]["satisfied"] and completions[0]["reputation_damage"] == 0, "satisfaction must report zero damage")
	var progress_at_end := boss.motion.progress
	boss.advance(1000.0)
	_expect(boss.motion.progress == progress_at_end, "resolved boss must stop moving")
	main.lane_field.monster_satisfied.emit(starts[0])
	main.upgrade_selector.upgrade_selected.emit(final_selection)
	_expect(completions.size() == 1 and starts.size() == 1, "duplicate terminal events must not end or start again")
	_expect(waves.size() == 5, "boss resolution must not emit a sixth wave completion")
	_expect(main.wave_director.current_wave_id == "wave_05", "boss must not replace current wave with Wave 6")
	_expect(main.wave_director.get_spawned_count() == 7, "boss must not be counted as a Wave 5 spawn")
	_expect(not main.wave_director.has_wave("wave_06"), "Wave 6 must not exist")
	_expect(not main.wave_director.start_wave("wave_06", 0.0)["ok"], "Wave 6 must remain unavailable")
	main.queue_free()
	await process_frame


func _test_breach() -> void:
	var main = await _create_main()
	var final_selection := _finish_five_waves_and_select(main)
	var completions: Array[Dictionary] = []
	main.boss_encounter_completed.connect(func(payload: Dictionary): completions.append(payload))
	main.lane_field.monster_reached_counter.emit({"spawn_sequence": -1})
	_expect(main.boss_encounter_active, "unrelated resolution must not end boss encounter")
	var boss: LaneRunner = main.boss_runner
	boss.advance(1000.0)
	_expect(not boss.monster_state.active and not boss.monster_state.satisfied, "breach must retire boss unsatisfied")
	_expect(not boss.is_targetable() and not main.boss_encounter_active, "breach must end encounter and targeting")
	_expect(completions.size() == 1, "breach must emit one completion")
	if completions.size() == 1:
		_expect(not completions[0]["satisfied"], "breach outcome must be unsatisfied")
		_expect(completions[0]["reputation_damage_on_breach"] == 40, "breach contract must preserve damage 40")
		_expect(completions[0]["reputation_damage"] == content["boss"]["reputation_damage_on_breach"], "damage must come from content")
	boss.advance(1000.0)
	main.upgrade_selector.upgrade_selected.emit(final_selection)
	_expect(completions.size() == 1 and not main.boss_encounter_active, "breached encounter must not restart or resolve twice")
	main.queue_free()
	await process_frame


func _test_phase_jumps_and_no_regression() -> void:
	var state := MonsterState.new("boss_big_glutton", 1, 300.0, 0)
	state.configure_phases(content["boss"]["phases"])
	state.apply_satisfaction(220.0)
	_expect(state.phase_index == 2, "one dish may cross both thresholds")
	# Even if remaining hunger is restored externally, a phase must never regress.
	state.hunger_remaining = 300.0
	state.apply_satisfaction(1.0)
	state.configure_phases(content["boss"]["phases"])
	_expect(state.phase_index == 2, "hunger restoration and reconfiguration must not regress phases")
	state.apply_satisfaction(1000.0)
	_expect(state.satisfied and state.phase_index == 2, "oversatisfaction must finish in final phase")
	var alternate := MonsterState.new("test_boss", 2, 100.0, 1)
	alternate.configure_phases([
		{"threshold": 1.0, "speed_multiplier": 0.9},
		{"threshold": 0.75, "speed_multiplier": 1.1},
	])
	alternate.apply_satisfaction(25.0)
	_expect(alternate.phase_index == 1 and alternate.get_current_phase()["speed_multiplier"] == 1.1, "phase logic must use supplied data, not hardcoded thresholds")


func _choose_first(main) -> Dictionary:
	var offer: Array = main.upgrade_selector.get_current_offer()
	_expect(offer.size() == 3, "completed wave must offer three upgrades")
	if offer.is_empty():
		return {}
	var result: Dictionary = main.upgrade_selector.select_upgrade(str(offer[0]["id"]))
	_expect(result["ok"], "deterministic first upgrade must be selectable")
	return result


func _dish(amount: float) -> Dictionary:
	return {"ok": true, "satisfaction_final": amount, "special_effect_triggered": false}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
