extends SceneTree

const Save = preload("res://scripts/save/save_service.gd")
const VALID_TEXT := '{ "schema_version": 1, "record": 123, "coins": 456, "preferences": {"test_option": true} }\n'
const TEMP_TEXT := '{"schema_version":1,"record":999,"coins":888,"preferences":{"temporary":true}}'


class QuarantineProbe:
	extends "res://scripts/save/save_service.gd"

	var quarantine_error: Error = ERR_FILE_NO_PERMISSION
	var quarantine_calls := 0
	var destination := ""


	func _init(save_path: String) -> void:
		super(save_path)


	func _move_to_quarantine(quarantine_path: String) -> Error:
		quarantine_calls += 1
		destination = quarantine_path
		if quarantine_error != OK:
			return quarantine_error
		return super._move_to_quarantine(quarantine_path)


var failures := 0
var assertions := 0
var cases := 0
var platform_skips := 0
# Holding the DirAccess keeps every fixture isolated and alive until suite exit.
var temporary_directory: DirAccess


func _init() -> void:
	temporary_directory = DirAccess.create_temp("sav_02_")
	if temporary_directory == null:
		push_error("SAV-02 could not create an isolated temporary directory")
		quit(1)
		return
	_run_case(_test_missing)
	_run_case(_test_empty)
	_run_case(_test_truncated)
	_run_case(_test_invalid_json)
	_run_case(_test_partial_json)
	_run_case(_test_extra_field)
	_run_case(_test_invalid_values)
	_run_case(_test_incompatible_schema)
	_run_case(_test_valid_save)
	_run_case(_test_valid_save_with_partial_temporary)
	_run_case(_test_valid_save_with_valid_temporary)
	_run_case(_test_temporary_without_primary)
	_run_case(_test_invalid_save_with_temporary)
	_run_case(_test_existing_quarantine)
	_run_case(_test_failed_quarantine)
	_run_case(_test_wrong_structure)
	_run_case(_test_nonfinite_json)
	_run_case(_test_explicit_save_after_recovery)
	_run_case(_test_status_transitions)
	_run_case(_test_relative_path)
	_run_case(_test_missing_parent)
	_run_case(_test_primary_directory)
	_run_case(_test_quarantine_directory_collision)
	_run_case(_test_quarantine_link_collision)
	_run_case(_test_primary_link)
	_run_case(_test_read_permission_failure)
	_run_case(_test_primary_case_alias)
	_run_case(_test_quarantine_case_alias)
	_run_case(_test_invalid_utf8)
	if failures == 0:
		print("SAV-02 tests passed: %d cases, %d assertions, %d platform skips; safe quarantine, complete defaults, explicit load outcomes and filesystem failure preservation." % [cases, assertions, platform_skips])
		quit(0)
	else:
		push_error("SAV-02 tests failed: %d failures across %d cases and %d assertions" % [failures, cases, assertions])
		quit(1)


func _run_case(test_case: Callable) -> void:
	cases += 1
	test_case.call()


func _path(name: String) -> String:
	return temporary_directory.get_current_dir().path_join(name + ".json")


func _test_missing() -> void:
	var path := _path("missing")
	var service := Save.new(path)
	_expect(service.get_last_load_status() == Save.LoadStatus.NOT_LOADED, "construction has no load outcome")
	_set_fixture(service)
	_expect(service.load_save() == OK, "missing save permits startup")
	_expect(service.get_last_load_status() == Save.LoadStatus.MISSING, "missing save has a distinct outcome")
	_expect_defaults(service, "missing save")
	_expect(not FileAccess.file_exists(path), "missing save is not automatically written")
	_expect(not FileAccess.file_exists(path + ".corrupt"), "missing save does not create quarantine")


func _test_empty() -> void:
	_expect_recovery("empty", "")


func _test_truncated() -> void:
	_expect_recovery("truncated", '{"schema_version":1,"record":')


func _test_invalid_json() -> void:
	_expect_recovery("invalid_json", "This is not JSON.\n")


