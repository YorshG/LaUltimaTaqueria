class_name ContentRegistry
extends RefCounted

const CONTENT_PATHS := {
	"ingredients": "res://data/content/ingredients.json",
	"recipes": "res://data/content/recipes.json",
	"monsters": "res://data/content/monsters.json",
	"boss": "res://data/content/boss.json",
	"waves": "res://data/content/waves.json",
	"upgrades": "res://data/content/upgrades.json",
	"localization": "res://data/content/localization.es-MX.json",
}

const RARITIES := ["common", "rare", "epic"]
const TARGETING := ["nearest"]
const OPERATIONS := ["add", "multiply"]
const TAGS := ["offense", "defense", "utility", "strong_defense"]
const CONDITIONS := ["first_dish_of_encounter", "reputation_below_ratio"]
const SPECIAL_EFFECTS := ["brief_stun", "bonus_satisfaction_burst", "reputation_small_restore"]

const EFFECT_RULES := {
	"modify_satisfaction": {
		"pairs": [["satisfaction_multiplier", "multiply"], ["satisfaction_flat_bonus", "add"]],
	},
	"modify_chain_bonus": {
		"pairs": [["chain4_satisfaction_bonus", "add"]],
	},
	"modify_special_effect": {
		"pairs": [["special_effect_power_multiplier", "multiply"]],
	},
	"add_splash_satisfaction": {
		"pairs": [["chain4_splash_satisfaction", "add"]],
	},
	"conditional_satisfaction": {
		"pairs": [["satisfaction_multiplier", "multiply"]],
	},
	"modify_reputation": {
		"pairs": [["reputation_max", "add"], ["reputation_damage_taken", "multiply"]],
	},
	"grant_charge": {
		"pairs": [["reputation_shield_charges", "add"], ["extra_life_charges", "add"]],
	},
	"modify_monster_stat": {
		"pairs": [["monster_speed_global", "multiply"]],
	},
	"modify_input": {
		"pairs": [["input_forgiveness", "add"]],
	},
}

var _id_regex := RegEx.new()


func _init() -> void:
	_id_regex.compile("^[a-z][a-z0-9_]*$")


func load_and_validate() -> Dictionary:
	var load_errors: Array = []
	var content := load_content(load_errors)
	if not load_errors.is_empty():
		return {"ok": false, "errors": load_errors, "content": content}
	return validate_content(content)


func load_content(errors: Array = []) -> Dictionary:
	var content := {}
	for key in CONTENT_PATHS:
		var value = _read_json(CONTENT_PATHS[key], errors)
		content[key] = value
	return content


func validate_content(content: Dictionary) -> Dictionary:
	var errors: Array = []

	var ingredients = _expect_array(content, "ingredients", errors)
	var recipes = _expect_array(content, "recipes", errors)
	var monsters = _expect_array(content, "monsters", errors)
	var waves = _expect_array(content, "waves", errors)
	var upgrades = _expect_array(content, "upgrades", errors)
	var boss = content.get("boss", null)
	var localization = content.get("localization", null)

	if typeof(boss) != TYPE_DICTIONARY:
		errors.append("boss must be an object")
		boss = {}
	if typeof(localization) != TYPE_DICTIONARY:
		errors.append("localization must be an object")
		localization = {}

	var ingredient_index := _index_by_id(ingredients, "ingredient", errors)
	var recipe_index := _index_by_id(recipes, "recipe", errors)
	var monster_index := _index_by_id(monsters, "monster", errors)
	var wave_index := _index_by_id(waves, "wave", errors)
	var upgrade_index := _index_by_id(upgrades, "upgrade", errors)

	_validate_ingredients(ingredients, localization, errors)
	_validate_recipes(recipes, ingredient_index, localization, errors)
	_validate_monsters(monsters, localization, errors)
	_validate_boss(boss, localization, errors)
	_validate_waves(waves, monster_index, errors)
	_validate_upgrades(upgrades, upgrade_index, localization, errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"content": content,
		"indexes": {
			"ingredients": ingredient_index,
			"recipes": recipe_index,
			"monsters": monster_index,
			"waves": wave_index,
			"upgrades": upgrade_index,
		},
	}


