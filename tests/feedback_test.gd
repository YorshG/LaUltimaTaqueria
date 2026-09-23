extends SceneTree

const Coordinator = preload("res://scripts/ui/feedback_coordinator.gd")
const Audio = preload("res://scripts/ui/feedback_audio.gd")
const Registry = preload("res://scripts/content/content_registry.gd")
const MAIN_SCENE = preload("res://scenes/Main.tscn")

var failures := 0
var content: Dictionary


func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "feedback uses validated content and localization")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	_test_gesture_and_threshold()
	_test_cue_contract_and_pcm()
	await _test_real_signals()
	await _test_boss_and_terminal_audio()
	await _test_audio_policy()
	await _test_gameplay_independence()
	await _test_layout()
	if failures == 0:
		print("UI-02 tests passed: gestures, all visual/audio cues, low reputation, boss endings, bounded audio, silent gameplay, Unicode layout.")
		quit(0)
	else:
		push_error("UI-02 tests failed: %d" % failures)
		quit(1)


func _test_gesture_and_threshold() -> void:
	var coordinator := Coordinator.new({"current": 100.0, "maximum": 100.0})
	var events := _record(coordinator)
	coordinator.on_chain_started(_points(1))
	coordinator.on_chain_started(_points(1))
	coordinator.on_chain_changed(_points(2))
	_expect(_ids(events) == ["selection"], "selection fires once; length 2 is not valid")
	for length in [3, 4, 5, 6, 3]:
		coordinator.on_chain_changed(_points(length))
	_expect(_ids(events) == ["selection", "chain_valid"], "first length 3 triggers one cue per gesture")
	coordinator.on_chain_completed(_points(6), "veggie")
	coordinator.on_chain_started(_points(1))
	coordinator.on_chain_changed(_points(3))
	coordinator.on_chain_cancelled()
	coordinator.on_chain_started(_points(1))
	coordinator.on_chain_changed(_points(3))
	_expect(_count(events, "selection") == 3 and _count(events, "chain_valid") == 3, "completion and cancellation rearm next gesture")
	events.clear()
	for value in [21.0, 20.0, 19.0, 1.0, 20.0]:
		coordinator.on_reputation_changed({"current": value, "maximum": 100.0})
	_expect(_ids(events) == ["low_reputation"], "exact 20 percent crossing alerts once; staying low is quiet")
	coordinator.on_reputation_changed({"current": 25.0, "maximum": 100.0})
	coordinator.on_reputation_changed({"current": 40.0, "maximum": 200.0})
	_expect(_count(events, "low_reputation") == 2, "recovery rearms a new crossing; threshold uses ratio")
	var initially_low := Coordinator.new({"current": 10.0, "maximum": 100.0})
	var initial_events := _record(initially_low)
	initially_low.on_reputation_changed({"current": 9.0, "maximum": 100.0})
	_expect(initial_events.is_empty(), "already low snapshot does not invent a crossing")