func _test_partial_json() -> void:
	var complete := {"schema_version": 1, "record": 100, "coins": 200, "preferences": {"partial": true}}
	for field in complete:
		var partial := complete.duplicate(true)
		partial.erase(field)
		_expect_recovery("missing_" + field, JSON.stringify(partial))
	_expect_recovery("only_record", '{"schema_version":1,"record":100}')


func _test_extra_field() -> void:
	_expect_recovery("extra", '{"schema_version":1,"record":100,"coins":200,"preferences":{},"unexpected":true}')


func _test_invalid_values() -> void:
	var invalid_counters: Array = [-1, 1.5, true, "12", null, Save.MAX_SAFE_INTEGER + 1, [], {}]
	for field in ["record", "coins"]:
		for index in invalid_counters.size():
			var state := {"schema_version": 1, "record": 100, "coins": 200, "preferences": {}}
			state[field] = invalid_counters[index]
			_expect_recovery("invalid_%s_%d" % [field, index], JSON.stringify(state))
	var invalid_preferences: Array = [null, [], true, 3, "preferences"]
	for index in invalid_preferences.size():
		var state := {"schema_version": 1, "record": 100, "coins": 200, "preferences": invalid_preferences[index]}
		_expect_recovery("invalid_preferences_%d" % index, JSON.stringify(state))
	var too_deep: Array = []
	for _level in range(Save.MAX_PREFERENCE_DEPTH + 2):
		too_deep = [too_deep]
	_expect_recovery("excessive_depth", JSON.stringify({"schema_version": 1, "record": 100, "coins": 200, "preferences": {"deep": too_deep}}))


func _test_incompatible_schema() -> void:
	var versions: Array = [999, 0, -1, 1.5, true, "1", null]
	for index in versions.size():
		_expect_recovery("schema_%d" % index, JSON.stringify({"schema_version": versions[index], "record": 100, "coins": 200, "preferences": {}}))


func _test_valid_save() -> void:
	# Hidden file also exercises parent listing with include_hidden enabled.
	var path := _path(".valid")
	if not _write_text(path, VALID_TEXT):
		return
	var service := Save.new(path)
	_expect(service.load_save() == OK, "valid save loads")
	_expect(service.get_last_load_status() == Save.LoadStatus.LOADED, "valid save reports normal load")
	_expect_fixture(service, "valid save")
	_expect(FileAccess.get_file_as_bytes(path) == VALID_TEXT.to_utf8_buffer(), "valid save remains byte-identical including original formatting")
	_expect(not FileAccess.file_exists(path + ".corrupt"), "valid save does not create quarantine")


func _test_valid_save_with_partial_temporary() -> void:
	_expect_valid_with_temporary("valid_partial_tmp", '{"schema_version":1,"record":')


func _test_valid_save_with_valid_temporary() -> void:
	_expect_valid_with_temporary("valid_other_tmp", TEMP_TEXT)


func _test_temporary_without_primary() -> void:
	for index in 2:
		var path := _path("only_tmp_%d" % index)
		var content := TEMP_TEXT if index == 0 else "{"
		if not _write_text(path + ".tmp", content):
			continue
		var service := Save.new(path)
		_set_fixture(service)
		_expect(service.load_save() == OK, "temporary without primary permits startup")
		_expect(service.get_last_load_status() == Save.LoadStatus.MISSING, "temporary is not treated as primary")
		_expect_defaults(service, "temporary without primary")
		_expect(not FileAccess.file_exists(path), "temporary is never promoted")
		_expect(FileAccess.get_file_as_bytes(path + ".tmp") == content.to_utf8_buffer(), "load leaves abandoned temporary byte-identical")


func _test_invalid_save_with_temporary() -> void:
	for index in 2:
		var name := "invalid_tmp_%d" % index
		var path := _path(name)
		var content := TEMP_TEXT if index == 0 else "{"
		if not _write_text(path + ".tmp", content):
			continue
		_expect_recovery(name, "corrupt primary")
		_expect(FileAccess.get_file_as_bytes(path + ".tmp") == content.to_utf8_buffer(), "recovery ignores both valid-looking and partial temporaries")


