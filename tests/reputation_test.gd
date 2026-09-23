extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const Reputation = preload("res://scripts/session/reputation_state.gd")
const MAIN_SCENE = preload("res://scenes/Main.tscn")

var failures := 0
var content: Dictionary


func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "UI-01 requires validated content")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	_test_state()
	_test_content_and_replay()
	await _test_breach_and_hud()
	await _test_restore_bridge()
	await _test_terminal_wave()
	await _test_boss_endings()
	await _test_hud_layout()
	if failures == 0:
		print("UI-01 tests passed: reputation, content damage, duplicate breaches, veggie service, terminal defeat, HUD, boss endings.")
		quit(0)
	else:
		push_error("UI-01 tests failed: %d" % failures)
		quit(1)


func _test_state() -> void:
	var state := Reputation.new(content)
	_expect(state.snapshot() == {"current": 100.0, "maximum": 100.0, "defeated": false}, "starts at 100 / 100")
	for invalid in [-1.0, 0.0, INF, NAN]:
		_expect(not state.apply_damage(invalid)["ok"], "invalid damage rejected")
		_expect(not state.restore(invalid)["ok"], "invalid restore rejected")
	_expect(state.current == 100.0, "invalid values leave state intact")
	state.apply_damage(3.0)
	var restored := state.restore(5.0)
	_expect(state.current == 100.0 and restored["delta"] == 3.0, "restoration clamps and reports actual delta")
	var endings: Array[Dictionary] = []
	state.run_ended.connect(func(payload: Dictionary): endings.append(payload))
	var result := state.apply_damage(1000.0)
	_expect(result["transitioned_to_defeat"] and state.current == 0.0, "overkill clamps to zero")
	_expect(result["before"] == 100.0 and result["delta"] == -100.0, "damage reports actual change")
	state.apply_damage(1.0)
	state.restore(5.0)
	_expect(endings.size() == 1 and state.current == 0.0, "defeat is terminal and emitted once")
	_expect(endings[0]["outcome"] == "defeat" and endings[0]["reason"] == "reputation_depleted", "defeat payload explains ending")


func _test_content_and_replay() -> void:
	var alternate := content.duplicate(true)
	for index in range(alternate["monsters"].size()):
		alternate["monsters"][index]["reputation_damage"] = 7 + index
	alternate["boss"]["reputation_damage_on_breach"] = 19
	alternate["ingredients"][2]["special_effect_params"]["amount"] = 9
	var validated := Registry.new().validate_content(alternate)
	_expect(validated["ok"], "alternate damage and restore fixture remains valid content")
	var first := Reputation.new(validated["content"])
	var replay := Reputation.new(validated["content"])
	var monsters: Array = alternate["monsters"].duplicate(true)
	monsters.append(alternate["boss"])
	for index in range(monsters.size()):
		var monster: Dictionary = monsters[index]
		var payload := {"monster_id": monster["id"], "spawn_sequence": index + 1}
		var result := first.apply_breach(payload)
		_expect(result == replay.apply_breach(payload), "identical inputs reproduce full payloads")
		var damage := float(monster.get("reputation_damage", monster.get("reputation_damage_on_breach", 0)))
		_expect(result["delta"] == -damage, "every damage amount comes from supplied validated content")
		_expect(not first.apply_breach(payload)["ok"], "duplicate sequence is rejected")
	var resolved := RecipeResolver.new(alternate).resolve("veggie", 5)
	var result := first.apply_served_dish(resolved, {"ok": true, "target_found": true, "served": {"spawn_sequence": 5}})
	_expect(result["delta"] == 9.0, "restore magnitude comes from resolver content")
	var before := first.current
	first.apply_breach({"monster_id": "missing", "spawn_sequence": 99})
	first.apply_breach({"monster_id": "nibbler"})
	_expect(first.current == before, "unknown or incomplete breach cannot damage")
	# Reentrant listeners cannot replay the same breach during reputation_changed.
	var reentrant := Reputation.new(content)
	var breach := {"monster_id": "nibbler", "spawn_sequence": 1}
	var repeat_breach := func(_payload: Dictionary): reentrant.apply_breach(breach)
	reentrant.reputation_changed.connect(repeat_breach)
	reentrant.apply_breach(breach)
	_expect(reentrant.current == 90.0, "reentrant breach is applied exactly once")
	reentrant.reputation_changed.disconnect(repeat_breach)


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