func _test_cue_contract_and_pcm() -> void:
	var coordinator := Coordinator.new()
	var events := _record(coordinator)
	coordinator.on_chain_started(_points(1))
	coordinator.on_chain_changed(_points(3))
	coordinator.on_dish_created({})
	coordinator.on_dish_served({})
	coordinator.on_monster_satisfied({"spawn_sequence": 1})
	coordinator.on_breach({"spawn_sequence": 2})
	coordinator.on_breach({"spawn_sequence": 2})
	coordinator.on_reputation_changed({"current": 20.0, "maximum": 100.0, "delta": -10.0})
	coordinator.on_upgrade_selected({"effect": {"type": "modify_reputation", "value": 15}})
	for phase in content["boss"]["phases"]:
		coordinator.on_boss_phase_changed(phase)
		coordinator.on_boss_phase_changed(phase)
	coordinator.on_boss_completed({"satisfied": false})
	_expect(_count(events, "victory") == 0, "boss breach cannot announce victory")
	coordinator.on_boss_completed({"satisfied": true})
	coordinator.on_boss_completed({"satisfied": true})
	coordinator.on_dish_served({})
	_expect(_count(events, "victory") == 1 and events.back()["cue_id"] == "victory", "victory is one-shot and remains final")
	var losing := Coordinator.new()
	var defeats := _record(losing)
	losing.on_run_ended({"outcome": "defeat"})
	losing.on_run_ended({"outcome": "defeat"})
	_expect(defeats.size() == 1, "defeat emits once")
	events.append_array(defeats)
	var seen := {}
	var streams := {}
	for payload in events:
		var key: String = payload["text_key"]
		_expect(key.begins_with("feedback.") and content["localization"].has(key), "every cue has localized visual feedback")
		_expect(not str(content["localization"][key]).is_empty(), "visual text is nonempty without sound or color")
		var cue: String = payload["sound_id"]
		if cue.is_empty():
			_expect(payload["values"]["delta"] == "-10", "delta reuses state result without recalculating damage")
			continue
		seen[cue] = true
		var stream := Audio.synthesize(cue)
		_expect(stream != null and stream.data == Audio.synthesize(cue).data, "PCM is deterministic for %s" % cue)
		_expect(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo, "native PCM is mono 16-bit")
		_expect(stream.get_length() > 0.0 and stream.get_length() < 0.5, "all cues are brief and bounded")
		_expect(stream.data.decode_u16(0) == 0 and stream.data.decode_u16(stream.data.size() - 2) == 0, "envelope and gap begin/end at silence")
		for other in streams:
			_expect(streams[other] != stream.data, "%s is distinct from %s" % [cue, other])
		streams[cue] = stream.data
	_expect(seen.size() == Coordinator.CUE_KEYS.size() and seen.size() == Audio.TONES.size(), "all 12 essential sound cues exercised with visual counterparts")
	_expect(_count(events, "breach") == 1, "duplicate breach has no second cue")
	_expect(_count(events, "boss_phase_2") == 1 and _count(events, "boss_phase_3") == 1, "phase cues distinct and deduplicated; calm has no cue")


func _create_main():
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(payload: Dictionary):
		main.wave_director.get_spawned_runner(int(payload["spawn_sequence"])).auto_advance = false
	)
	main.boss_started.connect(func(_payload: Dictionary): main.boss_runner.auto_advance = false)
	return main


func _test_real_signals() -> void:
	var main = await _create_main()
	var events := _record(main.feedback)
	var runner: LaneRunner = main.lane_field.spawn_runner(1, 50.0, "M", "nibbler", 30.0)
	runner.auto_advance = false
	main.board_view.begin_chain_at(Vector2i(0, 0))
	main.board_view.extend_chain_to(Vector2i(1, 0))
	main.board_view.extend_chain_to(Vector2i(2, 0))
	main.board_view.extend_chain_to(Vector2i(2, 1))
	main.board_view.finish_chain()
	_expect(_ids(events) == ["selection", "chain_valid", "dish_created", "dish_served", "satisfied"], "real BoardView and LaneField emit distinct ordered feedback")
	_expect(runner.monster_state.satisfied, "real service still resolves monster")
	var messages: Array = main.feedback_layer.get_messages()
	_expect(messages.size() == 4 and messages[1]["cue_id"] == "dish_created" and messages[2]["cue_id"] == "dish_served" and messages[3]["cue_id"] == "satisfied", "same-frame service stages remain visually readable")
	var breacher: LaneRunner = main.lane_field.spawn_runner(0, 50.0, "M", "nibbler", 30.0)
	breacher.auto_advance = false
	breacher.advance(1000.0)
	_expect(main.reputation.current == 90.0, "feedback does not duplicate reputation damage")
	_expect(events[-2]["cue_id"] == "breach" and events[-1]["values"]["delta"] == "-10", "breach has explicit cue and actual state delta")
	main.reputation.restore(5.0)
	_expect(events.back()["values"]["delta"] == "+5", "positive delta is also visual")
	main.upgrade_selector.receive_wave_completed({"wave_id": "wave_01"})
	var offer: Array = main.upgrade_selector.get_current_offer()
	var reputation_before: Dictionary = main.reputation.snapshot()
	main.upgrade_selector.select_upgrade(str(offer[0]["id"]))
	_expect(events.back()["cue_id"] == "upgrade", "real selection announces upgrade")
	_expect(main.reputation.snapshot() == reputation_before, "feedback does not apply selected upgrade")
	main.queue_free()
	await process_frame