func _test_existing_quarantine() -> void:
	var path := _path("collision")
	if not _write_text(path + ".corrupt", VALID_TEXT) or not _write_text(path + ".corrupt.1", "older incident"):
		return
	_expect_recovery("collision", "new incident", ".corrupt.2")
	_expect(FileAccess.get_file_as_bytes(path + ".corrupt") == VALID_TEXT.to_utf8_buffer(), "existing valid quarantine remains byte-identical")
	_expect(FileAccess.get_file_as_bytes(path + ".corrupt.1") == "older incident".to_utf8_buffer(), "previous numbered quarantine remains byte-identical")
	# First free suffix is deterministic even when a later suffix already exists.
	var gap := _path("quarantine_gap")
	if not _write_text(gap + ".corrupt", "first") or not _write_text(gap + ".corrupt.2", "third"):
		return
	_expect_recovery("quarantine_gap", "fill first free slot", ".corrupt.1")
	_expect(FileAccess.get_file_as_bytes(gap + ".corrupt.2") == "third".to_utf8_buffer(), "quarantine search does not overwrite a later occupied suffix")


func _test_failed_quarantine() -> void:
	var path := _path("failed_quarantine")
	if not _write_text(path, "unrecoverable for now") or not _write_text(path + ".tmp", TEMP_TEXT):
		return
	var service := QuarantineProbe.new(path)
	_set_fixture(service)
	_expect(service.load_save() == ERR_FILE_NO_PERMISSION, "quarantine failure returns the filesystem error")
	_expect(service.get_last_load_status() == Save.LoadStatus.FAILED, "quarantine failure is not reported as recovered")
	_expect_fixture(service, "failed quarantine")
	_expect(service.quarantine_calls == 1 and service.destination == path + ".corrupt", "quarantine failure follows one local deterministic move attempt")
	_expect(FileAccess.get_file_as_bytes(path) == "unrecoverable for now".to_utf8_buffer(), "quarantine failure preserves source bytes")
	_expect(FileAccess.get_file_as_bytes(path + ".tmp") == TEMP_TEXT.to_utf8_buffer(), "quarantine failure preserves abandoned temporary")
	_expect(not FileAccess.file_exists(path + ".corrupt"), "quarantine failure writes no replacement or backup")


func _test_wrong_structure() -> void:
	var roots: Array = [null, true, 1, "text", [], [1, 2], {}]
	for index in roots.size():
		_expect_recovery("root_%d" % index, JSON.stringify(roots[index]))


func _test_nonfinite_json() -> void:
	# Overflow exponents exercise parser-produced infinities where accepted;
	# literal NaN/Infinity are safely rejected even when parser syntax rejects them.
	var numbers := ["1e999", "-1e999", "NaN", "Infinity"]
	for index in numbers.size():
		_expect_recovery("nonfinite_record_%d" % index, '{"schema_version":1,"record":%s,"coins":200,"preferences":{}}' % numbers[index])
		_expect_recovery("nonfinite_preference_%d" % index, '{"schema_version":1,"record":100,"coins":200,"preferences":{"value":%s}}' % numbers[index])


func _test_explicit_save_after_recovery() -> void:
	var path := _path("explicit_after_recovery")
	if not _write_text(path, "original corrupt bytes"):
		return
	var service := Save.new(path)
	_expect(service.load_save() == OK, "recovery succeeds before explicit save")
	_expect(not FileAccess.file_exists(path), "recovery does not create a replacement primary")
	_expect(service.save() == OK, "explicit save may persist recovered defaults")
	_expect(service.get_last_load_status() == Save.LoadStatus.RECOVERED, "save preserves the last load outcome")
	var loaded := Save.new(path)
	_expect(loaded.load_save() == OK and loaded.get_last_load_status() == Save.LoadStatus.LOADED, "explicit replacement is a valid normal save")
	_expect_defaults(loaded, "explicitly persisted defaults")
	_expect(FileAccess.get_file_as_bytes(path + ".corrupt") == "original corrupt bytes".to_utf8_buffer(), "explicit save preserves quarantine evidence")
	_set_fixture(loaded)
	_expect(loaded.save() == OK and service.load_save() == OK, "recovered service continues saving and loading later metadata")
	_expect_fixture(service, "continued use after recovery")