func _spawn(main, monster_id: String) -> LaneRunner:
	var runner: LaneRunner = main.lane_field.spawn_runner(1, 50.0, "M", monster_id, 1000.0)
	runner.auto_advance = false
	return runner


func _test_breach_and_hud() -> void:
	var main = await _create_main()
	_expect(main.hud.reputation_label.text == "Reputación 100 / 100", "HUD initializes from state")
	var endings: Array[Dictionary] = []
	main.run_ended.connect(func(payload: Dictionary): endings.append(payload))
	var ids := ["nibbler", "salsa_tank", "swift_hopper", "boss_big_glutton"]
	var expected := [90.0, 65.0, 50.0, 10.0]
	for index in range(ids.size()):
		var runner := _spawn(main, ids[index])
		runner.advance(1000.0)
		_expect(main.reputation.current == expected[index], "%s uses expected content damage" % ids[index])
		main.lane_field.monster_reached_counter.emit({"monster_id": ids[index], "spawn_sequence": runner.monster_state.spawn_sequence})
		_expect(main.reputation.current == expected[index], "repeated lane signal cannot damage twice")
		_expect(main.hud.reputation_bar.value == expected[index], "HUD bar follows breach")
		_expect(main.hud.reputation_label.text == "Reputación %d / 100" % expected[index], "HUD text follows breach")
	var last := _spawn(main, "nibbler")
	last.advance(1000.0)
	_expect(endings.size() == 1 and main.reputation.defeated, "exact zero ends Main once")
	_expect(main.hud.outcome_label.text == "Derrota — reputación agotada" and main.hud.outcome_label.visible, "HUD explicitly presents defeat")
	_expect(main.hud.reputation_bar.value == 0.0, "defeat bar is empty")
	_expect(not main.can_process() and not main.board_view.can_process() and not main.lane_field.can_process(), "defeat disables gameplay processing and input")
	main.reputation.restore(100.0)
	main.lane_field.monster_reached_counter.emit({"monster_id": "nibbler", "spawn_sequence": 100})
	var service: Dictionary = main._on_chain_completed(_points(5), "veggie")
	_expect(not service["ok"] and main.reputation.current == 0.0 and endings.size() == 1, "late events cannot revive or repeat defeat")
	main.queue_free()
	await process_frame


func _test_restore_bridge() -> void:
	var main = await _create_main()
	main.reputation.apply_damage(30.0)
	main.board_view.chain_completed.emit(_points(5), "veggie")
	_expect(main.reputation.current == 70.0, "5+ with no target cannot restore")
	var target := _spawn(main, "salsa_tank")
	for length in [3, 4]:
		main.board_view.chain_completed.emit(_points(length), "veggie")
		_expect(main.reputation.current == 70.0, "3/4 chain cannot restore")
	main.board_view.chain_completed.emit(_points(5), "tortilla")
	_expect(main.reputation.current == 70.0, "other effects cannot restore")
	main.board_view.chain_completed.emit(_points(5), "veggie")
	_expect(main.reputation.current == 75.0, "successful veggie 5+ restores five")
	_expect(main.hud.reputation_label.text == "Reputación 75 / 100" and main.hud.reputation_bar.value == 75.0, "HUD follows restoration")
	main.reputation.restore(23.0)
	main.board_view.chain_completed.emit(_points(6), "veggie")
	_expect(main.reputation.current == 100.0, "6+ also restores and caps at maximum")
	main.reputation.apply_damage(10.0)
	var resolution: Dictionary = main.recipe_resolver.resolve("veggie", 5)
	main.reputation.apply_served_dish(resolution, {"ok": false, "target_found": true, "served": {"spawn_sequence": 1}})
	_expect(main.reputation.current == 90.0, "failed service with a target cannot restore")
	target.monster_state.apply_satisfaction(1000.0)
	main.board_view.chain_completed.emit(_points(5), "veggie")
	_expect(main.reputation.current == 90.0, "retired target cannot restore")
	main.queue_free()
	await process_frame