func _start_boss(main) -> void:
	for wave in content["waves"]:
		main.wave_director.start_wave(str(wave["id"]), 0.0)
		main.wave_director.advance(1000.0)
		for _entry in wave["spawns"]:
			main.lane_field.resolve_dish(_dish(1000.0))
		var offer: Array = main.upgrade_selector.get_current_offer()
		main.upgrade_selector.select_upgrade(str(offer[0]["id"]))


func _test_boss_and_terminal_audio() -> void:
	for win in [true, false]:
		var main = await _create_main()
		_start_boss(main)
		main.feedback_audio.playback_enabled = true # Headless uses Godot's Dummy audio driver.
		var events := _record(main.feedback)
		main.lane_field.resolve_dish(_dish(120.0))
		main.lane_field.resolve_dish(_dish(90.0))
		_expect(_count(events, "boss_phase_2") == 1 and _count(events, "boss_phase_3") == 1, "real boss phase transitions produce both cues")
		_expect(main.boss_runner.motion.phase_multiplier == 1.4 and main.boss_runner.motion.stun_remaining_sec == 0.0, "phase feedback preserves motion without mechanics")
		if win:
			main.lane_field.resolve_dish(_dish(1000.0))
			_expect(events.back()["cue_id"] == "victory", "real satisfied boss finishes with victory feedback")
		else:
			main.reputation.apply_damage(70.0)
			main.boss_runner.advance(1000.0)
			_expect(events.back()["cue_id"] == "defeat", "lethal breach ends with defeat, never overwritten")
			_expect(not main.can_process() and main.feedback_audio.can_process(), "terminal cue can play after gameplay is disabled")
			_expect(_count(events, "breach") == 1 and _count(events, "low_reputation") == 1, "lethal breach retains visual breach and threshold notice")
		var ending := "victory" if win else "defeat"
		_expect(main.feedback_audio._current_id == ending and main.feedback_audio._pending.is_empty(), "terminal sound preempts stale audio")
		_expect(main.feedback_layer.get_messages().back()["cue_id"] == ending, "terminal visual remains last")
		_expect(not main.boss_encounter_active, "BOSS-01 still closes")
		main.queue_free()
		await process_frame


func _test_audio_policy() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.playback_enabled = true
	audio.request(_audio_payload("selection"))
	var first_stream: AudioStream = audio.stream
	for _repeat in range(20):
		audio.request(_audio_payload("selection"))
	_expect(audio.stream == first_stream and audio._pending.is_empty(), "repetitions do not restart or accumulate sound")
	for cue in ["chain_valid", "dish_created", "dish_served", "satisfied", "breach", "low_reputation"]:
		audio.request(_audio_payload(cue))
	_expect(audio._pending.size() == Audio.MAX_PENDING and audio.max_polyphony == 1, "burst has bounded queue and a single voice")
	audio.request(_audio_payload("low_reputation"))
	_expect(audio._pending.count("low_reputation") == 1, "pending repetitions grouped")
	var next: String = audio._pending[0]
	audio.stop()
	audio.finished.emit() # Exercise scheduling without waiting for a physical device.
	_expect(audio._current_id == next, "finished advances queued feedback")
	audio.request(_audio_payload("defeat", true))
	_expect(audio._current_id == "defeat" and audio._pending.is_empty(), "terminal request interrupts and clears queue")
	audio.request(_audio_payload("dish_created"))
	_expect(audio._current_id == "defeat", "late sounds cannot replace terminal cue")
	audio.playback_enabled = false
	_expect(not audio.playing and audio._pending.is_empty(), "silent operation releases playback and queue")
	audio.queue_free()
	await process_frame


