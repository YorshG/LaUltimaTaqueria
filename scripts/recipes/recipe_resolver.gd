class_name RecipeResolver
extends RefCounted

const INVALID_CHAIN_LENGTH := "INVALID_CHAIN_LENGTH"
const INVALID_INGREDIENT_ID := "INVALID_INGREDIENT_ID"
const UNKNOWN_INGREDIENT := "UNKNOWN_INGREDIENT"
const NO_RECIPE_FOR_INGREDIENT := "NO_RECIPE_FOR_INGREDIENT"
const AMBIGUOUS_RECIPE := "AMBIGUOUS_RECIPE"
const INVALID_CONTENT_STATE := "INVALID_CONTENT_STATE"
const INVALID_MODIFIERS := "INVALID_MODIFIERS"

const BASIC_MULTIPLIER := 1.0
const CHAIN_BONUS_MULTIPLIER := 1.5

var _ingredients_by_id: Dictionary = {}
var _recipes_by_ingredient: Dictionary = {}
var _content_error := ""
var _id_regex := RegEx.new()


func _init(validated_content: Dictionary = {}) -> void:
	_id_regex.compile("^[a-z][a-z0-9_]*$")
	set_content(validated_content)


func set_content(validated_content: Dictionary) -> void:
	_ingredients_by_id.clear()
	_recipes_by_ingredient.clear()
	_content_error = ""

	var ingredients = validated_content.get("ingredients", null)
	var recipes = validated_content.get("recipes", null)
	if typeof(ingredients) != TYPE_ARRAY or typeof(recipes) != TYPE_ARRAY:
		_content_error = "ingredients and recipes must be arrays"
		return

	for item in ingredients:
		if typeof(item) != TYPE_DICTIONARY:
			_content_error = "ingredient entries must be objects"
			return
		var ingredient_id = item.get("id", null)
		if typeof(ingredient_id) != TYPE_STRING or ingredient_id.is_empty():
			_content_error = "ingredient ids must be non-empty strings"
			return
		if _ingredients_by_id.has(ingredient_id):
			_content_error = "duplicate ingredient id: %s" % ingredient_id
			return
		if typeof(item.get("special_effect", null)) != TYPE_STRING:
			_content_error = "ingredient %s special_effect must be a string" % ingredient_id
			return
		if typeof(item.get("special_effect_params", null)) != TYPE_DICTIONARY:
			_content_error = "ingredient %s special_effect_params must be an object" % ingredient_id
			return
		_ingredients_by_id[ingredient_id] = item.duplicate(true)

	for item in recipes:
		if typeof(item) != TYPE_DICTIONARY:
			_content_error = "recipe entries must be objects"
			return
		var recipe_id = item.get("id", null)
		if typeof(recipe_id) != TYPE_STRING or recipe_id.is_empty():
			_content_error = "recipe ids must be non-empty strings"
			return
		var recipe_ingredients = item.get("ingredients", null)
		if typeof(recipe_ingredients) != TYPE_DICTIONARY or recipe_ingredients.size() != 1:
			_content_error = "recipe %s must reference exactly one ingredient" % recipe_id
			return
		var ingredient_id = recipe_ingredients.keys()[0]
		if typeof(ingredient_id) != TYPE_STRING or not _ingredients_by_id.has(ingredient_id):
			_content_error = "recipe %s references an unknown ingredient" % recipe_id
			return
		var satisfaction = item.get("satisfaction", null)
		if not _is_finite_number(satisfaction) or float(satisfaction) <= 0.0:
			_content_error = "recipe %s satisfaction must be finite and positive" % recipe_id
			return
		if typeof(item.get("targeting", null)) != TYPE_STRING:
			_content_error = "recipe %s targeting must be a string" % recipe_id
			return
		if not _recipes_by_ingredient.has(ingredient_id):
			_recipes_by_ingredient[ingredient_id] = []
		_recipes_by_ingredient[ingredient_id].append(item.duplicate(true))


