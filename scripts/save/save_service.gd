class_name SaveService
extends RefCounted
## Local metadata only. No scene, gameplay or Autoload dependencies.
## Setters stage changes in memory; call save() explicitly to persist them.
## Use one synchronous writer per path. Concurrent writers are not supported.

const SCHEMA_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"
# JSON parses numbers as doubles: do not silently round integer metadata.
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_PREFERENCE_DEPTH := 32

# load_save() keeps its Error return; this reports the last attempted load.
enum LoadStatus { NOT_LOADED, LOADED, MISSING, RECOVERED, FAILED }

var _save_path: String
var _record := 0
var _coins := 0
var _preferences: Dictionary = {}
var _last_load_status := LoadStatus.NOT_LOADED


# Construction has no filesystem side effects; tests inject an absolute path.
func _init(save_path: String = DEFAULT_SAVE_PATH) -> void:
	_save_path = save_path


# OK means a valid file loaded, a confirmed missing file yielded defaults, or
# invalid data was safely quarantined before adopting complete defaults.
# No defaults are written here. Any filesystem failure preserves memory.
# A leftover .tmp is ignored and left untouched, never promoted or parsed.
# Unsupported schemas follow the same quarantine policy; no migration occurs.
func load_save() -> Error:
	_last_load_status = LoadStatus.FAILED
	if not _valid_path():
		return ERR_INVALID_PARAMETER
	var directory := DirAccess.open(_save_path.get_base_dir())
	if directory == null:
		return DirAccess.get_open_error()
	# An existence check alone can confuse inaccessible files with absence.
	# A successful listing also reserves all occupied quarantine names, including
	# directories, hidden entries and dangling links, under the single-writer rule.
	directory.include_hidden = true
	var listing_error := directory.list_dir_begin()
	if listing_error != OK:
		return listing_error
	var entries: Dictionary = {}
	var entry := directory.get_next()
	while not entry.is_empty():
		entries[entry] = true
		entry = directory.get_next()
	directory.list_dir_end()
	var filename := _save_path.get_file()
	if not _has_entry(directory, entries, filename):
		_adopt(_defaults())
		_last_load_status = LoadStatus.MISSING
		return OK
	# Recovery only moves regular local files, never directories or links.
	if directory.dir_exists(filename) or directory.is_link(filename):
		return ERR_FILE_CANT_OPEN
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := file.get_buffer(file.get_length())
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return read_error
	var decoded := bytes.get_string_from_utf8()
	var parser := JSON.new()
	# Decoding must not silently replace corrupt UTF-8 inside otherwise valid JSON.
	if decoded.to_utf8_buffer() == bytes and parser.parse(decoded) == OK and _valid_state(parser.data):
		_adopt(parser.data)
		_last_load_status = LoadStatus.LOADED
		return OK
	# First free deterministic sibling: .corrupt, .corrupt.1, .corrupt.2, ...
	# Keep every prior incident byte-for-byte; no rotation or automatic cleanup.
	var quarantine_name := filename + ".corrupt"
	var suffix := 0
	while _has_entry(directory, entries, quarantine_name):
		suffix += 1
		quarantine_name = filename + ".corrupt.%d" % suffix
	var result := _move_to_quarantine(_save_path.get_base_dir().path_join(quarantine_name))
	if result != OK:
		return result
	_adopt(_defaults())
	_last_load_status = LoadStatus.RECOVERED
	return OK


# Describes only load_save(); setters, save() and reset() do not change it.
func get_last_load_status() -> LoadStatus:
	return _last_load_status


func _has_entry(directory: DirAccess, entries: Dictionary, filename: String) -> bool:
	# Listing finds inaccessible entries; filesystem checks also catch aliases
	# on case-insensitive filesystems (e.g. .CORRUPT must reserve .corrupt).
	return (
		entries.has(filename)
		or directory.file_exists(filename)
		or directory.dir_exists(filename)
		or directory.is_link(filename)
	)


func _move_to_quarantine(quarantine_path: String) -> Error:
	# Same filesystem rename preserves the rejected bytes. As with save(),
	# concurrent writers to this path are unsupported.
	return DirAccess.rename_absolute(_save_path, quarantine_path)


func save() -> Error:
	return _save_state({
		"schema_version": SCHEMA_VERSION,
		"record": _record,
		"coins": _coins,
		"preferences": _preferences,
	})


func get_record() -> int:
	return _record


