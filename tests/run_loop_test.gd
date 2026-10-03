extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")
const Registry = preload("res://scripts/content/content_registry.gd")
const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
var checks := 0
var failures := 0
var content: Dictionary


func _init() -> void:
	content = Registry.new().load_and_validate()["content"]
	await _test_configured_scene()
	await _test_countdown()
	await _test_reentrant_phase_selection()
	var first := await _test_complete_run(false)
	var second := await _test_complete_run(false)
	_expect(first == second, "same defaults and choices reproduce offers, upgrades and initial board")
	await _test_complete_run(true)
	await _test_defeat()
	if failures == 0:
		print("RUN-01 tests passed: %d checks; configured scene, 5 waves/choices, real UI, victory/breach/defeat, pause, duplicate guards, deterministic runs." % checks)
	else:
		push_error("RUN-01 tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _fixture(scene: PackedScene = MAIN, countdown: float = -1.0) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	root.add_child(viewport)
	var host = scene.instantiate()
	if countdown >= 0.0:
		host.wave_countdown_sec = countdown
	viewport.add_child(host)
	await process_frame
	var main = _find_main(host)
	_expect(main != null, "configured scene must own Main")
	if main != null:
		main.set_process(false)
		main.wave_director.auto_advance = false
		main.wave_director.monster_spawned.connect(func(payload: Dictionary):
			main.wave_director.get_spawned_runner(int(payload["spawn_sequence"])).auto_advance = false
		)
		main.boss_started.connect(func(_payload: Dictionary): main.boss_runner.auto_advance = false)
	return {"viewport": viewport, "main": main}


func _find_main(node: Node):
	# Compare the script resource, independent of Main's position in an App host.
	if node.get_script() != null and node.get_script().resource_path == "res://scripts/main.gd":
		return node
	for child in node.get_children():
		var found = _find_main(child)
		if found != null:
			return found
	return null


func _test_configured_scene() -> void:
	var configured: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	var fixture := await _fixture(configured)
	var main = fixture["main"]
	if main != null:
		_expect(main.auto_start_run, "configured scene must enable the playable loop by default")
		_expect(main.wave_director.current_wave_id == "wave_01", "launch must start wave_01 without an external start_wave call")
		_expect(main.wave_director.state == WaveDirector.State.RUNNING, "zero default countdown preserves the existing agenda")
		_expect(main.upgrade_selector.get_selection_count() == 0, "launch must not auto-select upgrades")
		_expect(not main.upgrade_choice.visible, "launch has no upgrade overlay")
		_expect(main._on_wave_completed({"wave_id": "wave_02"}).get("error") == "UNEXPECTED_WAVE_COMPLETION", "forged out-of-order completion must not produce an offer")
		main.wave_director.advance(2.0)
		_expect(main.wave_director.get_spawned_count() == 1, "actual wave agenda spawns first monster")
		_expect(main._first_dish_pending and main._encounter_token == 1, "D3 first spawn owns encounter boundary")
	fixture["viewport"].queue_free()
	await process_frame


func _test_countdown() -> void:
	var fixture := await _fixture(MAIN, 0.5)
	var main = fixture["main"]
	_expect(main.wave_director.state == WaveDirector.State.COUNTDOWN, "configured countdown remains supported")
	main.wave_director.advance(0.25)
	_expect(main.wave_director.get_spawned_count() == 0 and main.wave_director.state == WaveDirector.State.COUNTDOWN, "countdown advances without premature spawn")
	main.wave_director.advance(0.25)
	main._process(0.25)
	_expect(main.get_run_snapshot()["phase"] == "wave", "countdown hands off to wave")
	fixture["viewport"].queue_free()
	await process_frame


func _test_reentrant_phase_selection() -> void:
	var fixture := await _fixture()
	var main = fixture["main"]
	var transitions: Array = []
	main.run_phase_changed.connect(func(snapshot: Dictionary):
		transitions.append(snapshot["phase"])
		if snapshot["phase"] == "upgrade":
			_expect(main.upgrade_choice.visible and main.wave_director.paused, "reentrant observer sees fully presented and paused offer")
			var offer: Array = main.upgrade_selector.get_current_offer()
			_expect(main._on_upgrade_choice_requested(str(offer[0]["id"]))["ok"], "reentrant observer may choose the current offer synchronously")
		elif snapshot["phase"] == "wave":
			_expect(main.wave_director.current_wave_id == "wave_02" and main.wave_director.state == WaveDirector.State.RUNNING, "wave observer sees initialized next director, never completed predecessor")
	)
	main._process(2.0)
	_expect(main.get_run_snapshot()["logical_elapsed_sec"] >= 2.0, "gameplay clock records processing time")
	main.wave_director.advance(1000.0)
	for _spawn in content["waves"][0]["spawns"]:
		main.lane_field.resolve_dish(_dish())
	_expect(transitions == ["upgrade", "wave"], "reentrant selection publishes one completed transition per phase")
	_expect(main.wave_director.current_wave_id == "wave_02" and not main.upgrade_choice.visible, "returning from reentrant callback must not resurrect stale overlay")
	fixture["viewport"].queue_free()
	await process_frame


func _test_complete_run(breach: bool) -> Dictionary:
	var fixture := await _fixture()
	var main = fixture["main"]
	var viewport: SubViewport = fixture["viewport"]
	var initial_board: Array = main.board_view.get_ingredient_snapshot()
	var offers: Array = []
	var completions: Array = []
	var boss_starts: Array = []
	var boss_ends: Array = []
	main.wave_director.wave_completed.connect(func(p: Dictionary): completions.append(p["wave_id"]))
	main.boss_started.connect(func(p: Dictionary): boss_starts.append(p))
	main.boss_encounter_completed.connect(func(p: Dictionary): boss_ends.append(p))
	main.run_phase_changed.connect(func(snapshot: Dictionary):
		if snapshot["phase"] == "ended":
			_expect(boss_ends.size() == 1, "terminal phase telemetry follows the contractual boss completion")
	)
	for index in range(5):
		var expected_wave := "wave_%02d" % (index + 1)
		_expect(main.wave_director.current_wave_id == expected_wave, "choice must automatically start the next ordered wave")
		_expect(not main.boss_has_started, "boss cannot start before fifth choice")
		main.wave_director.advance(1000.0)
		_expect(main.wave_director.state == WaveDirector.State.AWAITING_RESOLUTION, "duration metadata must not end unresolved wave")
		var spawn_count: int = content["waves"][index]["spawns"].size()
		for _monster in range(spawn_count - 1):
			main.lane_field.resolve_dish(_dish())
		_expect(not main.upgrade_choice.visible, "offer must wait for the last actual monster resolution")
		main.lane_field.resolve_dish(_dish())
		_expect(completions.size() == index + 1, "exactly one completion for each actual wave")
		_expect(main.get_run_snapshot()["phase"] == "upgrade" and not main.get_run_snapshot()["terminal"], "upgrade selection remains an active run")
		_expect(main.upgrade_choice.visible and main.upgrade_choice.options.get_child_count() == 3, "real overlay exposes exactly three choices")
		_expect(not main.board_view.can_process() and not main.lane_field.can_process() and main.wave_director.paused, "upgrade overlay pauses board, runners and director")
		var elapsed: float = main.get_run_snapshot()["logical_elapsed_sec"]
		var wave_elapsed: float = main.wave_director.wave_elapsed_sec
		main._process(10.0)
		main.wave_director.advance(10.0)
		_expect(main.get_run_snapshot()["logical_elapsed_sec"] == elapsed and main.wave_director.wave_elapsed_sec == wave_elapsed, "upgrade waiting advances neither gameplay clock nor agenda")
		var offer: Array = main.upgrade_selector.get_current_offer()
		var ids: Array = []
		for option_index in range(offer.size()):
			var upgrade: Dictionary = offer[option_index]
			ids.append(upgrade["id"])
			var button: Button = main.upgrade_choice.options.get_child(option_index)
			_expect(button.text.contains(content["localization"][upgrade["display_name_key"]]) and button.text.contains(content["localization"][upgrade["description_key"]]), "choice label and description come from validated localization")
		offers.append(ids)
		main.upgrade_choice.choice_requested.emit("not_in_the_offer")
		_expect(main.upgrade_selector.get_selection_count() == index and main.upgrade_choice.visible, "domain rejects invalid UI intent without leaving selection")
		var stale_button: Button = main.upgrade_choice.options.get_child(0)
		var previous_mode: int = main.process_mode
		main.process_mode = Node.PROCESS_MODE_DISABLED
		stale_button.pressed.emit()
		_expect(not stale_button.disabled and main.upgrade_choice._accepting_choice, "stale pressed event during host pause must not lock the offer")
		main.process_mode = previous_mode
		await process_frame
		await process_frame
		_expect(stale_button.get_global_rect().size.y >= 180, "choice has a usable vertical target")
		_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(stale_button.get_global_rect()), "choice is inside the portrait viewport")
		_tap(viewport, stale_button.get_global_rect().get_center())
		_expect(main.upgrade_selector.get_selection_count() == index + 1, "actual viewport click must select exactly one upgrade")
		_expect(not main.upgrade_choice.visible, "successful choice closes overlay synchronously")
		stale_button.pressed.emit()
		_expect(main.upgrade_selector.get_selection_count() == index + 1, "repeated button event cannot select a second upgrade")
		_expect(main.board_view.can_process() and main.lane_field.can_process() and not main.wave_director.paused, "choice resumes gameplay")
		if index < 4:
			_expect(main.wave_director.current_wave_id == "wave_%02d" % (index + 2), "first four choices advance exactly one wave")
		else:
			_expect(main.boss_has_started and boss_starts.size() == 1 and main.boss_encounter_active, "fifth choice starts exactly one boss")
			var modifiers: Dictionary = Modifiers.derive(main.upgrade_selector.get_active_effects())["modifiers"]
			_expect(main.boss_runner.motion.global_speed_multiplier == modifiers["monster_speed_global"], "fifth choice effects apply before boss spawn")
			_expect(main.get_run_snapshot()["phase"] == "boss", "boss is a distinct run phase")
	_expect(completions == ["wave_01", "wave_02", "wave_03", "wave_04", "wave_05"], "run has exactly five normal completions")
	_expect(not main.wave_director.has_wave("wave_06"), "there is no wave six")
	if breach:
		main.boss_runner.advance(1000.0)
		_expect(main.reputation.current > 0 and not main.reputation.defeated, "surviving boss breach must retain its positive reputation")
		_expect(main.get_run_snapshot()["outcome"] == "boss_escaped", "surviving boss breach is explicit non-victorious completion")
		_expect(not main.hud.outcome_label.visible, "unsatisfied boss must not display victory")
	else:
		main.lane_field.resolve_dish(_dish())
		_expect(main.get_run_snapshot()["outcome"] == "victory" and main.hud.outcome_label.text == "Victoria", "satisfied boss produces victory")
	_expect(main.get_run_snapshot()["terminal"] and main.get_run_snapshot()["phase"] == "ended", "boss completion freezes run terminal state")
	_expect(not main.board_view.can_process() and not main.lane_field.can_process(), "terminal result stops gameplay")
	_expect(boss_ends.size() == 1 and boss_ends[0]["satisfied"] == (not breach), "boss completion payload preserves satisfaction distinction")
	var terminal_elapsed: float = main.get_run_snapshot()["logical_elapsed_sec"]
	main._process(1000.0)
	main.wave_director.wave_completed.emit({"wave_id": "wave_05"})
	main.lane_field.monster_satisfied.emit(boss_starts[0])
	_expect(main.get_run_snapshot()["logical_elapsed_sec"] == terminal_elapsed and boss_ends.size() == 1 and boss_starts.size() == 1, "late callbacks cannot resume, repeat or advance terminal run")
	var transcript := {"board": initial_board, "offers": offers, "selected": main.upgrade_selector.get_selected_upgrade_ids()}
	viewport.queue_free()
	await process_frame
	return transcript


func _test_defeat() -> void:
	var fixture := await _fixture()
	var main = fixture["main"]
	var endings: Array = []
	main.run_ended.connect(func(p: Dictionary): endings.append(p))
	main.run_phase_changed.connect(func(snapshot: Dictionary):
		if snapshot["phase"] == "ended":
			_expect(endings.size() == 1, "terminal phase telemetry follows contractual run_ended")
	)
	main.wave_director.advance(2.0)
	main.reputation.apply_damage(1000.0)
	_expect(main.get_run_snapshot()["terminal"] and main.get_run_snapshot()["outcome"] == "defeat", "depleted reputation ends the playable run")
	_expect(endings.size() == 1 and not main.upgrade_choice.visible, "defeat emits one terminal event and no upgrade")
	main.wave_director.wave_completed.emit({"wave_id": "wave_01"})
	_expect(main.upgrade_selector.get_current_offer().is_empty() and not main.boss_has_started, "late completion cannot progress after defeat")
	fixture["viewport"].queue_free()
	await process_frame


func _dish() -> Dictionary:
	return {"ok": true, "satisfaction_final": 1000.0, "special_effect_triggered": false}


func _tap(viewport: SubViewport, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		viewport.push_input(event, true)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