func _read_json(path: String, errors: Array):
	if not FileAccess.file_exists(path):
		errors.append("missing content file: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("cannot open content file: %s" % path)
		return null
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		errors.append(
			"invalid JSON in %s at line %d: %s"
			% [path, parser.get_error_line(), parser.get_error_message()]
		)
		return null
	return parser.data


func _expect_array(content: Dictionary, key: String, errors: Array) -> Array:
	var value = content.get(key, null)
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s must be an array" % key)
		return []
	return value


func _index_by_id(items: Array, kind: String, errors: Array) -> Dictionary:
	var index := {}
	for i in range(items.size()):
		var item = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("%s[%d] must be an object" % [kind, i])
			continue
		var id = item.get("id", null)
		if typeof(id) != TYPE_STRING or id.is_empty():
			errors.append("%s[%d].id must be a non-empty string" % [kind, i])
			continue
		if _id_regex.search(id) == null:
			errors.append("%s id '%s' must be lower snake_case" % [kind, id])
		if index.has(id):
			errors.append("duplicate %s id: %s" % [kind, id])
		else:
			index[id] = item
	return index


func _validate_ingredients(items: Array, localization: Dictionary, errors: Array) -> void:
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "<missing>"))
		_require_localization(item.get("display_name_key"), localization, "ingredient %s" % id, errors)
		_require_positive_number(item.get("base_satisfaction"), "ingredient %s base_satisfaction" % id, errors)
		var tier = item.get("tier", null)
		if not _is_integer_number(tier) or int(tier) < 1:
			errors.append("ingredient %s tier must be an integer >= 1" % id)
		var effect = item.get("special_effect", null)
		if effect not in SPECIAL_EFFECTS:
			errors.append("ingredient %s has unsupported special_effect: %s" % [id, effect])
			continue
		var params = item.get("special_effect_params", null)
		if typeof(params) != TYPE_DICTIONARY:
			errors.append("ingredient %s special_effect_params must be an object" % id)
			continue
		match effect:
			"brief_stun":
				_require_positive_number(params.get("duration_sec"), "ingredient %s duration_sec" % id, errors)
			"bonus_satisfaction_burst", "reputation_small_restore":
				_require_positive_number(params.get("amount"), "ingredient %s amount" % id, errors)


func _validate_recipes(
	items: Array,
	ingredient_index: Dictionary,
	localization: Dictionary,
	errors: Array
) -> void:
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "<missing>"))
		_require_localization(item.get("display_name_key"), localization, "recipe %s" % id, errors)
		_require_positive_number(item.get("satisfaction"), "recipe %s satisfaction" % id, errors)
		if item.get("targeting", null) not in TARGETING:
			errors.append("recipe %s has unsupported targeting: %s" % [id, item.get("targeting")])
		var recipe_ingredients = item.get("ingredients", null)
		if typeof(recipe_ingredients) != TYPE_DICTIONARY or recipe_ingredients.size() != 1:
			errors.append("recipe %s must reference exactly one ingredient" % id)
			continue
		var ingredient_id = recipe_ingredients.keys()[0]
		if not ingredient_index.has(ingredient_id):
			errors.append("recipe %s references unknown ingredient: %s" % [id, ingredient_id])
			continue
		var count = recipe_ingredients[ingredient_id]
		if not _is_integer_number(count) or int(count) < 3:
			errors.append("recipe %s ingredient count must be an integer >= 3" % id)
		var expected_effect = ingredient_index[ingredient_id].get("special_effect", null)
		if item.get("effect", null) != expected_effect:
			errors.append(
				"recipe %s effect '%s' must match ingredient %s special_effect '%s'"
				% [id, item.get("effect"), ingredient_id, expected_effect]
			)


func _validate_monsters(items: Array, localization: Dictionary, errors: Array) -> void:
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "<missing>"))
		_require_localization(item.get("display_name_key"), localization, "monster %s" % id, errors)
		_require_positive_number(item.get("speed"), "monster %s speed" % id, errors)
		_require_positive_number(item.get("hunger"), "monster %s hunger" % id, errors)
		_require_non_negative_number(item.get("reputation_damage"), "monster %s reputation_damage" % id, errors)
		if typeof(item.get("tags", null)) != TYPE_ARRAY:
			errors.append("monster %s tags must be an array" % id)