func _test_status_transitions() -> void:
	var path := _path("transitions")
	var service := QuarantineProbe.new(path)
	_expect(service.get_last_load_status() == Save.LoadStatus.NOT_LOADED, "fresh status is not loaded")
	_expect(service.load_save() == OK and service.get_last_load_status() == Save.LoadStatus.MISSING, "status transitions to missing")
	if not _write_text(path, VALID_TEXT):
		return
	_expect(service.load_save() == OK and service.get_last_load_status() == Save.LoadStatus.LOADED, "status transitions from missing to loaded")
	if not _write_text(path, "broken"):
		return
	_expect(service.load_save() != OK and service.get_last_load_status() == Save.LoadStatus.FAILED, "status transitions from loaded to technical failure")
	_expect_fixture(service, "retryable technical failure")
	service.quarantine_error = OK
	_expect(service.load_save() == OK and service.get_last_load_status() == Save.LoadStatus.RECOVERED, "retry transitions from failed to recovered")
	_expect_defaults(service, "successful retry")
	_expect(service.load_save() == OK and service.get_last_load_status() == Save.LoadStatus.MISSING, "next load replaces recovered status with missing")
	_expect(not FileAccess.file_exists(path + ".corrupt.1"), "repeated load does not re-quarantine an absent file")
	if not _write_text(path, VALID_TEXT):
		return
	_expect(service.load_save() == OK and service.get_last_load_status() == Save.LoadStatus.LOADED, "status returns to loaded when a valid save becomes available")
	_expect_fixture(service, "later valid save")


func _test_relative_path() -> void:
	var service := Save.new("sav_02_relative.json")
	_set_fixture(service)
	_expect(service.load_save() == ERR_INVALID_PARAMETER, "relative path is rejected before filesystem access")
	_expect(service.get_last_load_status() == Save.LoadStatus.FAILED, "relative path is a technical failure")
	_expect_fixture(service, "relative path failure")


func _test_missing_parent() -> void:
	var parent := temporary_directory.get_current_dir().path_join("nonexistent_parent")
	var service := Save.new(parent.path_join("save.json"))
	_set_fixture(service)
	_expect(service.load_save() != OK, "inaccessible nonexistent parent is not treated as missing save")
	_expect(service.get_last_load_status() == Save.LoadStatus.FAILED, "missing parent reports technical failure")
	_expect_fixture(service, "missing parent failure")
	_expect(not DirAccess.dir_exists_absolute(parent), "load does not create a missing parent")


func _test_primary_directory() -> void:
	var path := _path("primary_directory")
	_expect(DirAccess.make_dir_absolute(path) == OK, "primary directory fixture is created")
	var marker := path.path_join("untouched.txt")
	if not _write_text(marker, "directory contents"):
		return
	var service := Save.new(path)
	_set_fixture(service)
	_expect(service.load_save() != OK, "directory at primary path fails instead of recovering")
	_expect(service.get_last_load_status() == Save.LoadStatus.FAILED, "primary directory reports technical failure")
	_expect_fixture(service, "primary directory failure")
	_expect(DirAccess.dir_exists_absolute(path) and FileAccess.get_file_as_string(marker) == "directory contents", "primary directory and its content remain untouched")
	_expect(not DirAccess.dir_exists_absolute(path + ".corrupt"), "primary directory is not moved into quarantine")


func _test_quarantine_directory_collision() -> void:
	var path := _path("quarantine_directory")
	_expect(DirAccess.make_dir_absolute(path + ".corrupt") == OK, "quarantine directory collision fixture is created")
	_expect_recovery("quarantine_directory", "invalid save", ".corrupt.1")
	_expect(DirAccess.dir_exists_absolute(path + ".corrupt"), "existing quarantine directory is preserved")


func _test_quarantine_link_collision() -> void:
	if not _supports_links_and_permissions():
		return
	var path := _path("quarantine_link")
	var missing_target := _path("link_target_absent")
	_expect(temporary_directory.create_link(missing_target, path + ".corrupt") == OK, "dangling quarantine symlink fixture is created")
	_expect(temporary_directory.is_link(path + ".corrupt"), "quarantine collision is a dangling link")
	_expect_recovery("quarantine_link", "invalid save", ".corrupt.1")
	_expect(temporary_directory.is_link(path + ".corrupt"), "dangling quarantine link is preserved")
	_expect(temporary_directory.read_link(path + ".corrupt") == missing_target, "quarantine collision does not change the link target")
	_expect(not FileAccess.file_exists(missing_target), "quarantine collision does not create or follow link target")


