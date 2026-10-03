extends SceneTree

const FIELD = preload("res://scenes/lane/LaneField.tscn")
const MAIN = preload("res://scenes/Main.tscn")
const Registry = preload("res://scripts/content/content_registry.gd")
var checks := 0
var failures := 0
var content: Dictionary

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	content = Registry.new().load_and_validate()["content"]
	await _primary_and_breach()
	await _splash_and_wave()
	await _nested_resolution()
	await _observer_removes_runner()
	await _boss(false)
	await _boss(true)
	await _stress()
	print("VIS-01 %s: %d checks; primary/breach, D7 splash, nested listeners, five waves, both boss outcomes, 100x12 stress." % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _field() -> LaneField:
	var field := FIELD.instantiate() as LaneField
	root.add_child(field)
	return field

func _spawn(field: LaneField, lane: int = 1, hunger: float = 30.0, id: String = "nibbler") -> LaneRunner:
	var runner := field.spawn_runner(lane, 55.0, "M", id, hunger)
	runner.auto_advance = false
	return runner

func _dish(amount: float, splash: float = 0.0) -> Dictionary:
	return {"ok": true, "satisfaction_final": amount, "chain_length": 4, "splash_satisfaction": splash}

func _live_during_listener(runner: LaneRunner, label: String) -> void:
	_expect(is_instance_valid(runner), "VIS_LISTENER_VALID " + label)
	if is_instance_valid(runner):
		_expect(runner.visible and runner.is_inside_tree() and not runner.is_queued_for_deletion(), "VIS_LISTENER_VISIBLE " + label)

func _retired_now(runner: LaneRunner, label: String) -> void:
	_expect(is_instance_valid(runner), "VIS_DEFERRED " + label)
	if is_instance_valid(runner):
		_expect(not runner.visible and not runner.is_visible_in_tree(), "VIS_HIDDEN " + label)
		_expect(runner.is_queued_for_deletion() and runner.process_mode == Node.PROCESS_MODE_DISABLED, "VIS_QUEUED " + label)
		_expect(not runner.is_targetable(), "VIS_NO_TARGET " + label)

func _settle() -> void:
	await process_frame
	await process_frame

func _primary_and_breach() -> void:
	var field := _field()
	var runner := _spawn(field)
	var state := runner.monster_state
	field.resolve_dish(_dish(1.0))
	_expect(runner.visible and not runner.is_queued_for_deletion() and runner.is_targetable(), "partial service remains visible and eligible")
	var events: Array = []
	field.dish_served.connect(func(_p):
		events.append("served")
		_live_during_listener(runner, "primary served"))
	field.monster_satisfied.connect(func(_p):
		events.append("satisfied")
		_live_during_listener(runner, "primary satisfied")
		_expect(not state.active and state.satisfied and state.hunger_remaining == 0.0, "listeners see final logical state"))
	var result := field.resolve_dish(_dish(100.0))
	_expect(result["monster_became_satisfied"] and events == ["served", "satisfied"], "VIS_ONCE primary exact service and satisfaction")
	_retired_now(runner, "primary")
	_expect(not field.resolve_dish(_dish(100.0))["target_found"], "resolved primary never retargeted before deletion")
	await _settle()
	_expect(not is_instance_valid(runner) and field._runners.is_empty() and _runner_count(field) == 0, "VIS_FREED primary and ownership removed")
	field.free()
	field = _field()
	runner = _spawn(field, 0)
	var breaches: Array = []
	field.monster_reached_counter.connect(func(p):
		breaches.append(p)
		_live_during_listener(runner, "breach")
		_expect(not runner.monster_state.active and not runner.monster_state.satisfied, "breach preserves unsatisfied outcome"))
	runner.advance(1000.0)
	_retired_now(runner, "breach")
	runner.advance(1000.0)
	_expect(breaches.size() == 1, "VIS_ONCE repeated advance cannot breach twice")
	await _settle()
	_expect(not is_instance_valid(runner) and field._runners.is_empty(), "VIS_FREED breach")
	field.free()

func _splash_and_wave() -> void:
	var field := _field()
	var director := WaveDirector.new()
	root.add_child(director)
	director.auto_advance = false
	var fixture := content.duplicate(true)
	fixture["waves"] = [{"id": "vis_wave", "duration_target_sec": 1.0, "spawns": [
		{"at_sec": 0.0, "monster_id": "nibbler", "lane": 1},
		{"at_sec": 0.0, "monster_id": "nibbler", "lane": 1}]}]
	director.configure(fixture, field)
	director.start_wave("vis_wave", 0.0)
	var primary := director.get_spawned_runner(1)
	var secondary := director.get_spawned_runner(2)
	primary.auto_advance = false
	secondary.auto_advance = false
	primary.motion.progress = 0.8
	secondary.motion.progress = 0.4
	secondary.monster_state.apply_satisfaction(secondary.monster_state.hunger_remaining - 7.0)
	var order: Array = []
	var completed: Array = []
	director.wave_completed.connect(func(p): completed.append(p))
	field.dish_served.connect(func(_p):
		order.append("served")
		_live_during_listener(primary, "D7 primary")
		_live_during_listener(secondary, "D7 secondary")
		_expect(secondary.monster_state.hunger_remaining == 0.0, "D7 secondary mutation precedes service"))
	field.monster_satisfied.connect(func(p):
		order.append(p.spawn_sequence)
		_live_during_listener(primary, "D7 satisfaction primary")
		_live_during_listener(secondary, "D7 satisfaction secondary"))
	var result := field.resolve_dish(_dish(1000.0, 10.0))
	_expect(order == ["served", 1, 2], "VIS_ONCE D7 served/primary/secondary order")
	_expect(result["splash"]["satisfaction_applied"] == 7.0 and completed.size() == 1, "D7 splash clamp and one completion preserved")
	_retired_now(primary, "splash primary")
	_retired_now(secondary, "splash secondary")
	await _settle()
	_expect(director.get_spawned_count() == 2 and director.get_resolved_count() == 2 and director.get_pending_count() == 0, "wave counts survive visual cleanup")
	_expect(director.get_spawned_runner(1) == null and director.get_spawned_runner(2) == null, "freed runner lookup safely returns null")
	_expect(field._runners.is_empty() and _runner_count(field) == 0, "VIS_FREED splash pair")
	director.free()
	field.free()

func _nested_resolution() -> void:
	var field := _field()
	var primary := _spawn(field, 1, 10.0)
	var second := _spawn(field, 0, 10.0)
	field.dish_served.connect(func(p):
		if p.spawn_sequence == primary.monster_state.spawn_sequence:
			field.resolve_dish(_dish(10.0))
			_live_during_listener(primary, "outer target after nested service"))
	field.resolve_dish(_dish(10.0))
	_retired_now(primary, "nested primary")
	_retired_now(second, "nested second")
	await _settle()
	_expect(field._runners.is_empty(), "nested cleanup cannot leave residuals")
	field.free()

func _boss(breach: bool) -> void:
	var main = MAIN.instantiate()
	for property in main.get_property_list():
		if property.name == "auto_start_run": main.set("auto_start_run", false)
	root.add_child(main)
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(p): main.wave_director.get_spawned_runner(p.spawn_sequence).auto_advance = false)
	main.boss_started.connect(func(_p): main.boss_runner.auto_advance = false)
	for index in range(5):
		main.wave_director.start_wave("wave_%02d" % (index + 1), 0.0)
		main.wave_director.advance(1000.0)
		while main.wave_director.get_pending_count() > 0:
			main.lane_field.resolve_dish(_dish(10000.0))
		await _settle()
		_expect(_runner_count(main.lane_field) == 0 and main.lane_field._runners.is_empty(), "VIS_FREED wave %d before next selection" % (index + 1))
		main.upgrade_selector.select_upgrade(main.upgrade_selector.get_current_offer()[0].id)
	var boss: LaneRunner = main.boss_runner
	var completions: Array = []
	main.boss_encounter_completed.connect(func(p):
		completions.append(p)
		_live_during_listener(boss, "boss terminal payload")
		_expect(p.satisfied == (not breach), "boss outcome unchanged"))
	if breach: boss.advance(1000.0)
	else: main.lane_field.resolve_dish(_dish(10000.0))
	_retired_now(boss, "VIS_BOSS")
	_expect(completions.size() == 1 and not main.boss_encounter_active, "boss completion remains unique")
	await _settle()
	_expect(not is_instance_valid(boss) and main.lane_field._runners.is_empty() and _runner_count(main.lane_field) == 0, "VIS_BOSS_FREED after terminal, including disabled Main")
	main.free()