func resolve(ingredient_id: String, chain_length: int, modifiers = {}) -> Dictionary:
	if chain_length < 3:
		return _failure(
			INVALID_CHAIN_LENGTH,
			"chain_length must be at least 3"
		)
	if ingredient_id.is_empty() or ingredient_id != ingredient_id.strip_edges():
		return _failure(
			INVALID_INGREDIENT_ID,
			"ingredient_id must be a non-empty lower snake_case string"
		)
	if _id_regex.search(ingredient_id) == null:
		return _failure(
			INVALID_INGREDIENT_ID,
			"ingredient_id must be a non-empty lower snake_case string"
		)
	if not _content_error.is_empty():
		return _failure(INVALID_CONTENT_STATE, _content_error)
	if not _ingredients_by_id.has(ingredient_id):
		return _failure(
			UNKNOWN_INGREDIENT,
			"unknown ingredient: %s" % ingredient_id
		)

	var candidates: Array = _recipes_by_ingredient.get(ingredient_id, [])
	if candidates.is_empty():
		return _failure(
			NO_RECIPE_FOR_INGREDIENT,
			"no recipe found for ingredient: %s" % ingredient_id
		)
	if candidates.size() > 1:
		return _failure(
			AMBIGUOUS_RECIPE,
			"multiple recipes found for ingredient: %s" % ingredient_id
		)

	# Accept the full derived snapshot, but consume only UPG-02b's four stats.
	if typeof(modifiers) != TYPE_DICTIONARY:
		return _failure(INVALID_MODIFIERS, "modifiers must be an object")
	for stat in modifiers:
		if typeof(stat) != TYPE_STRING or not _is_finite_number(modifiers[stat]):
			return _failure(INVALID_MODIFIERS, "modifier keys must be strings and values finite numbers")
	var flat_bonus := float(modifiers.get("satisfaction_flat_bonus", 0.0))
	var chain_bonus := float(modifiers.get("chain4_satisfaction_bonus", 0.0))
	var satisfaction_multiplier := float(modifiers.get("satisfaction_multiplier", 1.0))
	var special_multiplier := float(modifiers.get("special_effect_power_multiplier", 1.0))

	var recipe: Dictionary = candidates[0]
	var ingredient: Dictionary = _ingredients_by_id[ingredient_id]
	var chain_tier := "basic"
	var chain_multiplier := BASIC_MULTIPLIER
	var special_effect_triggered := false
	if chain_length == 4:
		chain_tier = "chain4"
		chain_multiplier = CHAIN_BONUS_MULTIPLIER + chain_bonus
	elif chain_length >= 5:
		chain_tier = "chain5_plus"
		chain_multiplier = CHAIN_BONUS_MULTIPLIER + chain_bonus
		special_effect_triggered = true

	var base_satisfaction := float(recipe["satisfaction"])
	# D4: flat -> chain -> satisfaction multipliers; never round.
	var satisfaction_final := (base_satisfaction + flat_bonus) * chain_multiplier * satisfaction_multiplier
	if not is_finite(satisfaction_final):
		return _failure(INVALID_MODIFIERS, "satisfaction_final must remain finite")
	var special_effect := ""
	var special_effect_params := {}
	if special_effect_triggered:
		special_effect = str(ingredient["special_effect"])
		special_effect_params = ingredient["special_effect_params"].duplicate(true)
		var power_param := ""
		match special_effect:
			"brief_stun":
				power_param = "duration_sec"
			"bonus_satisfaction_burst":
				power_param = "amount"
		# reputation_small_restore scaling is deliberately deferred to UPG-02e.
		if not power_param.is_empty():
			if not _is_finite_number(special_effect_params.get(power_param)):
				return _failure(INVALID_CONTENT_STATE, "special effect power must be finite")
			# D4: this additional effect never receives satisfaction modifiers.
			var power := float(special_effect_params[power_param]) * special_multiplier
			if not is_finite(power):
				return _failure(INVALID_MODIFIERS, "special effect power must remain finite")
			special_effect_params[power_param] = power

	return {
		"ok": true,
		"recipe_id": str(recipe["id"]),
		"ingredient_id": ingredient_id,
		"chain_length": chain_length,
		"chain_tier": chain_tier,
		"base_satisfaction": base_satisfaction,
		"chain_multiplier": chain_multiplier,
		"satisfaction_final": satisfaction_final,
		"targeting": str(recipe["targeting"]),
		"special_effect_triggered": special_effect_triggered,
		"special_effect": special_effect,
		"special_effect_params": special_effect_params,
	}


func _failure(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": error_code,
		"message": message,
	}


func _is_finite_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