func _test_primary_link() -> void:
	if not _supports_links_and_permissions():
		return
	for index in 2:
		var path := _path("primary_link_%d" % index)
		var target := _path("primary_link_target_%d" % index)
		if index == 0 and not _write_text(target, VALID_TEXT):
			continue
		_expect(temporary_directory.create_link(target, path) == OK, "primary symlink fixture is created")
		var service := Save.new(path)
		_set_fixture(service)
		_expect(service.load_save() != OK, "primary symlink fails for both existing and missing targets")
		_expect(service.get_last_load_status() == Save.LoadStatus.FAILED, "primary symlink reports technical failure")
		_expect_fixture(service, "primary symlink failure")
		_expect(temporary_directory.is_link(path) and temporary_directory.read_link(path) == target, "primary symlink is preserved without moving it")
		_expect(not temporary_directory.is_link(path + ".corrupt"), "primary symlink is not quarantined")
		if index == 0:
			_expect(FileAccess.get_file_as_bytes(target) == VALID_TEXT.to_utf8_buffer(), "primary symlink target remains byte-identical")
		else:
			_expect(not FileAccess.file_exists(target), "dangling primary link target remains absent")


func _test_read_permission_failure() -> void:
	if not _supports_links_and_permissions():
		return
	var path := _path("read_denied")
	if not _write_text(path, VALID_TEXT):
		return
	var original_permissions := FileAccess.get_unix_permissions(path)
	_expect(FileAccess.set_unix_permissions(path, 0) == OK, "read-denied fixture removes Unix permissions")
	var probe := FileAccess.open(path, FileAccess.READ)
	if probe != null:
		probe.close()
		_expect(FileAccess.set_unix_permissions(path, original_permissions) == OK, "permissions are restored when runtime bypasses permission checks")
		platform_skips += 1
		print("SAV-02 skip: runtime can read mode-000 files; injected quarantine error still verifies transactional failure.")
		return
	var service := Save.new(path)
	_set_fixture(service)
	var result: Error = service.load_save()
	# Restore before assertions so a failure cannot leave a locked test artifact.
	_expect(FileAccess.set_unix_permissions(path, original_permissions) == OK, "read-denied fixture permissions are restored")
	_expect(result != OK, "actual read denial returns a filesystem error")
	_expect(service.get_last_load_status() == Save.LoadStatus.FAILED, "actual read denial is not mistaken for a missing save")
	_expect_fixture(service, "actual read denial")
	_expect(FileAccess.get_file_as_bytes(path) == VALID_TEXT.to_utf8_buffer(), "actual read denial preserves the source bytes")
	_expect(not FileAccess.file_exists(path + ".corrupt"), "unreadable source is not treated as corrupt")


func _supports_links_and_permissions() -> bool:
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD"]:
		return true
	platform_skips += 1
	print("SAV-02 skip: Unix link/permission fixture is not supported on %s." % OS.get_name())
	return false


func _test_primary_case_alias() -> void:
	var path := _path("case_alias_primary")
	var actual_path := temporary_directory.get_current_dir().path_join("CASE_ALIAS_PRIMARY.JSON")
	if not _write_text(actual_path, VALID_TEXT):
		return
	var aliases := FileAccess.file_exists(path)
	var service := Save.new(path)
	_expect(service.load_save() == OK, "primary case alias is handled on either filesystem type")
	if aliases:
		_expect(service.get_last_load_status() == Save.LoadStatus.LOADED, "case-insensitive primary alias loads the existing file")
		_expect_fixture(service, "case-insensitive primary alias")
	else:
		_expect(service.get_last_load_status() == Save.LoadStatus.MISSING, "case-sensitive filesystem treats different primary spelling as absent")
		_expect_defaults(service, "case-sensitive primary spelling")
	_expect(FileAccess.get_file_as_bytes(actual_path) == VALID_TEXT.to_utf8_buffer(), "existing primary spelling remains byte-identical")


