extends SceneTree

var failures := 0
var Registry = preload("res://scripts/content/content_registry.gd")


func _init() -> void:
	var registry = Registry.new()
	var result = registry.load_and_validate()
	_expect(result["ok"], "default content must validate", result["errors"])

	if result["ok"]:
		var valid_content: Dictionary = result["content"]
		_test_duplicate_id(registry, valid_content)
		_test_broken_recipe_reference(registry, valid_content)
		_test_invalid_wave_lane(registry, valid_content)
		_test_missing_localization(registry, valid_content)
		_test_unknown_effect_type(registry, valid_content)
		_test_recipe_effect_mismatch(registry, valid_content)
		_test_asymmetric_conflict(registry, valid_content)

	if failures == 0:
		print("ContentRegistry tests passed.")
		quit(0)
	else:
		push_error("ContentRegistry tests failed: %d" % failures)
		quit(1)


func _test_duplicate_id(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	content["ingredients"].append(content["ingredients"][0].duplicate(true))
	_expect_rejected(registry, content, "duplicate ingredient id")


func _test_broken_recipe_reference(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	content["recipes"][0]["ingredients"] = {"missing_ingredient": 3}
	_expect_rejected(registry, content, "unknown ingredient")


func _test_invalid_wave_lane(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	content["waves"][0]["spawns"][0]["lane"] = 3
	_expect_rejected(registry, content, "lane must be 0, 1, or 2")


func _test_missing_localization(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	content["localization"].erase(content["monsters"][0]["display_name_key"])
	_expect_rejected(registry, content, "localization key is missing")


func _test_unknown_effect_type(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	content["upgrades"][0]["effect"]["type"] = "execute_arbitrary_script"
	_expect_rejected(registry, content, "unsupported effect.type")


func _test_recipe_effect_mismatch(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	content["recipes"][0]["effect"] = "reputation_small_restore"
	_expect_rejected(registry, content, "must match ingredient")


func _test_asymmetric_conflict(registry, source: Dictionary) -> void:
	var content := source.duplicate(true)
	var a: Dictionary = content["upgrades"][0]
	var b: Dictionary = content["upgrades"][1]
	if b["id"] not in a["conflicts"]:
		a["conflicts"].append(b["id"])
	b["conflicts"].erase(a["id"])
	_expect_rejected(registry, content, "conflict must be symmetric")


func _expect_rejected(registry, content: Dictionary, needle: String) -> void:
	var result = registry.validate_content(content)
	_expect(not result["ok"], "mutated content must be rejected: %s" % needle, result["errors"])
	if result["ok"]:
		return
	var found := false
	for error in result["errors"]:
		if needle in str(error):
			found = true
			break
	_expect(found, "error list must mention '%s'" % needle, result["errors"])


func _expect(condition: bool, message: String, details = null) -> void:
	if condition:
		return
	failures += 1
	push_error("%s | %s" % [message, details])
