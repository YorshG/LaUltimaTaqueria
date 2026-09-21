extends SceneTree

var failures := 0
var Registry = preload("res://scripts/content/content_registry.gd")
var Resolver = preload("res://scripts/recipes/recipe_resolver.gd")


func _init() -> void:
	var registry = Registry.new()
	var registry_result = registry.load_and_validate()
	_expect(registry_result["ok"], "default content must validate before resolver tests")
	if not registry_result["ok"]:
		quit(1)
		return

	var content: Dictionary = registry_result["content"]
	var resolver = Resolver.new(content)
	_test_tortilla(resolver)
	_test_meat(resolver)
	_test_veggie(resolver)
	_test_effect_copy_is_isolated(resolver, content)
	_test_errors(content)
	_test_determinism(resolver)

	if failures == 0:
		print("REC-01 tests passed: recipes, tiers, effects, errors, isolation, determinism.")
		quit(0)
	else:
		push_error("REC-01 tests failed: %d" % failures)
		quit(1)


func _test_tortilla(resolver) -> void:
	var chain_three: Dictionary = resolver.resolve("tortilla", 3)
	_expect_resolution(chain_three, 30.0, "basic", 1.0, false, "", {})
	_expect_identity(chain_three, "taco_simple", "tortilla")
	_expect_resolution(resolver.resolve("tortilla", 4), 45.0, "chain4", 1.5, false, "", {})
	for chain_length in [5, 6, 25]:
		var result = resolver.resolve("tortilla", chain_length)
		_expect_resolution(
			result,
			45.0,
			"chain5_plus",
			1.5,
			true,
			"brief_stun",
			{"duration_sec": 1.0}
		)
		_expect(result.get("chain_length") == chain_length, "tortilla result must preserve chain length")


func _test_meat(resolver) -> void:
	var chain_three: Dictionary = resolver.resolve("meat", 3)
	_expect_resolution(chain_three, 36.0, "basic", 1.0, false, "", {})
	_expect_identity(chain_three, "taco_meat_simple", "meat")
	_expect_resolution(resolver.resolve("meat", 4), 54.0, "chain4", 1.5, false, "", {})
	_expect_resolution(
		resolver.resolve("meat", 5),
		54.0,
		"chain5_plus",
		1.5,
		true,
		"bonus_satisfaction_burst",
		{"amount": 12.0}
	)


func _test_veggie(resolver) -> void:
	var chain_three: Dictionary = resolver.resolve("veggie", 3)
	_expect_resolution(chain_three, 24.0, "basic", 1.0, false, "", {})
	_expect_identity(chain_three, "taco_veggie_simple", "veggie")
	_expect_resolution(resolver.resolve("veggie", 4), 36.0, "chain4", 1.5, false, "", {})
	_expect_resolution(
		resolver.resolve("veggie", 5),
		36.0,
		"chain5_plus",
		1.5,
		true,
		"reputation_small_restore",
		{"amount": 5.0}
	)


func _test_effect_copy_is_isolated(resolver, source: Dictionary) -> void:
	var source_params: Dictionary = source["ingredients"][0]["special_effect_params"].duplicate(true)
	var first = resolver.resolve("tortilla", 5)
	first["special_effect_params"]["duration_sec"] = 99
	var second = resolver.resolve("tortilla", 5)

	_expect(
		source["ingredients"][0]["special_effect_params"] == source_params,
		"mutating result params must not mutate ContentRegistry content"
	)
	_expect(
		second["special_effect_params"] == source_params,
		"each resolution must return a fresh special_effect_params structure"
	)