func _test_terminal_wave() -> void:
	var main = await _create_main()
	main.wave_director.start_wave("wave_01", 0.0)
	main.wave_director.advance(1000.0)
	while main.wave_director.get_pending_count() > 1:
		main.lane_field.resolve_dish(_dish())
	main.reputation.apply_damage(99.0)
	main.lane_field.select_nearest_target().advance(1000.0)
	_expect(main.wave_director.state == WaveDirector.State.COMPLETED, "lethal last breach still resolves wave")
	_expect(main.upgrade_selector.get_current_offer().is_empty(), "lethal last breach cannot offer an upgrade before defeat")
	main.queue_free()
	await process_frame


func _test_boss_endings() -> void:
	for ending in ["satisfied", "breach", "lethal_breach"]:
		var main = await _create_main()
		for wave in content["waves"]:
			main.wave_director.start_wave(str(wave["id"]), 0.0)
			main.wave_director.advance(1000.0)
			for _spawn_entry in wave["spawns"]:
				main.lane_field.resolve_dish(_dish())
			var offer: Array = main.upgrade_selector.get_current_offer()
			main.upgrade_selector.select_upgrade(str(offer[0]["id"]))
		var completions: Array[Dictionary] = []
		main.boss_encounter_completed.connect(func(payload: Dictionary): completions.append(payload))
		if ending == "satisfied":
			main.reputation.apply_damage(10.0)
			main.boss_runner.monster_state.apply_satisfaction(299.0)
			main.board_view.chain_completed.emit(_points(5), "veggie")
			_expect(main.reputation.current == 95.0, "dish satisfying boss still restores reputation")
			_expect(main.hud.outcome_label.text == "Victoria" and main.hud.outcome_label.visible, "satisfied boss shows provisional victory")
		else:
			if ending == "lethal_breach":
				main.reputation.apply_damage(70.0)
			main.boss_runner.advance(1000.0)
			var expected := 0.0 if ending == "lethal_breach" else 60.0
			_expect(main.reputation.current == expected, "boss damage applies once and clamps")
			_expect(main.hud.outcome_label.visible == (ending == "lethal_breach"), "nonlethal boss breach does not invent victory or defeat")
		var payload := {"monster_id": content["boss"]["id"], "spawn_sequence": main.boss_runner.monster_state.spawn_sequence}
		if ending == "satisfied":
			main.lane_field.monster_satisfied.emit(payload)
		else:
			main.lane_field.monster_reached_counter.emit(payload)
		_expect(completions.size() == 1 and not main.boss_encounter_active, "BOSS-01 closes exactly once, including lethal breach")
		_expect(completions[0]["satisfied"] == (ending == "satisfied"), "BOSS-01 completion keeps outcome")
		main.queue_free()
		await process_frame


func _test_hud_layout() -> void:
	var main = await _create_main()
	# Equivalent portrait canvas ratios; font override exercises larger Unicode text.
	main.hud.reputation_format = "Reputación de la taquería — México: %s / %s"
	main.hud.reputation_label.add_theme_font_size_override("font_size", 64)
	main.reputation.apply_damage(1.0)
	main.hud.show_outcome("defeat")
	for canvas in [Vector2(1080, 1920), Vector2(1080, 1620), Vector2(1080, 2400)]:
		main.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		main.size = canvas
		for _frame in range(4):
			await process_frame
		var hud_rect: Rect2 = main.hud.get_global_rect()
		var board_rect: Rect2 = main.board_view.get_global_rect()
		var lanes_rect: Rect2 = main.lane_field.get_global_rect()
		_expect(hud_rect.position.x >= 24.0 and hud_rect.position.y >= 48.0, "HUD remains in existing safe margins")
		_expect(hud_rect.end.x <= canvas.x - 24.0, "expanded text fits horizontal margins")
		_expect(not hud_rect.intersects(board_rect) and not hud_rect.intersects(lanes_rect), "HUD never covers board or lanes")
		_expect(lanes_rect.end.y <= canvas.y - 48.0, "content remains inside bottom margin")
		_expect(main.hud.reputation_label.text.contains("México: 99 / 100"), "expanded Unicode label preserves values")
	main.queue_free()
	await process_frame


func _points(count: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for index in range(count):
		points.append(Vector2i(index % 5, index / 5))
	return points


func _dish() -> Dictionary:
	return {"ok": true, "satisfaction_final": 1000.0, "special_effect_triggered": false}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