func _validate_boss(item: Dictionary, localization: Dictionary, errors: Array) -> void:
	if item.is_empty():
		return
	var id = item.get("id", null)
	if typeof(id) != TYPE_STRING or _id_regex.search(id) == null:
		errors.append("boss id must be lower snake_case")
	_require_localization(item.get("display_name_key"), localization, "boss", errors)
	_require_positive_number(item.get("speed"), "boss speed", errors)
	_require_positive_number(item.get("hunger"), "boss hunger", errors)
	_require_non_negative_number(item.get("reputation_damage_on_breach"), "boss reputation_damage_on_breach", errors)
	var lane = item.get("lane", null)
	if not _is_integer_number(lane) or int(lane) < 0 or int(lane) > 2:
		errors.append("boss lane must be 0, 1, or 2")
	var phases = item.get("phases", null)
	if typeof(phases) != TYPE_ARRAY or phases.is_empty():
		errors.append("boss phases must be a non-empty array")
		return
	var previous_threshold := 2.0
	for i in range(phases.size()):
		var phase = phases[i]
		if typeof(phase) != TYPE_DICTIONARY:
			errors.append("boss phase %d must be an object" % i)
			continue
		var threshold = phase.get("threshold", null)
		if not _is_finite_number(threshold) or float(threshold) <= 0.0 or float(threshold) > 1.0:
			errors.append("boss phase %d threshold must be in (0, 1]" % i)
		elif float(threshold) >= previous_threshold:
			errors.append("boss phase thresholds must be strictly descending")
		else:
			previous_threshold = float(threshold)
		_require_positive_number(phase.get("speed_multiplier"), "boss phase %d speed_multiplier" % i, errors)


func _validate_waves(items: Array, monster_index: Dictionary, errors: Array) -> void:
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "<missing>"))
		_require_positive_number(item.get("duration_target_sec"), "wave %s duration_target_sec" % id, errors)
		var duration := float(item.get("duration_target_sec", 0.0))
		var spawns = item.get("spawns", null)
		if typeof(spawns) != TYPE_ARRAY:
			errors.append("wave %s spawns must be an array" % id)
			continue
		for i in range(spawns.size()):
			var spawn = spawns[i]
			if typeof(spawn) != TYPE_DICTIONARY:
				errors.append("wave %s spawn %d must be an object" % [id, i])
				continue
			var monster_id = spawn.get("monster_id", null)
			if typeof(monster_id) != TYPE_STRING or not monster_index.has(monster_id):
				errors.append("wave %s spawn %d references unknown monster: %s" % [id, i, monster_id])
			var lane = spawn.get("lane", null)
			if not _is_integer_number(lane) or int(lane) < 0 or int(lane) > 2:
				errors.append("wave %s spawn %d lane must be 0, 1, or 2" % [id, i])
			var at_sec = spawn.get("at_sec", null)
			if not _is_finite_number(at_sec) or float(at_sec) < 0.0:
				errors.append("wave %s spawn %d at_sec must be finite and >= 0" % [id, i])
			elif duration > 0.0 and float(at_sec) > duration:
				errors.append("wave %s spawn %d occurs after wave duration" % [id, i])


func _validate_upgrades(
	items: Array,
	upgrade_index: Dictionary,
	localization: Dictionary,
	errors: Array
) -> void:
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "<missing>"))
		_require_localization(item.get("display_name_key"), localization, "upgrade %s name" % id, errors)
		_require_localization(item.get("description_key"), localization, "upgrade %s description" % id, errors)
		if item.get("rarity", null) not in RARITIES:
			errors.append("upgrade %s has unsupported rarity: %s" % [id, item.get("rarity")])
		var tags = item.get("tags", null)
		if typeof(tags) != TYPE_ARRAY:
			errors.append("upgrade %s tags must be an array" % id)
		else:
			for tag in tags:
				if tag not in TAGS:
					errors.append("upgrade %s has unsupported tag: %s" % [id, tag])
		_validate_upgrade_effect(id, item.get("effect", null), errors)

	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", "<missing>"))
		var conflicts = _expect_string_array(item.get("conflicts", null), "upgrade %s conflicts" % id, errors)
		var synergies = _expect_string_array(item.get("synergies", null), "upgrade %s synergies" % id, errors)
		for target in conflicts:
			if target == id:
				errors.append("upgrade %s cannot conflict with itself" % id)
			elif not upgrade_index.has(target):
				errors.append("upgrade %s conflicts with unknown upgrade: %s" % [id, target])
			else:
				var reverse = upgrade_index[target].get("conflicts", [])
				if typeof(reverse) != TYPE_ARRAY or id not in reverse:
					errors.append("upgrade conflict must be symmetric: %s <-> %s" % [id, target])
		for target in synergies:
			if target == id:
				errors.append("upgrade %s cannot synergize with itself" % id)
			elif not upgrade_index.has(target):
				errors.append("upgrade %s synergizes with unknown upgrade: %s" % [id, target])
			else:
				var reverse = upgrade_index[target].get("synergies", [])
				if typeof(reverse) != TYPE_ARRAY or id not in reverse:
					errors.append("upgrade synergy must be symmetric: %s <-> %s" % [id, target])
			if target in conflicts:
				errors.append("upgrade %s cannot both conflict and synergize with %s" % [id, target])


