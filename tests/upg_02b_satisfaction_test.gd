extends SceneTree

const Registry = preload("res://scripts/content/content_registry.gd")
const Resolver = preload("res://scripts/recipes/recipe_resolver.gd")
const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
const Selector = preload("res://scripts/upgrades/upgrade_selector.gd")
const MAIN = preload("res://scenes/Main.tscn")

# Fault injection only: real selection scenarios below use the public selector.
class InvalidEffectsSelector extends Selector:
	func get_active_effects() -> Array[Dictionary]:
		return [{"upgrade_id": "broken", "effect": {}}]


class InvalidModifiersResolver extends Resolver:
	var injected

	func resolve(ingredient_id: String, chain_length: int, _modifiers = {}) -> Dictionary:
		return super.resolve(ingredient_id, chain_length, injected)


var failures := 0
var checks := 0
var content: Dictionary


func _init() -> void:
	var loaded := Registry.new().load_and_validate()
	_expect(loaded["ok"], "real content must validate")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	_test_arithmetic_and_isolation()
	_test_invalid_modifiers()
	await _test_main_public_selection()
	await _test_deferred_conditionals()
	await _test_main_failures_are_atomic()
	if failures == 0:
		print("UPG-02b tests passed: %d checks; D4 arithmetic, boosted effects, public selection, neutral path and atomic failures." % checks)
	else:
		push_error("UPG-02b tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_arithmetic_and_isolation() -> void:
	var resolver := Resolver.new(content)
	for ingredient in ["tortilla", "meat", "veggie"]:
		for length in [3, 4, 5, 6, 25]:
			var original := resolver.resolve(ingredient, length)
			_expect(original == resolver.resolve(ingredient, length, {}), "empty snapshot must preserve the complete REC-01 result")
			_expect(original == resolver.resolve(ingredient, length, _modifiers([])), "derived neutral snapshot must preserve REC-01")
	var fixtures := [
		[["extra_bite"], 3, 35.0], [["extra_bite"], 4, 52.5],
		[["chain4_boost"], 3, 30.0], [["chain4_boost"], 4, 48.0],
		[["chain4_boost"], 5, 48.0], [["taco_power_1"], 3, 34.5],
		[["taco_power_2"], 3, 45.0],
		[["extra_bite", "chain4_boost", "taco_power_2"], 5, 84.0],
	]
	for fixture in fixtures:
		var result := resolver.resolve("tortilla", fixture[1], _modifiers(fixture[0]))
		_expect(result["ok"], "real upgrades must resolve")
		_expect_float(result["satisfaction_final"], fixture[2], "satisfaction fixture %s" % [fixture])
		_expect(typeof(result["satisfaction_final"]) == TYPE_FLOAT, "satisfaction must keep float precision")
	var snapshot := _modifiers(["extra_bite", "chain4_boost", "taco_power_2", "chain5_effect_boost"])
	var before := snapshot.duplicate(true)
	var source_before := content.duplicate(true)
	for ingredient in ["tortilla", "meat", "veggie"]:
		for length in [3, 4, 5, 25]:
			var expected := resolver.resolve(ingredient, length, snapshot)
			for _repeat in range(10):
				_expect(resolver.resolve(ingredient, length, snapshot) == expected, "same snapshot must produce an identical complete result")
	# Values distinguish flat-before-chain and flat-before-multiplier from either alternative.
	var combined := resolver.resolve("tortilla", 5, snapshot)
	_expect_float(combined["satisfaction_final"], 84.0, "D4: (30 + 5) * 1.6 * 1.5")
	_expect_float(combined["base_satisfaction"], 30.0, "base must remain the recipe value")
	_expect_float(combined["chain_multiplier"], 1.6, "chain metadata must reflect the additive bonus")
	_expect_float(combined["special_effect_params"]["duration_sec"], 1.3, "stun must scale only once")
	var meat := resolver.resolve("meat", 5, snapshot)
	_expect_float(meat["satisfaction_final"], 98.4, "meat normal satisfaction follows D4")
	_expect_float(meat["special_effect_params"]["amount"], 15.6, "burst excludes flat, chain and taco_power")
	var power_burst := resolver.resolve("meat", 5, _modifiers(["taco_power_2", "chain5_effect_boost"]))
	_expect_float(power_burst["satisfaction_final"], 81.0, "taco_power_2 applies to normal meat satisfaction")
	_expect_float(power_burst["special_effect_params"]["amount"], 15.6, "burst must not receive taco_power_2 again")
	# UPG-02e completes the same independent special-effect scaling for veggie.
	_expect(resolver.resolve("veggie", 5, snapshot)["special_effect_params"] == {"amount": 6.5}, "veggie receives only the special-effect multiplier")
	combined["special_effect_params"]["duration_sec"] = 99.0
	_expect_float(resolver.resolve("tortilla", 5, snapshot)["special_effect_params"]["duration_sec"], 1.3, "output params must be isolated")
	_expect(snapshot == before and content == source_before, "resolver must preserve modifiers and source content")
	snapshot["satisfaction_multiplier"] = 2.0
	_expect_float(combined["satisfaction_final"], 84.0, "later input mutation must not affect previous output")


func _test_invalid_modifiers() -> void:
	var resolver := Resolver.new(content)
	for invalid in _invalid_snapshots():
		var before := var_to_bytes(invalid)
		var result := resolver.resolve("meat", 5, invalid)
		_expect(result.get("error") == Resolver.INVALID_MODIFIERS and not result["ok"], "invalid modifiers must fail explicitly")
		_expect(not result.get("message", "").is_empty(), "failure must include a reason")
		_expect(not result.has("satisfaction_final") and not result.has("special_effect_params"), "failure must expose no partial dish")
		_expect(var_to_bytes(invalid) == before, "failure must not mutate input, including NaN fixtures")


func _test_main_public_selection() -> void:
	var main = MAIN.instantiate()
	get_root().add_child(main)
	await process_frame
	var target: LaneRunner = main.lane_field.spawn_runner(1, 55.0, "T", "salsa_tank", 2000.0)
	target.auto_advance = false
	var other: LaneRunner = main.lane_field.spawn_runner(0, 55.0, "O", "salsa_tank", 2000.0)
	other.auto_advance = false
	target.motion.progress = 0.7
	other.motion.progress = 0.2
	var created: Array[Dictionary] = []
	main.lane_field.dish_created.connect(func(payload: Dictionary): created.append(payload))
	_expect(main.DEFAULT_RUN_SEED == 20260921, "public selection fixture pins the real Main seed")
	_expect(main.upgrade_selector.get_selection_count() == 0, "neutral path starts without upgrades")
	_complete_board_chain(main)
	_expect_float(created[-1]["satisfaction_final"], 30.0, "BoardView -> Main neutral satisfaction")
	_expect_float(target.monster_state.hunger_remaining, 1970.0, "neutral service must apply exactly 30")
	_select(main, 1, "second_chance")
	_select(main, 2, "chain5_effect_boost")
	var stun: Dictionary = main._on_chain_completed(_points(5), "tortilla")
	_expect(stun["ok"], "publicly selected boost must serve")
	_expect_float(stun["dish"]["special_effect_params"]["duration_sec"], 1.3, "Main must forward selected stun boost")
	_expect_float(target.motion.stun_remaining_sec, 1.3, "LaneField must apply 1.3-second stun")
	var progress := target.motion.progress
	target.motion.advance(1.1)
	_expect_float(target.motion.progress, progress, "boosted stun must still prevent movement after 1.1 seconds")
	target.motion.advance(0.3)
	_expect(not target.motion.is_stunned() and target.motion.progress > progress, "movement resumes after boosted duration")
	_expect(not other.motion.is_stunned(), "stun must only affect primary target")
	var burst: Dictionary = main._on_chain_completed(_points(5), "meat")
	_expect_float(burst["dish"]["satisfaction_final"], 54.0, "boost alone preserves normal meat satisfaction")
	_expect_float(burst["served"]["satisfaction_applied"], 69.6, "LaneField applies 54 + 15.6")
	main.reputation.apply_damage(20.0)
	var veggie: Dictionary = main._on_chain_completed(_points(5), "veggie")
	_expect(veggie["dish"]["special_effect_params"] == {"amount": 6.5}, "boosted snapshot scales veggie to +6.5")
	_expect_float(main.reputation.current, 86.5, "actual boosted veggie restoration is +6.5")
	_select(main, 3, "extra_bite")
	_complete_board_chain(main)
	_expect_float(created[-1]["satisfaction_final"], 35.0, "next board dish must reflect the new selection on demand")
	_select(main, 4, "slow_salsa")
	_select(main, 5, "taco_power_2")
	_complete_board_chain(main)
	_expect_float(created[-1]["satisfaction_final"], 52.5, "later selection must update flat * taco_power without cached state")
	var combined: Dictionary = main._on_chain_completed(_points(5), "meat")
	_expect_float(combined["dish"]["satisfaction_final"], 92.25, "Main combines extra_bite and taco_power_2")
	_expect_float(combined["dish"]["special_effect_params"]["amount"], 15.6, "Main burst remains independent of normal satisfaction")
	_expect_float(combined["served"]["satisfaction_applied"], 107.85, "LaneField adds the separately boosted burst")
	_expect_float(other.monster_state.hunger_remaining, 2000.0, "no splash or secondary target effect is introduced")
	_expect_float(target.motion.global_speed_multiplier, 0.9, "UPG-02c slow_salsa coexists with satisfaction and boosted effects")
	main.queue_free()
	await process_frame


func _test_deferred_conditionals() -> void:
	var main = MAIN.instantiate()
	get_root().add_child(main)
	await process_frame
	var target: LaneRunner = main.lane_field.spawn_runner(1, 55.0, "T", "salsa_tank", 2000.0)
	target.auto_advance = false
	# Fixed seed 20260921, public offers; last_stand's condition is true at 19%.
	_select(main, 1, "last_stand")
	_select(main, 2, "slow_salsa")
	_select(main, 3, "chain4_boost")
	_select(main, 4, "warm_welcome")
	main.reputation.apply_damage(81.0)
	for _repeat in range(2):
		var result: Dictionary = main._on_chain_completed(_points(3), "tortilla")
		_expect_float(result["served"]["satisfaction_applied"], 30.0, "neither first dish nor low reputation may activate deferred conditionals")
	var chain4: Dictionary = main._on_chain_completed(_points(4), "tortilla")
	_expect_float(chain4["served"]["satisfaction_applied"], 48.0, "real chain4_boost selection reaches LaneField")
	main.queue_free()
	await process_frame


func _test_main_failures_are_atomic() -> void:
	var main = MAIN.instantiate()
	get_root().add_child(main)
	await process_frame
	var target: LaneRunner = main.lane_field.spawn_runner(1, 55.0, "T", "salsa_tank", 2000.0)
	target.auto_advance = false
	main.reputation.apply_damage(20.0)
	var reputation_before: Dictionary = main.reputation.snapshot()
	var events: Array[String] = []
	main.lane_field.dish_created.connect(func(_p: Dictionary): events.append("created"))
	main.lane_field.dish_served.connect(func(_p: Dictionary): events.append("served"))
	main.lane_field.monster_satisfied.connect(func(_p: Dictionary): events.append("satisfied"))
	main.reputation.reputation_changed.connect(func(_p: Dictionary): events.append("reputation"))
	var real_selector: UpgradeSelector = main.upgrade_selector
	var broken_selector := InvalidEffectsSelector.new()
	main.add_child(broken_selector)
	main.upgrade_selector = broken_selector
	var failed_derive: Dictionary = main._on_chain_completed(_points(5), "veggie")
	_expect(not failed_derive["ok"] and failed_derive.get("error") == Modifiers.INVALID_ACTIVE_EFFECTS, "Main must propagate derivation failure")
	main.upgrade_selector = real_selector
	var faulty_resolver := InvalidModifiersResolver.new(content)
	main.recipe_resolver = faulty_resolver
	for invalid in _invalid_snapshots():
		faulty_resolver.injected = invalid
		var result: Dictionary = main._on_chain_completed(_points(5), "meat")
		_expect(not result["ok"] and result.get("error") == Resolver.INVALID_MODIFIERS, "Main must propagate invalid/overflow resolver result")
	_expect(events.is_empty(), "all failures must precede dish creation, service and reputation events")
	_expect_float(target.monster_state.hunger_remaining, 2000.0, "failures must preserve hunger")
	_expect(not target.motion.is_stunned(), "failures must not apply stun")
	_expect(main.reputation.snapshot() == reputation_before, "failures must preserve reputation")
	_expect(real_selector.get_selection_count() == 0, "failures must preserve selection")
	main.queue_free()
	await process_frame


func _invalid_snapshots() -> Array:
	var result: Array = [null, [], "invalid", 1, {1: 1.0},
		{"satisfaction_multiplier": 1e308}, {"special_effect_power_multiplier": 1e308},
		{"satisfaction_flat_bonus": 1e308, "chain4_satisfaction_bonus": 1e308, "satisfaction_multiplier": 0.0}]
	for stat in Modifiers.NEUTRAL_MODIFIERS:
		for value in [NAN, INF, -INF, null, true, "1.3", [], {}]:
			result.append({stat: value})
	return result


func _modifiers(ids: Array) -> Dictionary:
	var active: Array = []
	for upgrade in content["upgrades"]:
		if upgrade["id"] in ids:
			active.append({"upgrade_id": upgrade["id"], "effect": upgrade["effect"]})
	return Modifiers.derive(active)["modifiers"]


func _select(main, wave: int, upgrade_id: String) -> void:
	main.wave_director.wave_completed.emit({"wave_id": "wave_%02d" % wave})
	var selected: Dictionary = main.upgrade_selector.select_upgrade(upgrade_id)
	_expect(selected["ok"], "fixed seed must offer %s at wave %d" % [upgrade_id, wave])
	_expect(upgrade_id in main.upgrade_selector.get_selected_upgrade_ids(), "selection must be recorded through public API")


func _complete_board_chain(main) -> void:
	main.board_view.reset_with_seed(main.board_view.DEFAULT_BOARD_SEED)
	_expect(main.board_view.begin_chain_at(Vector2i(0, 0)), "board chain must begin")
	_expect(main.board_view.extend_chain_to(Vector2i(1, 0)), "board chain must extend")
	_expect(main.board_view.extend_chain_to(Vector2i(2, 0)), "board chain must reach three")
	_expect(main.board_view.finish_chain().size() == 3, "board must emit completed chain")


func _points(length: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(length):
		result.append(Vector2i(x, 0))
	return result


func _expect_float(actual: float, expected: float, message: String) -> void:
	_expect(is_equal_approx(actual, expected), "%s: expected %s, got %s" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