# Stores the caller's value exactly; does not calculate or compare scores.
func set_record(value: Variant) -> Error:
	if typeof(value) != TYPE_INT or value < 0 or value > MAX_SAFE_INTEGER:
		return ERR_INVALID_PARAMETER
	_record = value
	return OK


func get_coins() -> int:
	return _coins


func set_coins(value: Variant) -> Error:
	if typeof(value) != TYPE_INT or value < 0 or value > MAX_SAFE_INTEGER:
		return ERR_INVALID_PARAMETER
	_coins = value
	return OK


func add_coins(amount: Variant) -> Error:
	if typeof(amount) != TYPE_INT:
		return ERR_INVALID_PARAMETER
	# Check before addition, including both JSON precision and integer overflow.
	if amount < -_coins or amount > MAX_SAFE_INTEGER - _coins:
		return ERR_INVALID_PARAMETER
	_coins += amount
	return OK


func get_preferences() -> Dictionary:
	return _preferences.duplicate(true)


func get_preference(key: String, default_value: Variant = null) -> Variant:
	return _copy_value(_preferences.get(key, default_value))


# JSON has one number type: numeric preferences load as floats, with their
# values preserved. Record and coins are explicitly restored as integers.
func set_preference(key: String, value: Variant) -> Error:
	# Depth starts at one because the preferences dictionary is the root.
	if not _valid_json_value(value, 1):
		return ERR_INVALID_PARAMETER
	_preferences[key] = _copy_value(value)
	return OK


# Explicit durable reset: failure preserves both the file and in-memory state.
func reset() -> Error:
	var defaults := _defaults()
	var result := _save_state(defaults)
	if result == OK:
		_adopt(defaults)
	return result


func _defaults() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "record": 0, "coins": 0, "preferences": {}}


func _adopt(state: Dictionary) -> void:
	_record = int(state["record"])
	_coins = int(state["coins"])
	_preferences = state["preferences"].duplicate(true)


func _valid_path() -> bool:
	return _save_path.is_absolute_path() and not _save_path.get_file().is_empty()


func _valid_state(state: Variant) -> bool:
	if not state is Dictionary or state.size() != 4:
		return false
	for key in ["schema_version", "record", "coins", "preferences"]:
		if not state.has(key):
			return false
	return (
		_valid_counter(state["schema_version"])
		and state["schema_version"] == SCHEMA_VERSION
		and _valid_counter(state["record"])
		and _valid_counter(state["coins"])
		and state["preferences"] is Dictionary
		and _valid_json_value(state["preferences"])
	)


func _valid_counter(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value >= 0 and value <= MAX_SAFE_INTEGER
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value >= 0 and value <= MAX_SAFE_INTEGER and value == floor(value)
	return false


# Only JSON data can enter preferences: no objects, resources or engine values.
# A depth bound also rejects cycles without recursive duplication/serialization.
func _valid_json_value(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_PREFERENCE_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not _valid_json_value(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING or not _valid_json_value(value[key], depth + 1):
					return false
			return true
	return false


func _copy_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _save_state(state: Dictionary) -> Error:
	if not _valid_path():
		return ERR_INVALID_PARAMETER
	if not _valid_state(state):
		return ERR_INVALID_DATA
	var serialized := JSON.stringify(state, "\t", true, true) + "\n"
	# Sibling temporary file keeps replacement on the same local filesystem.
	var temp_path := _save_path + ".tmp"
	var result := _write_temporary(temp_path, serialized)
	if result == OK:
		# Verify the closed file, catching incomplete writes before replacement.
		var file := FileAccess.open(temp_path, FileAccess.READ)
		if file == null:
			result = FileAccess.get_open_error()
		else:
			var bytes := file.get_buffer(file.get_length())
			result = file.get_error()
			file.close()
			if result == OK and bytes != serialized.to_utf8_buffer():
				result = ERR_FILE_CORRUPT
	if result == OK:
		result = _replace_temporary(temp_path)
	if result != OK and FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	return result


func _write_temporary(temp_path: String, serialized: String) -> Error:
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_string(serialized)
	var result := file.get_error()
	if not stored and result == OK:
		result = ERR_FILE_CANT_WRITE
	if result == OK:
		file.flush()
		result = file.get_error()
	file.close()
	return result


func _replace_temporary(temp_path: String) -> Error:
	# Never truncate, remove or open the destination for writing. On the target
	# local POSIX filesystems, rename replaces the old file atomically.
	# This is not a guarantee of hardware/power-loss durability (directory fsync).
	return DirAccess.rename_absolute(temp_path, _save_path)