func _validate_upgrade_effect(id: String, effect, errors: Array) -> void:
	if typeof(effect) != TYPE_DICTIONARY:
		errors.append("upgrade %s effect must be an object" % id)
		return
	var type = effect.get("type", null)
	if not EFFECT_RULES.has(type):
		errors.append("upgrade %s has unsupported effect.type: %s" % [id, type])
		return
	var stat = effect.get("stat", null)
	var operation = effect.get("operation", null)
	if operation not in OPERATIONS:
		errors.append("upgrade %s has unsupported operation: %s" % [id, operation])
	var allowed_pairs: Array = EFFECT_RULES[type]["pairs"]
	if [stat, operation] not in allowed_pairs:
		errors.append("upgrade %s has invalid stat/operation for %s: %s/%s" % [id, type, stat, operation])
	_require_finite_number(effect.get("value"), "upgrade %s effect.value" % id, errors)

	var params = effect.get("params", {})
	if typeof(params) != TYPE_DICTIONARY:
		errors.append("upgrade %s effect.params must be an object when present" % id)
		return

	if type == "conditional_satisfaction":
		var condition = params.get("condition", null)
		if condition not in CONDITIONS:
			errors.append("upgrade %s has unsupported condition: %s" % [id, condition])
		if condition == "reputation_below_ratio":
			_require_ratio(params.get("threshold"), "upgrade %s threshold" % id, errors)
		elif params.has("threshold"):
			errors.append("upgrade %s threshold is only valid with reputation_below_ratio" % id)
	elif type == "grant_charge":
		if stat == "extra_life_charges":
			_require_ratio(params.get("restore_ratio"), "upgrade %s restore_ratio" % id, errors)
		elif params.has("restore_ratio"):
			errors.append("upgrade %s restore_ratio is only valid for extra_life_charges" % id)
	elif not params.is_empty():
		errors.append("upgrade %s effect.params is not allowed for effect.type %s" % [id, type])


func _expect_string_array(value, label: String, errors: Array) -> Array:
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s must be an array" % label)
		return []
	for item in value:
		if typeof(item) != TYPE_STRING:
			errors.append("%s must contain only strings" % label)
			return []
	return value


func _require_localization(key, localization: Dictionary, label: String, errors: Array) -> void:
	if typeof(key) != TYPE_STRING or key.is_empty():
		errors.append("%s localization key must be a non-empty string" % label)
	elif not localization.has(key):
		errors.append("%s localization key is missing: %s" % [label, key])
	elif typeof(localization[key]) != TYPE_STRING or localization[key].is_empty():
		errors.append("%s localization text must be non-empty: %s" % [label, key])


func _require_positive_number(value, label: String, errors: Array) -> void:
	if not _is_finite_number(value) or float(value) <= 0.0:
		errors.append("%s must be finite and > 0" % label)


func _require_non_negative_number(value, label: String, errors: Array) -> void:
	if not _is_finite_number(value) or float(value) < 0.0:
		errors.append("%s must be finite and >= 0" % label)


func _require_finite_number(value, label: String, errors: Array) -> void:
	if not _is_finite_number(value):
		errors.append("%s must be finite" % label)


func _require_ratio(value, label: String, errors: Array) -> void:
	if not _is_finite_number(value) or float(value) < 0.0 or float(value) > 1.0:
		errors.append("%s must be in [0, 1]" % label)


func _is_integer_number(value) -> bool:
	if not _is_finite_number(value):
		return false
	var number := float(value)
	return is_equal_approx(number, round(number))


func _is_finite_number(value) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)
