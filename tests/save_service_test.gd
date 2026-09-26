extends SceneTree

const Save = preload("res://scripts/save/save_service.gd")


class AtomicProbe:
	extends "res://scripts/save/save_service.gd"

	var write_mode := "complete"
	var replacement_error: Error = OK
	var replacement_calls := 0
	var previous_bytes := PackedByteArray()
	var expected_serialized := ""
	var saw_previous_save := false
	var saw_complete_temporary := false
	var saw_sibling_temporary := false


	func _init(save_path: String) -> void:
		super(save_path)


	func _write_temporary(temp_path: String, serialized: String) -> Error:
		expected_serialized = serialized
		if write_mode == "complete":
			return super._write_temporary(temp_path, serialized)
		var file := FileAccess.open(temp_path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string("{")
		file.flush()
		file.close()
		return OK if write_mode == "partial_ok" else ERR_FILE_CANT_WRITE


	func _replace_temporary(temp_path: String) -> Error:
		replacement_calls += 1
		saw_previous_save = FileAccess.get_file_as_bytes(_save_path) == previous_bytes
		saw_sibling_temporary = temp_path == _save_path + ".tmp"
		var temporary_bytes := FileAccess.get_file_as_bytes(temp_path)
		var parsed: Variant = JSON.parse_string(temporary_bytes.get_string_from_utf8())
		saw_complete_temporary = (
			temporary_bytes == expected_serialized.to_utf8_buffer()
			and parsed is Dictionary
			and parsed.size() == 4
			and parsed.get("schema_version") == SCHEMA_VERSION
		)
		if replacement_error != OK:
			return replacement_error
		return super._replace_temporary(temp_path)


var failures := 0
var assertions := 0
var cases := 0
# Holding the DirAccess keeps the OS temporary directory alive until suite exit.
var temporary_directory: DirAccess


func _init() -> void:
	temporary_directory = DirAccess.create_temp("sav_01_")
	if temporary_directory == null:
		push_error("SAV-01 could not create an isolated temporary directory")
		quit(1)
		return
	_run_case(_test_initial_state)
	_run_case(_test_roundtrip_and_schema)
	_run_case(_test_record_validation)
	_run_case(_test_coins_validation)
	_run_case(_test_preferences)
	_run_case(_test_reset)
	_run_case(_test_atomic_replacement)
	_run_case(_test_failed_writes_preserve_save)
	_run_case(_test_failed_reset_preserves_state)
	_run_case(_test_invalid_load_preserves_state)
	if failures == 0:
		print("SAV-01 tests passed: %d cases, %d assertions; isolated JSON persistence, API validation, reset and atomic replacement." % [cases, assertions])
		quit(0)
	else:
		push_error("SAV-01 tests failed: %d failures across %d cases and %d assertions" % [failures, cases, assertions])
		quit(1)


func _run_case(test_case: Callable) -> void:
	cases += 1
	test_case.call()


func _path(name: String) -> String:
	return temporary_directory.get_current_dir().path_join(name + ".json")


func _test_initial_state() -> void:
	var path := _path("initial")
	var service := Save.new(path)
	_expect(Save.SCHEMA_VERSION == 1, "SAV-01 schema version is explicit")
	_expect(Save.DEFAULT_SAVE_PATH == "user://save.json", "production save path is explicit")
	_expect(not FileAccess.file_exists(path), "construction performs no disk write")
	_expect(service.load_save() == OK, "missing save loads successfully")
	_expect_defaults(service, "missing save")
	_expect(not FileAccess.file_exists(path), "loading a missing save does not create it")
	_expect(not FileAccess.file_exists(path + ".tmp"), "loading a missing save leaves no temporary")
	var relative := Save.new("sav_01_relative.json")
	_expect(relative.load_save() == ERR_INVALID_PARAMETER, "relative save path is rejected before filesystem access")


func _test_roundtrip_and_schema() -> void:
	var path := _path("roundtrip")
	var service := Save.new(path)
	_set_fixture(service)
	_expect(not FileAccess.file_exists(path), "setters only change memory until explicit save")
	_expect(service.save() == OK, "record, coins and generic preference save")
	var loaded := Save.new(path)
	_expect_defaults(loaded, "new service before explicit load")
	_expect(loaded.load_save() == OK, "a new instance loads the persisted file")
	_expect_fixture(loaded, "roundtrip")
	var parser := JSON.new()
	_expect(parser.parse(FileAccess.get_file_as_string(path)) == OK, "save is auditable JSON")
	var document: Variant = parser.data
	_expect(document is Dictionary, "save root is a dictionary")
	if document is Dictionary:
		var keys: Array = document.keys()
		keys.sort()
		_expect(keys == ["coins", "preferences", "record", "schema_version"], "save contains only the four approved fields")
		_expect(document.get("schema_version") == Save.SCHEMA_VERSION, "current schema version is always persisted")
		_expect(document == {"schema_version": float(Save.SCHEMA_VERSION), "record": 123.0, "coins": 456.0, "preferences": {"test_option": true}}, "serialized document contains exactly the requested values")
	_expect(loaded.set_record(12) == OK, "record may be explicitly replaced without gameplay scoring or a max rule")
	_expect(loaded.save() == OK, "updated record saves")
	var updated := Save.new(path)
	_expect(updated.load_save() == OK and updated.get_record() == 12, "updated record survives another instance")
	_expect(updated.get_coins() == 456 and updated.get_preferences() == {"test_option": true}, "record update preserves other values")


func _test_record_validation() -> void:
	var service := Save.new(_path("record"))
	_expect(service.set_record(42) == OK, "nonnegative integer record is accepted")
	for invalid in [-1, true, 1.0, "1", null, Save.MAX_SAFE_INTEGER + 1]:
		_expect(service.set_record(invalid) != OK, "invalid record is rejected: %s" % str(invalid))
		_expect(service.get_record() == 42, "rejected record preserves the previous value")
	_expect(service.set_record(Save.MAX_SAFE_INTEGER) == OK, "largest exact JSON integer record is accepted")
	_expect(service.save() == OK, "maximum record saves")
	var loaded := Save.new(_path("record"))
	_expect(loaded.load_save() == OK and loaded.get_record() == Save.MAX_SAFE_INTEGER, "maximum record roundtrips exactly")
	_expect(service.set_record(0) == OK and service.get_record() == 0, "zero record is accepted")


func _test_coins_validation() -> void:
	var path := _path("coins")
	var service := Save.new(path)
	_expect(service.set_coins(10) == OK, "set_coins accepts a nonnegative integer")
	for invalid in [-1, true, 1.0, "1", null, Save.MAX_SAFE_INTEGER + 1]:
		_expect(service.set_coins(invalid) != OK, "invalid coin total is rejected: %s" % str(invalid))
		_expect(service.get_coins() == 10, "rejected coin total preserves state")
	for invalid in [true, 1.0, "1", null, Save.MAX_SAFE_INTEGER + 1, -Save.MAX_SAFE_INTEGER - 1]:
		_expect(service.add_coins(invalid) != OK, "invalid coin delta is rejected: %s" % str(invalid))
		_expect(service.get_coins() == 10, "rejected coin delta preserves state")
	_expect(service.add_coins(-11) != OK and service.get_coins() == 10, "delta producing negative coins is rejected")
	_expect(service.add_coins(5) == OK and service.add_coins(-3) == OK, "generic signed adjustment accepts a valid resulting total")
	_expect(service.get_coins() == 12 and service.save() == OK, "set/add total saves")
	var loaded := Save.new(path)
	_expect(loaded.load_save() == OK and loaded.get_coins() == 12, "set/add total survives reload")
	_expect(service.set_coins(Save.MAX_SAFE_INTEGER) == OK, "maximum exact coin total is accepted")
	_expect(service.add_coins(1) != OK and service.get_coins() == Save.MAX_SAFE_INTEGER, "coin overflow is rejected without changing state")
	_expect(service.save() == OK and loaded.load_save() == OK and loaded.get_coins() == Save.MAX_SAFE_INTEGER, "maximum coin total roundtrips exactly")
	_expect(service.add_coins(-Save.MAX_SAFE_INTEGER) == OK and service.get_coins() == 0, "valid adjustment may reach zero")


func _test_preferences() -> void:
	var path := _path("preferences")
	var service := Save.new(path)
	var supplied := {"items": [null, true, "México", -7, 0.125, {"nested": "original"}, 1.2345678901234567, Save.MAX_SAFE_INTEGER, -Save.MAX_SAFE_INTEGER]}
	var expected := supplied.duplicate(true)
	_expect(service.set_preference("test_value", supplied) == OK, "JSON-safe nested generic preference is accepted")
	supplied["items"][5]["nested"] = "changed outside service"
	_expect(service.get_preference("test_value") == expected, "preference setter takes a deep copy")
	var snapshot: Dictionary = service.get_preferences()
	snapshot["test_value"]["items"].append("external")
	_expect(service.get_preference("test_value") == expected, "preferences getter returns a deep copy")
	var selected: Dictionary = service.get_preference("test_value")
	selected["items"][5]["nested"] = "changed getter"
	_expect(service.get_preference("test_value") == expected, "single preference getter returns a deep copy")
	var fallback := ["default"]
	var returned_fallback: Array = service.get_preference("missing", fallback)
	returned_fallback.append("changed")
	_expect(fallback == ["default"] and service.get_preference("missing") == null, "missing preference returns a copied fallback without inserting it")
	for invalid in [Vector2.ONE, RefCounted.new(), INF, NAN, {1: "non-string key"}, PackedByteArray([1]), Save.MAX_SAFE_INTEGER + 1]:
		_expect(service.set_preference("test_value", invalid) != OK, "non-JSON-safe preference is rejected")
		_expect(service.get_preference("test_value") == expected, "invalid preference cannot replace valid data")
	var cyclic_array: Array = []
	cyclic_array.append(cyclic_array)
	_expect(service.set_preference("cycle", cyclic_array) != OK, "cyclic array preference is rejected without recursion failure")
	cyclic_array.clear()
	var cyclic_dictionary: Dictionary = {}
	cyclic_dictionary["self"] = cyclic_dictionary
	_expect(service.set_preference("cycle", cyclic_dictionary) != OK, "cyclic dictionary preference is rejected without recursion failure")
	cyclic_dictionary.clear()
	var too_deep: Array = []
	for _level in range(Save.MAX_PREFERENCE_DEPTH + 2):
		too_deep = [too_deep]
	_expect(service.set_preference("deep", too_deep) != OK, "excessive preference nesting is rejected")
	_expect(service.save() == OK, "valid preferences remain serializable after rejected updates")
	var loaded := Save.new(path)
	# JSON numbers load as floats; compare explicit values, including full precision.
	var expected_loaded := {"items": [null, true, "México", -7.0, 0.125, {"nested": "original"}, 1.2345678901234567, float(Save.MAX_SAFE_INTEGER), float(-Save.MAX_SAFE_INTEGER)]}
	_expect(loaded.load_save() == OK and loaded.get_preferences() == {"test_value": expected_loaded}, "only accepted preferences survive reload with exact numeric values")


func _test_reset() -> void:
	var path := _path("reset")
	var service := Save.new(path)
	_set_fixture(service)
	_expect(service.save() == OK, "reset fixture saves")
	_expect(service.reset() == OK, "explicit reset succeeds")
	_expect_defaults(service, "reset in memory")
	var loaded := Save.new(path)
	_expect(loaded.load_save() == OK, "reset persisted without a separate save call")
	_expect_defaults(loaded, "reset after reload")
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(document == {"schema_version": float(Save.SCHEMA_VERSION), "record": 0.0, "coins": 0.0, "preferences": {}}, "reset retains only the versioned defaults")


func _test_atomic_replacement() -> void:
	var path := _path("atomic_success")
	var original := Save.new(path)
	_set_fixture(original)
	_expect(original.save() == OK, "atomic replacement fixture saves")
	var service := AtomicProbe.new(path)
	service.previous_bytes = FileAccess.get_file_as_bytes(path)
	_expect(service.load_save() == OK and service.set_record(789) == OK, "replacement prepares a new state")
	_expect(service.save() == OK, "atomic replacement succeeds")
	_expect(service.replacement_calls == 1, "save uses the replacement step exactly once")
	_expect(service.saw_previous_save, "last valid save remains byte-identical until replacement")
	_expect(service.saw_complete_temporary and service.saw_sibling_temporary, "replacement receives complete JSON in the destination's sibling temporary")
	_expect(not FileAccess.file_exists(path + ".tmp"), "successful replacement leaves no temporary file")
	var loaded := Save.new(path)
	_expect(loaded.load_save() == OK and loaded.get_record() == 789, "replacement is visible to a new service")


func _test_failed_writes_preserve_save() -> void:
	for mode in ["write_error", "partial_ok", "replace_error"]:
		var path := _path(mode)
		var original := Save.new(path)
		_set_fixture(original)
		_expect(original.save() == OK, "%s fixture saves" % mode)
		var previous_bytes := FileAccess.get_file_as_bytes(path)
		var service := AtomicProbe.new(path)
		service.previous_bytes = previous_bytes
		service.write_mode = "complete" if mode == "replace_error" else mode
		service.replacement_error = ERR_CANT_CREATE if mode == "replace_error" else OK
		_expect(service.load_save() == OK and service.set_record(999) == OK, "%s prepares replacement state" % mode)
		_expect(service.save() != OK, "%s is reported to caller" % mode)
		_expect(FileAccess.get_file_as_bytes(path) == previous_bytes, "%s preserves the last save byte for byte" % mode)
		_expect(not FileAccess.file_exists(path + ".tmp"), "%s cleans its failed temporary" % mode)
		_expect(service.get_record() == 999, "%s keeps the caller's unsaved in-memory state" % mode)
		var loaded := Save.new(path)
		_expect(loaded.load_save() == OK, "%s leaves a loadable previous save" % mode)
		_expect_fixture(loaded, mode)
		if mode == "replace_error":
			_expect(service.replacement_calls == 1 and service.saw_previous_save and service.saw_complete_temporary, "replacement failure occurs after valid temporary creation and before destination change")
		else:
			_expect(service.replacement_calls == 0, "%s never reaches replacement" % mode)


func _test_failed_reset_preserves_state() -> void:
	var path := _path("reset_failure")
	var original := Save.new(path)
	_set_fixture(original)
	_expect(original.save() == OK, "failed reset fixture saves")
	var previous_bytes := FileAccess.get_file_as_bytes(path)
	var service := AtomicProbe.new(path)
	service.replacement_error = ERR_CANT_CREATE
	_expect(service.load_save() == OK and service.set_record(999) == OK, "failed reset has distinct in-memory state")
	_expect(service.reset() != OK, "reset reports replacement failure")
	_expect(service.get_record() == 999 and service.get_coins() == 456 and service.get_preferences() == {"test_option": true}, "failed reset preserves all in-memory values")
	_expect(FileAccess.get_file_as_bytes(path) == previous_bytes, "failed reset preserves the previous file byte for byte")
	_expect(not FileAccess.file_exists(path + ".tmp"), "failed reset cleans its temporary")
	var loaded := Save.new(path)
	_expect(loaded.load_save() == OK, "previous save still loads after failed reset")
	_expect_fixture(loaded, "failed reset")


func _test_invalid_load_preserves_state() -> void:
	# Minimal validation smoke only; corruption recovery and migrations belong to SAV-02.
	var path := _path("invalid_load")
	var service := Save.new(path)
	_set_fixture(service)
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "invalid input fixture opens in the isolated directory")
	if file == null:
		return
	file.store_string(JSON.stringify({"schema_version": Save.SCHEMA_VERSION, "record": -1, "coins": 0, "preferences": {}}))
	file.close()
	var previous_bytes := FileAccess.get_file_as_bytes(path)
	_expect(service.load_save() != OK, "invalid persisted value is reported without crashing")
	_expect_fixture(service, "rejected load")
	_expect(FileAccess.get_file_as_bytes(path) == previous_bytes, "rejected load does not silently rewrite the source file")


func _set_fixture(service) -> void:
	_expect(service.set_record(123) == OK, "fixture sets record 123")
	_expect(service.set_coins(456) == OK, "fixture sets coins 456")
	_expect(service.set_preference("test_option", true) == OK, "fixture sets generic test_option")


func _expect_fixture(service, context: String) -> void:
	_expect(service.get_record() == 123, "%s preserves record 123" % context)
	_expect(service.get_coins() == 456, "%s preserves coins 456" % context)
	_expect(service.get_preferences() == {"test_option": true}, "%s preserves exactly the generic preference" % context)


func _expect_defaults(service, context: String) -> void:
	_expect(service.get_record() == 0, "%s has zero record" % context)
	_expect(service.get_coins() == 0, "%s has zero coins" % context)
	_expect(service.get_preferences() == {}, "%s has no preferences" % context)


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