func _test_quarantine_case_alias() -> void:
	var path := _path("case_alias_quarantine")
	var previous_path := path + ".CORRUPT"
	if not _write_text(previous_path, VALID_TEXT):
		return
	var aliases := FileAccess.file_exists(path + ".corrupt")
	_expect_recovery("case_alias_quarantine", "new invalid bytes", ".corrupt.1" if aliases else ".corrupt")
	_expect(FileAccess.get_file_as_bytes(previous_path) == VALID_TEXT.to_utf8_buffer(), "differently cased quarantine is never overwritten")


func _test_invalid_utf8() -> void:
	var bytes := '{"schema_version":1,"record":100,"coins":200,"preferences":{"value":"'.to_utf8_buffer()
	bytes.append(255)
	bytes.append_array('"}}'.to_utf8_buffer())
	_expect_recovery_bytes("invalid_utf8", bytes)


func _expect_recovery(name: String, content: String, suffix: String = ".corrupt") -> void:
	_expect_recovery_bytes(name, content.to_utf8_buffer(), suffix)


func _expect_recovery_bytes(name: String, bytes: PackedByteArray, suffix: String = ".corrupt") -> void:
	var path := _path(name)
	if not _write_bytes(path, bytes):
		return
	var service := Save.new(path)
	_set_fixture(service)
	_expect(service.load_save() == OK, "%s permits startup after recovery" % name)
	_expect(service.get_last_load_status() == Save.LoadStatus.RECOVERED, "%s reports recovery distinctly" % name)
	_expect_defaults(service, name)
	_expect(not FileAccess.file_exists(path), "%s does not write defaults over the source" % name)
	_expect(FileAccess.file_exists(path + suffix), "%s has a deterministic quarantine" % name)
	_expect(FileAccess.get_file_as_bytes(path + suffix) == bytes, "%s preserves all original bytes in quarantine" % name)


func _expect_valid_with_temporary(name: String, content: String) -> void:
	var path := _path(name)
	if not _write_text(path, VALID_TEXT) or not _write_text(path + ".tmp", content):
		return
	var service := Save.new(path)
	_expect(service.load_save() == OK, "%s loads the primary successfully" % name)
	_expect(service.get_last_load_status() == Save.LoadStatus.LOADED, "%s reports normal primary load" % name)
	_expect_fixture(service, name)
	_expect(FileAccess.get_file_as_bytes(path) == VALID_TEXT.to_utf8_buffer(), "%s preserves valid primary byte for byte" % name)
	_expect(FileAccess.get_file_as_bytes(path + ".tmp") == content.to_utf8_buffer(), "%s neither promotes nor cleans the temporary" % name)
	_expect(not FileAccess.file_exists(path + ".corrupt"), "%s does not quarantine a valid primary" % name)


func _write_text(path: String, content: String) -> bool:
	return _write_bytes(path, content.to_utf8_buffer())


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "fixture opens only inside isolated temporary directory: %s" % path.get_file())
	if file == null:
		return false
	var stored := file.store_buffer(bytes)
	file.close()
	_expect(stored, "fixture stores complete test content")
	return stored


func _set_fixture(service) -> void:
	_expect(service.set_record(123) == OK, "fixture sets record 123")
	_expect(service.set_coins(456) == OK, "fixture sets coins 456")
	_expect(service.set_preference("test_option", true) == OK, "fixture sets generic preference")


func _expect_fixture(service, context: String) -> void:
	_expect(service.get_record() == 123, "%s preserves record 123" % context)
	_expect(service.get_coins() == 456, "%s preserves coins 456" % context)
	_expect(service.get_preferences() == {"test_option": true}, "%s preserves all preferences" % context)


func _expect_defaults(service, context: String) -> void:
	_expect(service.get_record() == 0, "%s has zero record" % context)
	_expect(service.get_coins() == 0, "%s has zero coins" % context)
	_expect(service.get_preferences() == {}, "%s has no partial preferences" % context)


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
