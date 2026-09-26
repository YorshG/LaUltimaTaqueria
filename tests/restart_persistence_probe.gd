extends SceneTree
## One operation per OS process, using only an explicit, marked fixture path.

const Save = preload("res://scripts/save/save_service.gd")
const MODES := ["write", "read", "recover", "missing-save", "verify-defaults"]
var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in MODES:
		push_error("TST-02 probe expects: <write|read|recover|missing-save|verify-defaults> <absolute fixture path>")
		quit(1)
		return
	var mode := args[0]
	var path := args[1].simplify_path()
	if (
		not path.is_absolute_path()
		or path.begins_with("user://") or path.begins_with("res://")
		or path == ProjectSettings.globalize_path(Save.DEFAULT_SAVE_PATH)
		or path.get_file() != "save.json"
		or not FileAccess.file_exists(path.get_base_dir().path_join(".tst-02-fixture"))
	):
		push_error("TST-02 probe requires an explicit save.json in a marked temporary fixture directory")
		quit(1)
		return
	var service := Save.new(path)
	_expect(service.get_last_load_status() == Save.LoadStatus.NOT_LOADED, "fresh load status")
	_expect_values(service, 0, 0, {})
	var status := "SAVED"
	if mode == "write":
		_expect(not FileAccess.file_exists(path), "write starts with no primary")
		_expect(service.set_record(123) == OK, "set record")
		_expect(service.set_coins(456) == OK, "set coins")
		_expect(service.set_preference("test_option", true) == OK, "set preference")
		if failures == 0:
			_expect(service.save() == OK, "explicit save")
	else:
		var expected_status := Save.LoadStatus.LOADED
		if mode == "recover":
			expected_status = Save.LoadStatus.RECOVERED
		elif mode == "missing-save":
			expected_status = Save.LoadStatus.MISSING
		_expect(service.load_save() == OK, "load succeeds")
		_expect(service.get_last_load_status() == expected_status, "expected load outcome")
		status = Save.LoadStatus.keys()[expected_status]
		if mode == "read":
			_expect_values(service, 123, 456, {"test_option": true})
		else:
			_expect_values(service, 0, 0, {})
		if mode in ["recover", "missing-save"]:
			_expect(not FileAccess.file_exists(path), "load does not implicitly write defaults")
		if mode == "missing-save" and failures == 0:
			_expect(service.save() == OK, "explicitly persist defaults after missing load")
	if failures == 0:
		print("TST-02 PROBE PASS: %s %s" % [mode, status])
		quit(0)
	else:
		push_error("TST-02 probe failed: %d assertions" % failures)
		quit(1)


func _expect_values(service, record: int, coins: int, preferences: Dictionary) -> void:
	_expect(service.get_record() == record, "exact record")
	_expect(service.get_coins() == coins, "exact coins")
	_expect(service.get_preferences() == preferences, "exact preferences")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("TST-02: " + message)