func _test_errors(source: Dictionary) -> void:
	var resolver = Resolver.new(source)
	for chain_length in [0, 1, 2]:
		_expect_error(resolver.resolve("tortilla", chain_length), Resolver.INVALID_CHAIN_LENGTH)
	_expect_error(resolver.resolve("", 3), Resolver.INVALID_INGREDIENT_ID)
	_expect_error(resolver.resolve("missing_ingredient", 3), Resolver.UNKNOWN_INGREDIENT)

	var no_recipe_content := source.duplicate(true)
	var recipes_without_tortilla: Array = []
	for recipe in no_recipe_content["recipes"]:
		if not recipe["ingredients"].has("tortilla"):
			recipes_without_tortilla.append(recipe)
	no_recipe_content["recipes"] = recipes_without_tortilla
	var no_recipe_resolver = Resolver.new(no_recipe_content)
	_expect_error(
		no_recipe_resolver.resolve("tortilla", 3),
		Resolver.NO_RECIPE_FOR_INGREDIENT
	)

	var ambiguous_content := source.duplicate(true)
	var duplicate_recipe: Dictionary = ambiguous_content["recipes"][0].duplicate(true)
	duplicate_recipe["id"] = "alternate_tortilla_recipe"
	ambiguous_content["recipes"].append(duplicate_recipe)
	_expect_error(
		Resolver.new(ambiguous_content).resolve("tortilla", 3),
		Resolver.AMBIGUOUS_RECIPE
	)
	ambiguous_content["recipes"].reverse()
	_expect_error(
		Resolver.new(ambiguous_content).resolve("tortilla", 3),
		Resolver.AMBIGUOUS_RECIPE
	)

	_expect_error(
		Resolver.new({"ingredients": []}).resolve("tortilla", 3),
		Resolver.INVALID_CONTENT_STATE
	)


func _test_determinism(resolver) -> void:
	var expected: Dictionary = resolver.resolve("meat", 5)
	for _iteration in range(20):
		_expect(
			resolver.resolve("meat", 5) == expected,
			"same content and inputs must produce an identical complete result"
		)


func _expect_resolution(
	result: Dictionary,
	expected_satisfaction: float,
	expected_tier: String,
	expected_multiplier: float,
	expected_triggered: bool,
	expected_effect: String,
	expected_params: Dictionary
) -> void:
	var required_fields: Array[String] = [
		"ok",
		"recipe_id",
		"ingredient_id",
		"chain_length",
		"chain_tier",
		"base_satisfaction",
		"chain_multiplier",
		"satisfaction_final",
		"targeting",
		"special_effect_triggered",
		"special_effect",
		"special_effect_params",
	]
	for field in required_fields:
		_expect(result.has(field), "resolution must include required field %s" % field)
	_expect(result.get("ok", false), "resolution must succeed: %s" % result)
	if not result.get("ok", false):
		return
	_expect(not String(result["recipe_id"]).is_empty(), "resolution must include recipe id")
	_expect(not String(result["ingredient_id"]).is_empty(), "resolution must include ingredient id")
	_expect(
		is_equal_approx(float(result["satisfaction_final"]), expected_satisfaction),
		"unexpected satisfaction: %s" % result
	)
	_expect(result["chain_tier"] == expected_tier, "unexpected chain tier: %s" % result)
	_expect(
		is_equal_approx(float(result["chain_multiplier"]), expected_multiplier),
		"unexpected chain multiplier: %s" % result
	)
	_expect(
		is_equal_approx(
			float(result["base_satisfaction"]) * float(result["chain_multiplier"]),
			float(result["satisfaction_final"])
		),
		"final satisfaction must be base satisfaction times chain multiplier: %s" % result
	)
	_expect(result["targeting"] == "nearest", "unexpected targeting: %s" % result)
	_expect(
		result["special_effect_triggered"] == expected_triggered,
		"unexpected special effect trigger: %s" % result
	)
	_expect(result["special_effect"] == expected_effect, "unexpected special effect: %s" % result)
	_expect(
		result["special_effect_params"] == expected_params,
		"unexpected special effect params: %s" % result
	)


func _expect_error(result: Dictionary, expected_error: String) -> void:
	_expect(not result.get("ok", true), "resolution must fail: %s" % result)
	_expect(result.get("error") == expected_error, "expected %s, got %s" % [expected_error, result])


func _expect_identity(result: Dictionary, expected_recipe: String, expected_ingredient: String) -> void:
	_expect(result.get("recipe_id") == expected_recipe, "unexpected recipe id: %s" % result)
	_expect(result.get("ingredient_id") == expected_ingredient, "unexpected ingredient id: %s" % result)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
