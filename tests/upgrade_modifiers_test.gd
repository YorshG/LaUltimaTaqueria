extends SceneTree

const Modifiers = preload("res://scripts/upgrades/upgrade_modifiers.gd")
const Registry = preload("res://scripts/content/content_registry.gd")
const Selector = preload("res://scripts/upgrades/upgrade_selector.gd")

var failures := 0
var checks := 0
var content: Dictionary
var effects: Dictionary = {}


func _init() -> void:
	var loaded: Dictionary = Registry.new().load_and_validate()
	_expect(loaded["ok"], "real content must validate")
	if not loaded["ok"]:
		quit(1)
		return
	content = loaded["content"]
	for upgrade in content["upgrades"]:
		effects[upgrade["id"]] = {"upgrade_id": upgrade["id"], "effect": upgrade["effect"]}
	_test_neutrals()
	_test_real_continuous_effects()
	_test_conditionals_and_ownership()
	_test_one_shots()
	_test_aggregation_and_order()
	_test_selector_snapshots()
	_test_invalid_inputs()
	if failures == 0:
		print("UPG-02a tests passed: %d checks; pure deterministic modifiers, conditionals and input isolation." % checks)
	else:
		push_error("UPG-02a tests failed: %d/%d" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _test_neutrals() -> void:
	var result := Modifiers.derive([])
	_expect(result == {
		"ok": true,
		"modifiers": {
			"satisfaction_flat_bonus": 0.0,
			"chain4_satisfaction_bonus": 0.0,
			"satisfaction_multiplier": 1.0,
			"special_effect_power_multiplier": 1.0,
			"chain4_splash_satisfaction": 0.0,
			"monster_speed_global": 1.0,
			"input_forgiveness": 0.0,
			"reputation_damage_taken": 1.0,
		},
		"conditional_multipliers": [],
	}, "empty snapshot must provide exactly the eight neutral continuous stats")
	for value in result["modifiers"].values():
		_expect(typeof(value) == TYPE_FLOAT, "neutral values must be floats")


func _test_real_continuous_effects() -> void:
	var cases := [
		["extra_bite", "satisfaction_flat_bonus", 5.0],
		["taco_power_1", "satisfaction_multiplier", 1.15],
		["taco_power_2", "satisfaction_multiplier", 1.5],
		["chain4_boost", "chain4_satisfaction_bonus", 0.1],
		["chain5_effect_boost", "special_effect_power_multiplier", 1.3],
		["slow_salsa", "monster_speed_global", 0.9],
		["slow_salsa_plus", "monster_speed_global", 0.75],
		["steady_hands", "input_forgiveness", 0.1],
		["patient_service", "reputation_damage_taken", 0.85],
		["assist_serve", "chain4_splash_satisfaction", 10.0],
	]
	for fixture in cases:
		var expected := Modifiers.derive([])
		expected["modifiers"][fixture[1]] = fixture[2]
		_expect(Modifiers.derive([effects[fixture[0]]]) == expected,
			"%s must only change %s to %s" % fixture)


func _test_conditionals_and_ownership() -> void:
	var active := _active(["warm_welcome", "last_stand"])
	var snapshot := active.duplicate(true)
	var result := Modifiers.derive(active)
	_expect(result["ok"], "conditionals must derive")
	_expect(result["modifiers"] == Modifiers.derive([])["modifiers"], "conditionals must not change neutral stats")
	_expect(result["conditional_multipliers"] == [
		{
			"upgrade_id": "last_stand", "stat": "satisfaction_multiplier",
			"operation": "multiply", "value": 1.25,
			"params": {"condition": "reputation_below_ratio", "threshold": 0.20},
		},
		{
			"upgrade_id": "warm_welcome", "stat": "satisfaction_multiplier",
			"operation": "multiply", "value": 2.0,
			"params": {"condition": "first_dish_of_encounter"},
		},
	], "conditionals must retain identity, operation, value and unevaluated parameters in ID order")
	_expect(active == snapshot, "derive must not sort or mutate its input")
	active.reverse()
	_expect(_encoded(Modifiers.derive(active)) == _encoded(result), "conditional order must be canonical")
	active.reverse()
	result["conditional_multipliers"][0]["params"]["threshold"] = 0.99
	result["modifiers"]["input_forgiveness"] = 99.0
	_expect(active == snapshot, "returned params must not alias input")
	var fresh := Modifiers.derive(active)
	_expect(fresh["conditional_multipliers"][0]["params"]["threshold"] == 0.20, "returned mutations must not leak to later calls")
	active[1]["effect"]["params"]["threshold"] = 0.5
	_expect(fresh["conditional_multipliers"][0]["params"]["threshold"] == 0.20, "input mutations must not alter previous results")
	var mixed := Modifiers.derive(_active(["warm_welcome", "taco_power_1", "last_stand"]))
	_expect(mixed["modifiers"]["satisfaction_multiplier"] == 1.15, "mixed result must only aggregate unconditional satisfaction")
	_expect(mixed["conditional_multipliers"] == fresh["conditional_multipliers"], "mixed result must retain both deferred conditions")


func _test_one_shots() -> void:
	# Test strong defenses separately: selector owns their mutual exclusion.
	for upgrade_id in ["reputation_boost", "safety_shield", "second_chance"]:
		var active := _active([upgrade_id])
		var before := active.duplicate(true)
		_expect(Modifiers.derive(active) == Modifiers.derive([]), "%s must grant no maximum or charges" % upgrade_id)
		_expect(Modifiers.derive(active) == Modifiers.derive([]), "%s repeated snapshot must remain neutral" % upgrade_id)
		_expect(active == before, "%s must preserve one-shot metadata" % upgrade_id)
		active.append(effects["extra_bite"].duplicate(true))
		_expect(Modifiers.derive(active) == Modifiers.derive(_active(["extra_bite"])), "%s must not discard continuous effects" % upgrade_id)


func _test_aggregation_and_order() -> void:
	# Synthetic distinct IDs exercise the arithmetic contract, not catalog eligibility.
	var active := [
		_synthetic("mul_a", "multiply", 1.15),
		_synthetic("mul_b", "multiply", 1.3),
		_synthetic("mul_c", "multiply", 0.85),
		_synthetic("add_a", "add", 0.1),
		_synthetic("add_b", "add", 0.2),
		_synthetic("add_c", "add", 0.3),
	]
	var before := active.duplicate(true)
	var expected := Modifiers.derive(active)
	_expect(expected["ok"], "synthetic aggregation must succeed")
	_expect(expected["modifiers"]["satisfaction_multiplier"] == (1.15 * 1.3) * 0.85, "multipliers must multiply without rounding")
	_expect(expected["modifiers"]["satisfaction_flat_bonus"] == (0.1 + 0.2) + 0.3, "additions must sum without rounding")
	_expect(active == before, "arithmetic must not mutate the snapshot")
	_check_permutations([], active, _encoded(expected))
	for _iteration in range(3):
		_expect(Modifiers.derive(active) == expected, "repeated derivation must be identical")
	var reordered: Array = []
	for entry in active:
		var effect: Dictionary = entry["effect"]
		reordered.append({"effect": {"value": effect["value"], "operation": effect["operation"],
			"stat": effect["stat"], "type": effect["type"]}, "upgrade_id": entry["upgrade_id"]})
	reordered.append({"effect": {"params": {"threshold": 0.2, "condition": "reputation_below_ratio"},
		"value": 1.25, "operation": "multiply", "stat": "satisfaction_multiplier", "type": "conditional_satisfaction"},
		"upgrade_id": "last_stand"})
	active.append(effects["last_stand"].duplicate(true))
	_expect(_encoded(Modifiers.derive(reordered)) == _encoded(Modifiers.derive(active)), "dictionary insertion order must not affect output, including conditional params")


func _test_selector_snapshots() -> void:
	for seed in [0, 7, 20260927]:
		var selector := Selector.new()
		_expect(selector.configure(content)["ok"], "selector must configure")
		_expect(selector.start_run(seed)["ok"], "selector must start")
		for wave_number in range(1, 6):
			_expect(selector.receive_wave_completed({"wave_id": "wave_%02d" % wave_number})["ok"], "selector must offer")
			_expect(selector.select_upgrade(selector.get_current_offer()[0]["id"])["ok"], "selector must select")
			var active := selector.get_active_effects()
			var before := active.duplicate(true)
			var result := Modifiers.derive(active)
			_expect(result["ok"], "real selector snapshot must derive")
			_expect(active == before and selector.get_active_effects() == before, "derivation must preserve selector and snapshot")
			active.reverse()
			_expect(_encoded(Modifiers.derive(active)) == _encoded(result), "real selected effects must be order independent")
		selector.free()


func _test_invalid_inputs() -> void:
	for invalid in [[null], [1], [{}], [{"upgrade_id": ""}], [{"upgrade_id": 1}],
		[{"upgrade_id": "missing_effect"}], [effects["extra_bite"], effects["extra_bite"]]]:
		_expect_error(invalid)
	for field in ["type", "stat", "operation", "value"]:
		var entry: Dictionary = effects["extra_bite"].duplicate(true)
		entry["effect"].erase(field)
		_expect_error([entry])
	for value in [null, true, "5", NAN, INF, -INF]:
		var entry: Dictionary = effects["extra_bite"].duplicate(true)
		entry["effect"]["value"] = value
		_expect_error([entry])
	for params in [null, [], {"condition": "unknown"}, {"condition": "reputation_below_ratio"},
		{"condition": "reputation_below_ratio", "threshold": 1.1},
		{"condition": "reputation_below_ratio", "threshold": -0.1},
		{"condition": "reputation_below_ratio", "threshold": NAN},
		{"condition": "first_dish_of_encounter", "threshold": 0.2}]:
		var entry: Dictionary = effects["last_stand"].duplicate(true)
		entry["effect"]["params"] = params
		_expect_error([entry])
	var wrong_pair: Dictionary = effects["taco_power_1"].duplicate(true)
	wrong_pair["effect"]["operation"] = "add"
	_expect_error([wrong_pair])
	var malformed_one_shot: Dictionary = effects["second_chance"].duplicate(true)
	malformed_one_shot["effect"]["params"] = {}
	_expect_error([malformed_one_shot])
	_expect_error([_synthetic("overflow_a", "multiply", 1e308), _synthetic("overflow_b", "multiply", 1e308)])


func _active(ids: Array) -> Array:
	var result: Array = []
	for upgrade_id in ids:
		result.append(effects[upgrade_id].duplicate(true))
	return result


func _synthetic(id: String, operation: String, value: float) -> Dictionary:
	return {"upgrade_id": id, "effect": {"type": "modify_satisfaction",
		"stat": "satisfaction_flat_bonus" if operation == "add" else "satisfaction_multiplier",
		"operation": operation, "value": value}}


func _check_permutations(prefix: Array, remaining: Array, expected: String) -> void:
	if remaining.is_empty():
		_expect(_encoded(Modifiers.derive(prefix)) == expected, "all 720 input permutations must be exactly equal")
		return
	for index in range(remaining.size()):
		var rest := remaining.duplicate()
		var next := prefix.duplicate()
		next.append(rest.pop_at(index))
		_check_permutations(next, rest, expected)


func _encoded(result: Dictionary) -> String:
	# Disable JSON key sorting to also observe output dictionary insertion order.
	return JSON.stringify(result, "", false, true)


func _expect_error(active: Array) -> void:
	var before := active.duplicate(true)
	var result := Modifiers.derive(active)
	_expect(not result["ok"] and result.get("error") == Modifiers.INVALID_ACTIVE_EFFECTS, "invalid snapshot must return explicit error: %s" % result)
	_expect(not result.get("message", "").is_empty(), "error must include a reason")
	_expect(not result.has("modifiers") and not result.has("conditional_multipliers"), "invalid input must expose no partial result")
	# Binary serialization preserves invalid NaN/Inf fixtures without JSON warnings.
	_expect(var_to_bytes(active) == var_to_bytes(before), "failure must not mutate input")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
