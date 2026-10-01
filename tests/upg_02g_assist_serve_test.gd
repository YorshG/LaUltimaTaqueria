extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
const FIELD = preload("res://scenes/lane/LaneField.tscn")
const MAIN = preload("res://scenes/Main.tscn")

class SeededSelector extends UpgradeSelector:
	var fixture_seed := 0
	func start_run(_seed: int) -> Dictionary:
		return super.start_run(fixture_seed)

# Composition fixture: actual catalog effects, including combinations exceeding
# five slots. Main still evaluates live conditions and consumes warm_welcome.
class EffectsSelector extends UpgradeSelector:
	var fixture_effects: Array = []
	func get_active_effects() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		result.assign(fixture_effects)
		return result

# Simulate eligibility changing at the application boundary, without editing
# MonsterState or relying on timing; its real rejection/clamp still runs.
class RejectingState extends MonsterState:
	func apply_satisfaction(amount: float) -> Dictionary:
		active = false
		return super.apply_satisfaction(amount)

var checks := 0
var failures := 0
var content: Dictionary
var resolver: RecipeResolver

func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "content validates")
	content = loaded["content"]
	resolver = RecipeResolver.new(content)
	_test_resolver()
	await _test_basic_matrix()
	await _test_priority_and_eligibility()
	await _test_selection_after_mutations()
	await _test_rejections()
	await _test_order_and_clamp()
	await _test_composition()
	await _test_r1_synchronous_boss()
	await _test_r2_splash_completes_wave()
	if failures == 0:
		print("UPG-02g tests passed: %d checks; flat splash, D7, R1 and R2." % checks)
	else:
		push_error("UPG-02g tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _effects(ids: Array) -> Array:
	var effects: Array = []
	for id in ids:
		for upgrade in content["upgrades"]:
			if upgrade["id"] == id:
				effects.append({"upgrade_id": id, "effect": upgrade["effect"].duplicate(true)})
	return effects

func _resolution(length: int = 4, assist: bool = true, ingredient: String = "tortilla") -> Dictionary:
	var derived := Modifiers.derive(_effects(["assist_serve"] if assist else []))
	return resolver.resolve(ingredient, length, derived["modifiers"])

func _test_resolver() -> void:
	for assist in [false, true]:
		for length in [3, 4, 5, 8]:
			var result := _resolution(length, assist)
			_expect(result["ok"], "resolver accepts chain %d" % length)
			_expect(result["splash_satisfaction"] == (10.0 if assist and length >= 4 else 0.0), "tier and ownership gate splash")
			_expect(result["satisfaction_final"] == _resolution(length, false)["satisfaction_final"], "splash never mixes into primary")
	for value in [NAN, INF, -INF, "10"]:
		var result := resolver.resolve("tortilla", 4, {"chain4_splash_satisfaction": value})
		_expect(not result["ok"] and result["error"] == RecipeResolver.INVALID_MODIFIERS, "nonfinite/nonnumeric splash rejected")

func _field() -> LaneField:
	var field := FIELD.instantiate() as LaneField
	root.add_child(field)
	await process_frame
	return field

func _spawn(field: LaneField, lane: int = 1, hunger: float = 100.0, progress: float = 0.0) -> LaneRunner:
	var runner := field.spawn_runner(lane, 55.0, "T", "nibbler", hunger)
	runner.auto_advance = false
	runner.motion.progress = progress
	return runner

func _observe(field: LaneField) -> Dictionary:
	var events := {"created": [], "served": [], "satisfied": [], "order": []}
	field.dish_created.connect(func(p: Dictionary): events["created"].append(p))
	field.dish_served.connect(func(p: Dictionary):
		events["served"].append(p)
		events["order"].append("served"))
	field.monster_satisfied.connect(func(p: Dictionary):
		events["satisfied"].append(p)
		events["order"].append(p["spawn_sequence"]))
	return events

func _test_basic_matrix() -> void:
	for assist in [false, true]:
		for length in [3, 4, 5, 8]:
			var field := await _field()
			var primary := _spawn(field, 1, 100.0, 0.9)
			var second := _spawn(field, 1, 100.0, 0.5)
			var events := _observe(field)
			var result := field.resolve_dish(_resolution(length, assist))
			var expected := 10.0 if assist and length >= 4 else 0.0
			_expect(result["ok"] and result["served"]["spawn_sequence"] == primary.monster_state.spawn_sequence, "primary targeting preserved")
			_expect(second.monster_state.hunger_remaining == 100.0 - expected, "secondary receives only flat splash")
			_expect(result["splash"].is_empty() == (expected == 0.0), "empty splash iff not applied")
			_expect(primary.monster_state.hunger_remaining == 100.0 - result["served"]["satisfaction_applied"], "active primary never splashes itself")
			_expect(events["served"].size() == 1 and events["satisfied"].is_empty(), "one service and no false satisfaction")
			_expect(not events["created"][0].has("splash") and not events["created"][0].has("splash_satisfaction"), "dish_created contract unchanged")
			_expect(events["served"][0].size() == 4 and not events["served"][0].has("splash"), "dish_served payload unchanged")
			field.queue_free()
			await process_frame
	for other_lane in [-1, 0, 2]:
		var field := await _field()
		_spawn(field, 1, 100.0, 0.9)
		var other: LaneRunner = null
		if other_lane >= 0:
			other = _spawn(field, other_lane, 100.0, 0.8)
		var result := field.resolve_dish(_resolution())
		_expect(result["splash"] == {}, "single target or other lane means no splash")
		if other != null:
			_expect(other.monster_state.hunger_remaining == 100.0, "other lane untouched")
		field.queue_free()
		await process_frame
	var empty := await _field()
	_expect(empty.resolve_dish(_resolution())["splash"] == {}, "no primary returns empty splash")
	empty.queue_free()
	await process_frame

func _test_priority_and_eligibility() -> void:
	var field := await _field()
	var primary := _spawn(field, 1, 1.0, 0.95)
	var other_lane := _spawn(field, 0, 100.0, 0.94)
	var inactive := _spawn(field, 1, 100.0, 0.93)
	inactive.monster_state.active = false
	var satisfied := _spawn(field, 1, 1.0, 0.92)
	satisfied.monster_state.apply_satisfaction(1.0)
	_spawn(field, 1, 100.0, 1.0)
	var freed := _spawn(field, 1, 100.0, 0.91)
	freed.free()
	var farther := _spawn(field, 1, 100.0, 0.2)
	var older := _spawn(field, 1, 100.0, 0.6)
	var newer := _spawn(field, 1, 100.0, 0.6)
	var result := field.resolve_dish(_resolution())
	_expect(primary.monster_state.satisfied, "primary becomes satisfied first")
	_expect(result["splash"].get("spawn_sequence", -1) == older.monster_state.spawn_sequence, "nearest valid with spawn-order tie break")
	_expect(older.monster_state.hunger_remaining == 90.0, "correct runner receives 10")
	for runner in [other_lane, inactive, farther, newer]:
		_expect(runner.monster_state.hunger_remaining == 100.0, "nonselected runner unchanged")
	field.queue_free()
	await process_frame

func _test_selection_after_mutations() -> void:
	# Real synchronous MonsterState phase signal changes the best candidate during
	# the primary's special burst. Preselecting even a still-valid runner fails.
	var field := await _field()
	var primary := _spawn(field, 1, 100.0, 0.9)
	var before := _spawn(field, 1, 100.0, 0.6)
	var after := _spawn(field, 1, 100.0, 0.2)
	primary.monster_state.configure_phases([
		{"threshold": 1.0}, {"threshold": 0.4}])
	primary.monster_state.phase_changed.connect(func(_p: Dictionary): after.motion.progress = 0.8)
	var result := field.resolve_dish(_resolution(5, true, "meat"))
	_expect(primary.monster_state.phase_index == 1, "special burst crosses phase threshold")
	_expect(result["splash"].get("spawn_sequence", -1) == after.monster_state.spawn_sequence, "selection occurs after primary special mutation")
	_expect(before.monster_state.hunger_remaining == 100.0 and after.monster_state.hunger_remaining == 90.0, "pre-mutation candidate untouched")
	field.queue_free()
	await process_frame
	# Invalidation during primary mutation must also exclude that runner.
	field = await _field()
	primary = _spawn(field, 1, 100.0, 0.9)
	before = _spawn(field, 1, 100.0, 0.6)
	after = _spawn(field, 1, 100.0, 0.2)
	primary.monster_state.configure_phases([{"threshold": 1.0}, {"threshold": 0.8}])
	primary.monster_state.phase_changed.connect(func(_p: Dictionary): before.monster_state.active = false)
	result = field.resolve_dish(_resolution())
	_expect(result["splash"].get("spawn_sequence", -1) == after.monster_state.spawn_sequence, "invalidated candidate skipped after primary mutation")
	_expect(before.monster_state.hunger_remaining == 100.0, "invalidated candidate not mutated")
	field.queue_free()
	await process_frame

func _test_rejections() -> void:
	var field := await _field()
	var primary := _spawn(field, 1, 100.0, 0.9)
	var second := _spawn(field, 1, 100.0, 0.5)
	var events := _observe(field)
	_expect(field.resolve_dish({"ok": false})["splash"] == {}, "failed resolution has empty splash")
	field.dish_created.connect(func(_p: Dictionary): primary.monster_state.active = false, CONNECT_ONE_SHOT)
	var result := field.resolve_dish(_resolution())
	_expect(not result["ok"] and result["splash"] == {}, "rejected primary cannot splash")
	_expect(second.monster_state.hunger_remaining == 100.0 and events["served"].is_empty(), "primary failure has no service or secondary mutation")
	primary.monster_state.active = true
	second.monster_state = RejectingState.new("nibbler", 1, 100.0, second.monster_state.spawn_sequence)
	result = field.resolve_dish(_resolution())
	_expect(result["ok"] and result["splash"] == {}, "secondary rejection leaves primary successful")
	_expect(second.monster_state.hunger_remaining == 100.0 and events["satisfied"].is_empty(), "secondary rejection cannot fake satisfaction")
	second.monster_state = MonsterState.new("nibbler", 1, 100.0, second.monster_state.spawn_sequence)
	for length in [0, 3]:
		primary.monster_state = MonsterState.new("nibbler", 1, 100.0, primary.monster_state.spawn_sequence)
		var malformed := _resolution()
		malformed["chain_length"] = length
		_expect(field.resolve_dish(malformed)["splash"] == {}, "LaneField independently gates chain length")
		_expect(second.monster_state.hunger_remaining == 100.0, "chain guard prevents secondary mutation")
	for amount in [0.0, -10.0, NAN, INF]:
		primary.monster_state = MonsterState.new("nibbler", 1, 100.0, primary.monster_state.spawn_sequence)
		var malformed := _resolution()
		malformed["splash_satisfaction"] = amount
		_expect(field.resolve_dish(malformed)["splash"] == {}, "LaneField ignores nonpositive/nonfinite splash")
		_expect(second.monster_state.hunger_remaining == 100.0, "invalid splash cannot corrupt hunger")
	field.queue_free()
	await process_frame

func _test_order_and_clamp() -> void:
	var field := await _field()
	var primary := _spawn(field, 1, 1.0, 0.9)
	var second := _spawn(field, 1, 7.0, 0.5)
	var events := _observe(field)
	field.dish_served.connect(func(_p: Dictionary):
		_expect(primary.monster_state.satisfied and second.monster_state.satisfied, "all mutations precede dish_served"))
	field.monster_satisfied.connect(func(_p: Dictionary):
		_expect(second.monster_state.hunger_remaining == 0.0, "all mutations precede monster_satisfied"))
	var result := field.resolve_dish(_resolution())
	_expect(result["splash"] == {
		"spawn_sequence": second.monster_state.spawn_sequence, "lane": 1,
		"monster_id": "nibbler", "satisfaction_requested": 10.0,
		"satisfaction_applied": 7.0, "hunger_remaining_after": 0.0,
		"monster_became_satisfied": true}, "additive return records requested versus clamped actual satisfaction")
	_expect(events["order"] == ["served", primary.monster_state.spawn_sequence, second.monster_state.spawn_sequence], "D7 exact signal order, one service and each satisfaction once")
	field.resolve_dish(_resolution())
	_expect(events["satisfied"].size() == 2, "repeat cannot satisfy retired secondary twice")
	field.queue_free()
	await process_frame

func _main(selector_script: Script, effects: Array = []):
	var main = MAIN.instantiate()
	var selector = main.get_node("%UpgradeSelector")
	selector.set_script(selector_script)
	if selector is EffectsSelector:
		selector.fixture_effects = effects
	root.add_child(main)
	await process_frame
	main.wave_director.auto_advance = false
	main.wave_director.monster_spawned.connect(func(p: Dictionary):
		main.wave_director.get_spawned_runner(p["spawn_sequence"]).auto_advance = false)
	main.boss_started.connect(func(_p: Dictionary): main.boss_runner.auto_advance = false)
	return main

func _serve(main, ingredient: String, length: int = 5) -> Dictionary:
	var points: Array[Vector2i] = []
	for i in range(length):
		points.append(Vector2i(i % 5, i / 5))
	return main._on_chain_completed(points, ingredient)

func _test_composition() -> void:
	var combinations := [
		["assist_serve"],
		["assist_serve", "taco_power_1", "chain4_boost"],
		["assist_serve", "taco_power_2", "warm_welcome", "last_stand", "chain5_effect_boost"],
		["assist_serve", "taco_power_1", "taco_power_2", "chain4_boost", "warm_welcome", "last_stand", "chain5_effect_boost"],
	]
	for ids in combinations:
		for ingredient in ["tortilla", "meat", "veggie"]:
			var main = await _main(EffectsSelector, _effects(ids))
			main.wave_director.start_wave("wave_01", 0.0)
			main.wave_director.advance(2.0)
			main.reputation.apply_damage(81.0)
			var primary := _spawn(main.lane_field, 1, 10000.0, 0.9)
			var second := _spawn(main.lane_field, 1, 10000.0, 0.8)
			var events := _observe(main.lane_field)
			var reputation_events: Array = []
			main.reputation.reputation_changed.connect(func(p: Dictionary): reputation_events.append(p))
			var result := _serve(main, ingredient)
			_expect(result["splash"]["satisfaction_requested"] == 10.0 and result["splash"]["satisfaction_applied"] == 10.0, "all modifier combinations preserve exact flat 10")
			_expect(second.monster_state.hunger_remaining == 9990.0 and second.motion.stun_remaining_sec == 0.0, "secondary receives no special burst or stun")
			var power := 1.3 if "chain5_effect_boost" in ids else 1.0
			var expected_primary := float(result["dish"]["satisfaction_final"]) + (12.0 * power if ingredient == "meat" else 0.0)
			_expect(is_equal_approx(result["served"]["satisfaction_applied"], expected_primary), "primary alone receives special burst")
			_expect(primary.motion.stun_remaining_sec == (power if ingredient == "tortilla" else 0.0), "primary alone receives special stun")
			_expect(is_equal_approx(main.reputation.current, 19.0 + (5.0 * power if ingredient == "veggie" else 0.0)), "one veggie restore only; splash grants none")
			_expect(reputation_events.size() == (1 if ingredient == "veggie" else 0), "no additional global restoration event")
			_expect(events["served"].size() == 1 and not main._first_dish_pending, "Main sees one service and consumes first dish once")
			var next := _serve(main, ingredient)
			var ratio := 2.0 if "warm_welcome" in ids else 1.0
			if ingredient == "veggie" and "last_stand" in ids:
				ratio *= 1.25
			_expect(is_equal_approx(result["dish"]["satisfaction_final"], next["dish"]["satisfaction_final"] * ratio), "next primary reevaluates conditions without extra warm consumption")
			_expect(next["splash"]["satisfaction_applied"] == 10.0, "next splash remains flat")
			main.queue_free()
			await process_frame

func _test_r1_synchronous_boss() -> void:
	var main = await _main(SeededSelector)
	var inside := {"resolve": false, "spawned_inside": false}
	main.boss_started.connect(func(_p: Dictionary): inside["spawned_inside"] = inside["resolve"])
	# Main's listener offers first; this real fifth choice spawns the boss in the
	# same call stack as the last wave_05 monster_satisfied, before resolve returns.
	main.wave_director.wave_completed.connect(func(_p: Dictionary):
		var offer: Array = main.upgrade_selector.get_current_offer()
		var chosen: String = offer[0]["id"]
		for option in offer:
			if option["id"] == "assist_serve":
				chosen = "assist_serve"
		_expect(main.upgrade_selector.select_upgrade(chosen)["ok"], "R1 real synchronous selection succeeds"))
	for wave_index in range(5):
		_expect(main.wave_director.start_wave("wave_%02d" % (wave_index + 1), 0.0)["ok"], "R1 real wave starts")
		main.wave_director.advance(1000.0)
		# Leave a central-lane monster for last so a premature boss is eligible.
		var last: LaneRunner = null
		for runner in main.lane_field._runners:
			if runner.is_targetable() and runner.monster_state.lane == 1:
				last = runner
		_expect(last != null, "R1 central lane final target exists")
		last.motion.progress = 0.0
		for runner in main.lane_field._runners:
			if runner != last and runner.is_targetable():
				runner.motion.progress = 0.5
		while main.wave_director.get_pending_count() > 1:
			main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 10000.0})
		last.monster_state.apply_satisfaction(last.monster_state.hunger_remaining - 1.0)
		if wave_index == 4:
			_expect("assist_serve" in main.upgrade_selector.get_selected_upgrade_ids(), "R1 assist owned before final wave service")
			_expect(not main.boss_has_started, "R1 boss absent before last service")
		inside["resolve"] = true
		var result := _serve(main, "tortilla", 4)
		inside["resolve"] = false
		_expect(result["splash"] == {}, "R1 last normal service cannot splash newly spawned boss")
	_expect(inside["spawned_inside"] and main.boss_has_started, "R1 fifth choice spawned boss inside resolve_dish")
	_expect(main.upgrade_selector.get_selection_count() == 5, "R1 all five real choices completed")
	_expect(main.boss_runner.monster_state.hunger_remaining == main.boss_runner.monster_state.hunger_max, "R1 boss retains full hunger after resolve returns")
	_expect(main.boss_runner.monster_state.hunger_remaining == 300.0, "R1 boss begins at 300")
	main.queue_free()
	await process_frame

