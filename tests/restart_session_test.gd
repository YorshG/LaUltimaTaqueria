extends SceneTree

const APP := preload("res://scenes/App.tscn")
const AppScript := preload("res://scripts/app.gd")
const Save := preload("res://scripts/save/save_service.gd")
const BOOST_PATH := ["last_stand", "slow_salsa", "taco_power_1", "patient_service", "reputation_boost"]
const SHIELD_PATH := ["slow_salsa_plus", "taco_power_1", "warm_welcome", "last_stand", "safety_shield"]

class SeededSelector extends UpgradeSelector:
	func start_run(_seed: int) -> Dictionary:
		return super.start_run(2)

class TestHost extends AppScript:
	var shield_fixture := false

	func _create_session() -> Node:
		var session := super._create_session()
		# RUN-01 may auto-start production. Fixtures intentionally own their clock.
		for property in session.get_property_list():
			if property["name"] == "auto_start_run":
				session.set("auto_start_run", false)
		if shield_fixture:
			session.get_node("UpgradeSelector").set_script(SeededSelector)
		return session

var checks := 0
var failures := 0
var restart_cycles := 20
var covered: Dictionary = {}
var viewport: SubViewport


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	root.add_child(viewport)
	await _confirmation_snapshot()
	await _whole_run_reset()
	await _charges_and_forgiveness()
	await _terminal_and_audio()
	await _reentrant_terminal_restarts()
	await _stale_callbacks_and_timers()
	await _real_modal_input()
	await _repeat_and_metadata()
	await _production_scene()
	for case_number in range(1, 31):
		_expect(covered.has(case_number), "coverage contains RST-%02d" % case_number)
	viewport.free()
	if failures == 0:
		print("RST-01 PASS: 30/30 cases; %d checks; atomic replacement, real input, %d restarts, stale callbacks, metadata." % [checks, restart_cycles])
	else:
		push_error("RST-01 FAIL: %d/%d checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _new_app(shield: bool = false):
	var app = APP.instantiate()
	app.set_script(TestHost)
	app.shield_fixture = shield
	viewport.add_child(app)
	await process_frame
	await process_frame
	app.get_session().wave_director.auto_advance = false
	return app


func _confirmation_snapshot() -> void:
	var app = await _new_app()
	var main = app.get_session()
	main.wave_director.start_wave("wave_01", 7.0)
	main.wave_director.advance(2.0)
	main.reputation.apply_damage(21.5)
	main.board_view.begin_chain_at(Vector2i(0, 0))
	main.board_view.extend_chain_to(Vector2i(1, 0))
	main.board_view.extend_chain_to(Vector2i(2, 0))
	var runner = main.lane_field.spawn_runner(1, 55.0, "M", "nibbler", 100.0)
	runner.auto_advance = false
	runner.advance(1.0)
	runner.apply_brief_stun(2.0)
	main.feedback_audio.playback_enabled = true
	main.feedback_audio.request({"sound_id": "selection"})
	main.feedback_audio.request({"sound_id": "chain_valid"})
	var snapshot := _snapshot(main)
	var generation: int = app.get_generation()
	app.request_restart()
	_case(1, app.is_confirmation_pending() and app.get_session() == main and app.confirmation.visible, "active run requires a visible confirmation")
	app.request_restart()
	_expect(app.session_host.get_child_count() == 1 and app.get_generation() == generation, "repeated request keeps one modal and one session")
	await create_timer(0.10).timeout
	_expect(main.feedback_audio._current_id == "selection" and main.feedback_audio._pending == ["chain_valid"], "modal preserves active audio and queued cues")
	app.cancel_restart()
	_case(2, _snapshot(main) == snapshot, "cancel restores strong runtime snapshot, including gesture and RNG")
	_case(25, main.can_process() and runner.can_process() and not app.is_confirmation_pending(), "cancel restores processing and dismisses modal")
	# A pending upgrade is active even when its wave is completed.
	main.wave_director.wave_completed.emit({"wave_id": "wave_01"})
	_expect(main.upgrade_selector.state == UpgradeSelector.State.OFFER_READY, "fixture owns a pending offer")
	var offer_snapshot := _snapshot(main)
	app.request_restart()
	_expect(app.is_confirmation_pending(), "pending upgrade still requires confirmation")
	app.cancel_restart()
	_expect(_snapshot(main) == offer_snapshot, "cancel preserves exact pending upgrade offer")
	app.free()


func _whole_run_reset() -> void:
	var app = await _new_app()
	var initial := _snapshot(app.get_session())
	var main = app.get_session()
	_drive_to_boss(main, BOOST_PATH)
	_expect(main.boss_encounter_active and main.boss_runner != null, "fixture reaches the real fifth-selection boss bridge")
	_expect(main.lane_field.global_speed_multiplier < 1.0 and main.reputation.reputation_damage_multiplier == 0.85 and main.reputation.maximum == 115.0, "real selections applied speed, defense and reputation effects")
	main.reputation.apply_damage(37.25)
	main.boss_runner.apply_brief_stun(4.0)
	main.boss_runner.monster_state.apply_satisfaction(main.boss_runner.monster_state.hunger_max * 0.5)
	main.board_view.begin_chain_at(Vector2i(0, 0))
	main.board_view.extend_chain_to(Vector2i(1, 0))
	main.board_view.extend_chain_to(Vector2i(2, 0))
	main.board_view.finish_chain()
	main._begin_encounter()
	var old_boss = main.boss_runner
	var old_runner = main.lane_field._runners[0]
	var old_id: int = main.get_instance_id()
	var old_reputation = main.reputation
	var old_feedback = main.feedback
	var old_generation: int = app.get_generation()
	app.request_restart()
	app.confirm_restart()
	var fresh = app.get_session()
	fresh.wave_director.auto_advance = false
	_case(3, _retired(main) and fresh.get_instance_id() != old_id and _official(app, fresh, old_generation + 1), "replacement retires old immediately and installs exactly one official ready session")
	_case(4, fresh.reputation.snapshot() == initial["reputation_snapshot"] and fresh.reputation._processed_breaches.is_empty() and fresh.reputation._applied_selections.is_empty(), "reputation, maximum and dedupe reset")
	_case(5, _wave_snapshot(fresh) == initial["wave"], "wave schedule, counts, timers and paused state reset")
	_case(6, _board_snapshot(fresh) == initial["board"], "board, RNG and gesture reset")
	_case(7, _upgrade_snapshot(fresh) == initial["upgrades"], "selected, blocked and offered upgrades plus RNG reset")
	_case(8, fresh.lane_field.global_speed_multiplier == 1.0 and fresh.reputation.reputation_damage_multiplier == 1.0 and fresh.reputation.maximum == 100.0, "applied effects reset, not just selected IDs")
	_case(12, fresh._encounter_token == 0 and not fresh._first_dish_pending, "encounter token and first dish reset")
	_case(13, not old_boss.is_inside_tree() and not old_boss.can_process() and not fresh.boss_has_started and not fresh.boss_encounter_active and fresh.boss_runner == null, "old boss is detached and inactive; new encounter is clean")
	_case(14, not old_runner.is_inside_tree() and not old_runner.can_process(), "old runner is immediately outside gameplay")
	var fresh_snapshot := _snapshot(fresh)
	old_reputation.reputation_changed.emit({"current": 1.0, "maximum": 1.0, "defeated": true})
	old_reputation.run_ended.emit({"outcome": "defeat"})
	old_feedback.feedback_requested.emit({"cue_id": "defeat", "text_key": "feedback.defeat", "sound_id": "defeat", "terminal": true})
	old_runner.reached_counter.emit({"spawn_sequence": old_runner.monster_state.spawn_sequence, "monster_id": "nibbler", "lane": 0})
	main.run_ended.emit({"outcome": "defeat"})
	main.boss_encounter_completed.emit({"satisfied": true})
	_case(26, _snapshot(fresh) == fresh_snapshot and not app.is_terminal(), "old node and RefCounted signals cannot affect the replacement before deletion")
	await process_frame
	_case(3, not is_instance_valid(main), "old Main is destroyed by the next frame")
	_case(13, not is_instance_valid(old_boss), "old boss is destroyed by the next frame")
	_case(14, not is_instance_valid(old_runner), "old runner is destroyed by the next frame")
	var generation: int = app.get_generation()
	app.confirm_restart()
	app.confirm_restart()
	app.session_replaced.connect(func(_value):
		app.request_restart()
		app.confirm_restart()
	)
	_case(19, app.get_generation() == generation and not app.is_confirmation_pending(), "duplicate confirmations cannot replace twice")
	app.request_restart()
	app.confirm_restart()
	_expect(app.get_generation() == generation + 1 and not app.is_confirmation_pending(), "reentrant replacement observer cannot open or confirm another restart")
	app.free()


func _charges_and_forgiveness() -> void:
	var app = await _new_app(true)
	_drive_to_boss(app.get_session(), SHIELD_PATH)
	_expect(app.get_session().reputation.shield_charges > 0, "real safety_shield selection grants charges")
	app.request_restart()
	app.confirm_restart()
	_case(9, app.get_session().reputation.shield_charges == 0, "shield charges are per run")
	app.free()
	app = await _new_app()
	var main = app.get_session()
	_select(main, 1, "second_chance")
	_expect(main.reputation.extra_life_charges == 1 and main.reputation._extra_life_restore_ratio == 0.25, "real second_chance grants one life")
	app.request_restart()
	app.confirm_restart()
	_case(10, app.get_session().reputation.extra_life_charges == 0 and app.get_session().reputation._extra_life_restore_ratio == 0.0, "life charge and rescue ratio reset")
	_select(app.get_session(), 1, "steady_hands")
	_expect(app.get_session().board_view.get_input_forgiveness() == 0.1, "real steady_hands applies forgiveness")
	app.request_restart()
	app.confirm_restart()
	_case(11, app.get_session().board_view.get_input_forgiveness() == 0.0, "input forgiveness is zero in replacement")
	app.free()


func _terminal_and_audio() -> void:
	var app = await _new_app()
	var main = app.get_session()
	main.feedback_audio.playback_enabled = true
	main.reputation.apply_damage(1000.0)
	_expect(main.feedback_audio._terminal and main.feedback_audio._current_id == "defeat", "fixture actually latches terminal audio")
	_expect(app.is_terminal() and not main.can_process() and app.restart_button.can_process(), "defeat disables gameplay but leaves host CTA active")
	var generation: int = app.get_generation()
	app.restart_button.pressed.emit()
	_case(18, app.get_generation() == generation + 1 and not app.is_confirmation_pending() and not app.is_terminal(), "terminal defeat restarts directly")
	app.restart_button.pressed.emit()
	_expect(app.get_generation() == generation + 1 and app.is_confirmation_pending(), "second terminal CTA activation cannot restart the fresh active run without confirmation")
	app.cancel_restart()
	var audio = app.get_session().feedback_audio
	audio.playback_enabled = true
	audio.request({"sound_id": "selection"})
	_case(17, not audio._terminal and audio._current_id == "selection" and audio.playing, "audio accepts and plays a cue after defeat plus restart")
	audio.playback_enabled = false
	# Both satisfied and escaped terminal boss payloads are terminal under D9.
	for satisfied in [true, false]:
		app.get_session().boss_encounter_completed.emit({"satisfied": satisfied})
		_expect(app.is_terminal(), "terminal boss completion is recognized")
		generation = app.get_generation()
		app.request_restart()
		_expect(app.get_generation() == generation + 1 and not app.is_confirmation_pending(), "boss terminal restarts directly")
	app.free()


func _retired(old: Node) -> bool:
	return is_instance_valid(old) and not old.is_inside_tree() and old.process_mode == Node.PROCESS_MODE_DISABLED and old.is_queued_for_deletion()


func _official(app, fresh, generation: int) -> bool:
	return app.get_session() == fresh and fresh.is_inside_tree() and fresh.is_node_ready() and app.get_generation() == generation and app.session_host.get_child_count() == 1 and app.session_host.get_child(0) == fresh and not app._replacing


func _reentrant_terminal_restarts() -> void:
	# These real emitters stay locked until each synchronous listener returns.
	for terminal_kind in ["defeat", "satisfied", "escaped"]:
		for double_request in [false, true]:
			var app = await _new_app()
			var old = app.get_session()
			if terminal_kind != "defeat":
				_drive_to_boss(old, BOOST_PATH)
			var generation: int = app.get_generation()
			var observations: Array = []
			var listener := func(_payload: Dictionary):
				app.request_restart()
				observations.append(_retired(old) and _official(app, app.get_session(), generation + 1))
				if double_request:
					app.request_restart()
					observations.append(_official(app, app.get_session(), generation + 1) and app.is_confirmation_pending())
			if terminal_kind == "defeat":
				old.run_ended.connect(listener, CONNECT_ONE_SHOT)
				old.reputation.apply_damage(1000.0)
			else:
				old.boss_encounter_completed.connect(listener, CONNECT_ONE_SHOT)
				if terminal_kind == "satisfied":
					old.lane_field.resolve_dish({"ok": true, "satisfaction_final": 10000.0, "special_effect_triggered": false})
				else:
					old.boss_runner.advance(1000.0)
			var fresh = app.get_session()
			fresh.wave_director.auto_advance = false
			_case(27 if terminal_kind == "defeat" else 28, observations.size() == (2 if double_request else 1) and observations.all(func(value): return value) and _official(app, fresh, generation + 1), "terminal listener installs one ready session synchronously: %s" % terminal_kind)
			if double_request:
				_case(29, app.is_confirmation_pending() and app.get_generation() == generation + 1, "second listener request can only open confirmation for the fresh run")
				app.cancel_restart()
			var snapshot := _snapshot(fresh)
			old.run_ended.emit({"outcome": "defeat"})
			old.boss_encounter_completed.emit({"satisfied": false})
			app._on_terminal({"outcome": "defeat"}, generation)
			_case(30, not app.is_terminal() and app.restart_button.text == "Reiniciar" and not app.is_confirmation_pending() and _snapshot(fresh) == snapshot and _official(app, fresh, generation + 1), "previous-generation callbacks are ineffective before deletion")
			await process_frame
			_case(27 if terminal_kind == "defeat" else 28, not is_instance_valid(old), "terminal emitter is destroyed after the frame unwinds")
			app.free()


func _stale_callbacks_and_timers() -> void:
	var app = await _new_app()
	var main = app.get_session()
	main.wave_director.auto_advance = true
	main.wave_director.start_wave("wave_01", 5.0)
	var runner = main.lane_field.spawn_runner(0, 100.0, "M", "nibbler", 30.0)
	var timer := Timer.new()
	timer.wait_time = 0.12
	timer.one_shot = true
	# Even explicitly ALWAYS children must be frozen by a confirmation modal.
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(timer)
	var fired: Array = []
	timer.timeout.connect(func(): fired.append(true))
	timer.start()
	var countdown: float = main.wave_director.countdown_remaining_sec
	var progress: float = runner.motion.progress
	var remaining := timer.time_left
	app.request_restart()
	await create_timer(0.18).timeout
	_case(24, main.wave_director.countdown_remaining_sec == countdown and runner.motion.progress == progress and timer.time_left == remaining and fired.is_empty(), "modal freezes wave, runner and even an ALWAYS gameplay timer")
	app.cancel_restart()
	await create_timer(0.04).timeout
	_expect(main.wave_director.countdown_remaining_sec < countdown and runner.motion.progress > progress and timer.time_left < remaining, "cancel resumes the original clocks")
	app.request_restart()
	app.confirm_restart()
	_case(15, _retired(main) and not timer.is_inside_tree() and not timer.can_process(), "old Timer is immediately detached and inactive")
	await process_frame
	_case(15, not is_instance_valid(timer), "old gameplay Timer is destroyed by the next frame")
	await create_timer(0.14).timeout
	_expect(fired.is_empty(), "old timeout cannot fire after replacement")
	app.free()


func _real_modal_input() -> void:
	for touch in [false, true]:
		var app = await _new_app()
		var main = app.get_session()
		var board: BoardView = main.board_view
		var restart_point: Vector2 = app.restart_button.get_global_rect().get_center()
		_press(restart_point, touch, true)
		_press(restart_point, touch, false)
		_expect(app.is_confirmation_pending(), "footer restart CTA opens a modal through real viewport input")
		app.cancel_restart()
		var completions: Array = []
		board.chain_completed.connect(func(_points, _ingredient): completions.append(true))
		_press(_cell_center(board, 0), touch, true)
		_drag(_cell_center(board, 1), touch)
		_drag(_cell_center(board, 2), touch)
		_expect(board._chain.size() == 3 and board._dragging, "real input starts a valid unfinished chain")
		var before := _snapshot(main)
		app.request_restart()
		await process_frame
		# Release and attempts to continue gameplay underneath a real modal.
		_press(_cell_center(board, 2), touch, false)
		_press(_cell_center(board, 4), touch, true)
		_drag(_cell_center(board, 3), touch)
		_press(_cell_center(board, 3), touch, false)
		_expect(completions.is_empty() and board._chain.size() == 3, "modal input cannot finish or mutate the existing chain")
		var cancel_point: Vector2 = app.cancel_button.get_global_rect().get_center()
		_press(cancel_point, touch, true)
		_press(cancel_point, touch, false)
		_expect(not app.is_confirmation_pending(), "modal cancel works through real viewport input")
		_expect(_snapshot(main) == before and completions.is_empty(), "cancel input leaves snapshot and pending chain intact")
		# Confirm also works through GUI, from a fresh modal.
		app.request_restart()
		await process_frame
		var confirm_point: Vector2 = app.confirm_button.get_global_rect().get_center()
		_press(confirm_point, touch, true)
		_press(confirm_point, touch, false)
		_expect(_retired(main) and _official(app, app.get_session(), 2), "real confirm synchronously installs one replacement")
		await process_frame
		_expect(not is_instance_valid(main), "real confirm destroys old by the next frame")
		app.free()


func _repeat_and_metadata() -> void:
	var app = await _new_app()
	var initial := _snapshot(app.get_session())
	var nodes := _node_count(app)
	var connections := _connections(app.get_session())
	var task_tmp := OS.get_environment("TMPDIR")
	if task_tmp.is_empty():
		task_tmp = "/tmp"
	var path := task_tmp.path_join("rst_01_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	var save := Save.new(path)
	save.set_record(321)
	save.set_coins(654)
	save.set_preference("audio", false)
	_expect(save.save() == OK, "isolated metadata fixture saves")
	var bytes := FileAccess.get_file_as_bytes(path)
	var repetitions := 20
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cycles="):
			repetitions = maxi(20, int(argument.trim_prefix("--cycles=")))
	restart_cycles = repetitions
	for cycle in range(repetitions):
		var old = app.get_session()
		var generation: int = app.get_generation()
		old.reputation.apply_damage(1.25)
		app.request_restart()
		app.confirm_restart()
		var fresh = app.get_session()
		fresh.wave_director.auto_advance = false
		_case(20, _retired(old) and _official(app, fresh, generation + 1) and _node_count(app) == nodes, "stable nodes after replacement %d" % cycle)
		_case(21, _connections(fresh) == connections, "stable signal listeners after replacement %d" % cycle)
		_case(22, _snapshot(fresh) == initial, "default seeds reproduce initial logical state %d" % cycle)
		await process_frame
		_case(20, not is_instance_valid(old), "old session destroyed after replacement %d" % cycle)
	_case(16, _connections(app.get_session()) == connections, "signal wiring has no duplicate connections")
	var source := FileAccess.get_file_as_string("res://scripts/app.gd")
	_case(23, FileAccess.get_file_as_bytes(path) == bytes and save.get_record() == 321 and save.get_coins() == 654 and save.get_preferences() == {"audio": false} and not source.contains("save_service") and not source.contains("FileAccess") and not source.contains("DirAccess"), "App does not load/write metadata and fixture bytes are unchanged")
	DirAccess.remove_absolute(path)
	app.free()


func _production_scene() -> void:
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/App.tscn", "project boots App")
	var app = APP.instantiate()
	viewport.add_child(app)
	await process_frame
	await process_frame
	_expect(app.session_host.get_child_count() == 1 and app.get_session().is_node_ready(), "production App owns exactly one ready Main")
	app.free()


func _drive_to_boss(main, path: Array) -> void:
	for index in range(5):
		var id := "wave_%02d" % (index + 1)
		_expect(main.wave_director.start_wave(id, 0.0)["ok"], "wave fixture starts " + id)
		main.wave_director.advance(1000.0)
		for runner in main.lane_field._runners.duplicate():
			runner.auto_advance = false
			if runner.monster_state.active:
				runner.monster_state.apply_satisfaction(10000.0)
				main.lane_field.monster_satisfied.emit({"spawn_sequence": runner.monster_state.spawn_sequence, "monster_id": runner.monster_state.monster_id, "lane": runner.monster_state.lane})
		_expect(main.upgrade_selector.select_upgrade(path[index])["ok"], "real offer selects " + path[index])


func _select(main, wave: int, id: String) -> void:
	main.wave_director.wave_completed.emit({"wave_id": "wave_%02d" % wave})
	_expect(main.upgrade_selector.select_upgrade(id)["ok"], "real offer selects " + id)


func _props(object: Object, keys: Array) -> Dictionary:
	var result := {}
	for key in keys:
		var value = object.get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result


func _board_snapshot(main) -> Dictionary:
	var board = main.board_view
	return {"cells": board.get_ingredient_snapshot(), "seed": board.get_board_seed(), "rng": board._board_state._rng.state, "forgiveness": board.get_input_forgiveness(), "dragging": board._dragging, "points": board._chain.points(), "ingredient": board._chain.ingredient_id()}


func _wave_snapshot(main) -> Dictionary:
	return _props(main.wave_director, ["state", "paused", "auto_advance", "current_wave_id", "countdown_remaining_sec", "wave_elapsed_sec", "_schedule", "_next_spawn_index", "_scheduled_spawn_count", "_pending_sequences", "_resolved_count", "_satisfied_count", "_counter_reached_count", "_completion_emitted", "_duration_target_sec", "_teaches"])


func _upgrade_snapshot(main) -> Dictionary:
	var selector = main.upgrade_selector
	var result := _props(selector, ["state", "_run_started", "_selected_upgrades", "_selected_ids", "_blocked_ids", "_completed_wave_ids", "_current_offer", "_current_wave_id", "_strong_defense_selected"])
	result["rng"] = selector._rng.state
	return result


func _snapshot(main) -> Dictionary:
	var runners: Array = []
	for runner in main.lane_field._runners:
		runners.append({"motion": _props(runner.motion, ["progress", "speed_relative", "phase_multiplier", "global_speed_multiplier", "stun_remaining_sec"]), "monster": _props(runner.monster_state, ["monster_id", "spawn_sequence", "hunger_max", "hunger_remaining", "satisfied", "active", "phase_index"]), "emitted": runner._counter_reached_emitted, "auto": runner.auto_advance})
	var run_state := {}
	for property in main.get_property_list():
		if property["name"] in ["_wave_order", "_wave_index", "_run_phase", "_run_terminal", "_run_outcome", "_selection_in_progress", "_logical_elapsed_sec"]:
			run_state.merge(_props(main, [property["name"]]))
	return {
		"run_state": run_state,
		"main": _props(main, ["boss_has_started", "boss_encounter_active", "_completed_normal_waves", "_breach_results_by_sequence", "_encounter_token", "_first_dish_pending", "process_mode"]),
		"reputation_snapshot": main.reputation.snapshot(),
		"reputation_private": _props(main.reputation, ["reputation_damage_multiplier", "_extra_life_restore_ratio", "_processed_breaches", "_applied_selections"]),
		"board": _board_snapshot(main), "wave": _wave_snapshot(main), "upgrades": _upgrade_snapshot(main),
		"lane": {"speed": main.lane_field.global_speed_multiplier, "sequence": main.lane_field._next_spawn_sequence, "runners": runners},
		"feedback": _props(main.feedback, ["_gesture_active", "_valid_reported", "_was_low", "_ended", "_reported_resolutions", "_reported_shields", "_reported_phases"]),
		"audio": _props(main.feedback_audio, ["_terminal", "_current_id", "_pending", "playback_enabled", "stream_paused", "process_mode"]),
		"messages": main.feedback_layer.get_messages(),
		"hud": [main.hud.reputation_label.text, main.hud.reputation_bar.value, main.hud.reputation_bar.max_value, main.hud.outcome_label.text, main.hud.outcome_label.visible],
	}


func _connections(main) -> Array:
	var result: Array = []
	for pair in [[main, "run_ended"], [main, "boss_encounter_completed"], [main.board_view, "chain_completed"], [main.lane_field, "monster_reached_counter"], [main.lane_field, "monster_satisfied"], [main.wave_director, "wave_completed"], [main.upgrade_selector, "upgrade_selected"], [main.reputation, "run_ended"], [main.reputation, "reputation_changed"], [main.feedback, "feedback_requested"], [main.feedback_audio, "finished"]]:
		result.append(pair[0].get_signal_connection_list(pair[1]).size())
	return result


func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count


func _cell_center(board: BoardView, index: int) -> Vector2:
	return (board.grid.get_child(index) as Control).get_global_rect().get_center()


func _press(point: Vector2, touch: bool, pressed: bool) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		viewport.push_input(event, true)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event, true)


func _drag(point: Vector2, touch: bool) -> void:
	if touch:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point
		viewport.push_input(event, true)
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(event, true)


func _case(number: int, condition: bool, message: String) -> void:
	covered[number] = true
	_expect(condition, "RST-%02d: %s" % [number, message])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