func _test_gameplay_independence() -> void:
	var snapshots: Array[Dictionary] = []
	for mode in ["disconnected", "silent", "dummy_audio"]:
		var main = await _create_main()
		if mode == "disconnected":
			# Baseline with no coordinator callbacks, including all gameplay sources.
			for source in [main.board_view, main.lane_field, main.reputation, main.upgrade_selector, main]:
				for event in source.get_signal_list():
					for connection in source.get_signal_connection_list(event["name"]):
						if connection["callable"].get_object() == main.feedback:
							source.disconnect(event["name"], connection["callable"])
		main.feedback_audio.playback_enabled = mode == "dummy_audio"
		var target: LaneRunner = main.lane_field.spawn_runner(1, 50.0, "M", "salsa_tank", 70.0)
		target.auto_advance = false
		main.board_view.begin_chain_at(Vector2i(0, 0))
		main.board_view.extend_chain_to(Vector2i(1, 0))
		main.board_view.extend_chain_to(Vector2i(2, 0))
		main.board_view.finish_chain()
		target.advance(1000.0)
		main.upgrade_selector.receive_wave_completed({"wave_id": "wave_01"})
		var offer: Array = main.upgrade_selector.get_current_offer()
		main.upgrade_selector.select_upgrade(str(offer[0]["id"]))
		snapshots.append({
			"board": main.board_view.get_ingredient_snapshot(),
			"reputation": main.reputation.snapshot(),
			"hunger": target.monster_state.hunger_remaining,
			"progress": target.motion.progress,
			"speed": target.effective_speed(),
			"wave": main.wave_director.get_state_name(),
			"upgrades": main.upgrade_selector.get_selected_upgrade_ids(),
		})
		main.queue_free()
		await process_frame
	_expect(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "feedback absent, silence and device-free audio produce identical gameplay")


func _test_layout() -> void:
	var main = await _create_main()
	var expanded: Dictionary = content["localization"].duplicate(true)
	expanded["feedback.boss_phase_3"] = "!! El Gran Glotón acelera — atención a los carriles, México"
	main.feedback_layer.configure(expanded)
	for label in main.feedback_layer.message_labels:
		label.add_theme_font_size_override("font_size", 56)
	for cue in ["chain_valid", "dish_created", "dish_served", "boss_phase_3"]:
		main.feedback_layer.present({"cue_id": cue, "text_key": Coordinator.CUE_KEYS[cue]})
	main.hud.show_outcome("defeat")
	for canvas in [Vector2(1080, 1620), Vector2(1080, 1920), Vector2(1080, 2400)]:
		main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		main.size = canvas
		for _frame in range(4):
			await process_frame
		var feedback_rect: Rect2 = main.feedback_layer.get_global_rect()
		_expect(feedback_rect.position.x >= 24.0 and feedback_rect.position.y >= 48.0 and feedback_rect.end.x <= canvas.x - 24.0, "feedback respects existing safe margins")
		for other in [main.hud, main.board_view, main.lane_field]:
			_expect(not feedback_rect.intersects(other.get_global_rect()), "expanded feedback never covers HUD/board/lanes")
		_expect(main.lane_field.get_global_rect().end.y <= canvas.y - 48.0, "portrait layout fits below expanded feedback")
		for label in main.feedback_layer.message_labels:
			_expect(feedback_rect.encloses(label.get_global_rect()), "wrapped Unicode labels remain inside feedback layer")
		_expect(main.feedback_layer.message_labels[3].text.contains("México"), "Unicode expansion preserved")
	main.queue_free()
	await process_frame


func _record(coordinator) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	coordinator.feedback_requested.connect(func(payload: Dictionary): events.append(payload.duplicate(true)))
	return events


func _ids(events: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for payload in events:
		result.append(payload["cue_id"])
	return result


func _count(events: Array[Dictionary], cue: String) -> int:
	return _ids(events).count(cue)


func _points(count: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for index in range(count):
		points.append(Vector2i(index, 0))
	return points


func _dish(amount: float) -> Dictionary:
	return {"ok": true, "satisfaction_final": amount, "special_effect_triggered": false}


func _audio_payload(cue: String, terminal: bool = false) -> Dictionary:
	return {"sound_id": cue, "terminal": terminal}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