func _test_r2_splash_completes_wave() -> void:
	var field := await _field()
	var director := WaveDirector.new()
	director.auto_advance = false
	root.add_child(director)
	var fixture := content.duplicate(true)
	fixture["waves"] = [{"id": "wave_05", "duration_target_sec": 30.0, "spawns": [
		{"monster_id": "nibbler", "lane": 1, "at_sec": 0.0},
		{"monster_id": "nibbler", "lane": 1, "at_sec": 0.0}]}]
	_expect(director.configure(fixture, field)["ok"], "R2 real WaveDirector configured")
	director.start_wave("wave_05", 0.0)
	var primary := director.get_spawned_runner(1)
	var second := director.get_spawned_runner(2)
	primary.auto_advance = false
	second.auto_advance = false
	primary.motion.progress = 0.9
	second.monster_state.apply_satisfaction(second.monster_state.hunger_remaining - 7.0)
	var events := _observe(field)
	var completions: Array = []
	var primary_observation: Array = []
	director.wave_completed.connect(func(p: Dictionary): completions.append(p))
	field.monster_satisfied.connect(func(p: Dictionary):
		if p["spawn_sequence"] == 1:
			primary_observation.append(director.get_pending_count())
			_expect(director.state == WaveDirector.State.AWAITING_RESOLUTION, "R2 primary alone cannot complete wave"))
	var result := field.resolve_dish(_resolution())
	_expect(result["splash"]["monster_became_satisfied"], "R2 splash satisfied second")
	_expect(primary_observation == [1], "R2 primary leaves secondary pending until its signal")
	_expect(events["order"] == ["served", 1, 2], "R2 exactly one secondary satisfaction after primary")
	_expect(director.get_resolved_count() == 2 and director.get_pending_count() == 0, "R2 WaveDirector accounts for both")
	_expect(director.state == WaveDirector.State.COMPLETED, "R2 wave reaches COMPLETED")
	_expect(completions.size() == 1 and completions[0]["satisfied_count"] == 2, "R2 one completion with two satisfied monsters")
	director.queue_free()
	field.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