func _observer_removes_runner() -> void:
	var field := _field()
	var runner_id: int = _spawn(field).get_instance_id()
	var satisfied: Array = []
	field.dish_served.connect(func(_p): instance_from_id(runner_id).free())
	field.monster_satisfied.connect(func(p): satisfied.append(p))
	var result := field.resolve_dish(_dish(1000.0))
	_expect(result["ok"] and satisfied.size() == 1, "observer removal preserves already captured result/payload")
	_expect(field._runners.is_empty() and _runner_count(field) == 0, "observer removal leaves no ownership or stale retirement call")
	await _settle()
	field.free()

func _stress() -> void:
	var field := _field()
	var base_nodes := _node_count(field)
	for cycle in range(100):
		for index in range(12):
			var runner := _spawn(field, index % 3, 10.0)
			if index % 2 == 0: field.resolve_dish(_dish(100.0))
			else: runner.advance(1000.0)
		await _settle()
		_expect(_node_count(field) == base_nodes and field._runners.is_empty(), "VIS_STRESS no node/ownership growth at cycle %d" % cycle)
	print("VIS_STRESS settled nodes=%d across 100 cycles / 1200 runners" % base_nodes)
	field.free()

func _runner_count(field: LaneField) -> int:
	var count := 0
	for host in field.lane_hosts: count += host.get_child_count()
	return count

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += _node_count(child)
	return count

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("VIS_ASSERT: " + message)
