## Standalone scene only; never attached to Main or enabled by the normal project.
extends Control

const BOARD = preload("res://scenes/board/BoardView.tscn")
const ProbeChain = preload("res://tests/inp_probe_chain.gd")
var board: BoardView
var status: Label
var gesture_probe_seq := 0
var counts := {"raw": 0, "chain_started": 0, "try_add": 0, "chain_completed": 0, "chain_cancelled": 0}
var records: Array[Dictionary] = []
var retain_records := false
var _last_press_usec := -1000000
var _last_press_position := Vector2(-10000, -10000)
var _last_press_type := ""
var _original_emulation := true
var _log: FileAccess
var _log_path := ""
var _test_layout := false

func _ready() -> void:
	_original_emulation = Input.is_emulating_mouse_from_touch()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 180
	status.max_lines_visible = 4
	status.clip_text = true
	status.add_theme_font_size_override("font_size", 28)
	column.add_child(status)
	var reset := Button.new()
	reset.text = "Restablecer tablero y contadores"
	reset.custom_minimum_size.y = 88
	reset.add_theme_font_size_override("font_size", 28)
	reset.pressed.connect(reset_probe)
	column.add_child(reset)
	var experiment := CheckButton.new()
	experiment.text = "B experimental: desactivar mouse desde touch"
	experiment.custom_minimum_size.y = 88
	experiment.add_theme_font_size_override("font_size", 28)
	experiment.toggled.connect(func(enabled: bool):
		Input.set_emulate_mouse_from_touch(false if enabled else _original_emulation)
		_record("scenario", {"scenario": "B" if enabled else "A", "emulate_mouse_from_touch": Input.is_emulating_mouse_from_touch()})
		_refresh())
	column.add_child(experiment)
	var forgiveness := CheckButton.new()
	forgiveness.text = "Margen experimental de celda: 0.1"
	forgiveness.custom_minimum_size.y = 88
	forgiveness.add_theme_font_size_override("font_size", 28)
	forgiveness.toggled.connect(func(enabled: bool):
		board.set_input_forgiveness(0.1 if enabled else 0.0)
		_record("forgiveness", {"value": board.get_input_forgiveness()}))
	column.add_child(forgiveness)
	var fixture := CheckButton.new()
	fixture.text = "Fixture: dos filas T para cadenas 3/4/5 y zig-zag"
	fixture.custom_minimum_size.y = 88
	fixture.add_theme_font_size_override("font_size", 28)
	fixture.toggled.connect(func(enabled: bool):
		_test_layout = enabled
		reset_probe())
	column.add_child(fixture)
	var square := AspectRatioContainer.new()
	square.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(square)
	board = BOARD.instantiate()
	square.add_child(board)
	var chain = ProbeChain.new()
	chain.on_attempt = _on_attempt
	board._chain = chain
	board.chain_started.connect(func(points: Array[Vector2i]):
		counts.chain_started += 1
		_record("chain_started", {"points": _points(points)}))
	board.chain_changed.connect(func(points: Array[Vector2i]): _record("chain_changed", {"points": _points(points)}))
	board.chain_completed.connect(func(points: Array[Vector2i], ingredient: String):
		counts.chain_completed += 1
		_record("chain_completed", {"points": _points(points), "ingredient": ingredient}))
	board.chain_cancelled.connect(func():
		counts.chain_cancelled += 1
		_record("chain_cancelled", {}))
	if not "--no-file" in OS.get_cmdline_user_args():
		var directory := "user://inp_probe"
		DirAccess.make_dir_recursive_absolute(directory)
		_log_path = directory.path_join("probe-%d-%d.jsonl" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
		_log = FileAccess.open(_log_path, FileAccess.WRITE)
		if _log == null:
			push_warning("INP probe could not open its diagnostic log; use console output.")
			_log_path = "Archivo no disponible; revisar consola INP_PROBE."
	_record("environment", {"engine": Engine.get_version_info().string, "os": OS.get_name(), "display_server": DisplayServer.get_name(), "renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "run_seed": 20260921, "board_seed": board.get_board_seed(), "emulate_mouse_from_touch": Input.is_emulating_mouse_from_touch(), "emulate_touch_from_mouse": Input.is_emulating_touch_from_mouse(), "correlation": "temporal heuristic only; not a physical gesture claim", "log_path": _log_path})
	_refresh()

func _exit_tree() -> void:
	Input.set_emulate_mouse_from_touch(_original_emulation)
	if _log != null:
		_log.flush()
		_log.close()

func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var now := Time.get_ticks_usec()
	var kind := event.get_class()
	var position: Vector2 = event.position
	var is_press: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	if is_press:
		# Only pair different event families close in time/position. Never deduplicate.
		var paired := kind != _last_press_type and now - _last_press_usec <= 80000 and position.distance_to(_last_press_position) <= 16.0
		if not paired:
			gesture_probe_seq += 1
		_last_press_usec = now
		_last_press_position = position
		_last_press_type = kind
	counts.raw += 1
	var payload := {"event_type": kind, "position": [position.x, position.y], "device": event.device}
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		payload["pressed"] = event.pressed
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		payload["touch_index"] = event.index
	if event is InputEventMouseButton:
		payload["button_index"] = event.button_index
	if event is InputEventMouseMotion:
		payload["button_mask"] = event.button_mask
	_record("raw_input", payload)

func reset_probe() -> void:
	board._chain.reset()
	board._dragging = false
	board.reset_with_seed(BoardView.DEFAULT_BOARD_SEED)
	if _test_layout:
		var layout := BoardView.PLACEHOLDER_LAYOUT.duplicate()
		for i in range(10):
			layout[i] = "tortilla"
		board._board_state.reset(BoardView.DEFAULT_BOARD_SEED, layout)
		board._ingredients = board._board_state.snapshot()
		board._sync_cells()
	board._refresh_selection()
	for key in counts:
		counts[key] = 0
	_record("reset", {"board_seed": board.get_board_seed(), "layout": "two_tortilla_rows" if _test_layout else "production_default"})
	_refresh()

func _on_attempt(point: Vector2i, ingredient: String, accepted: bool, points: Array[Vector2i]) -> void:
	counts.try_add += 1
	_record("try_add", {"coord": [point.x, point.y], "ingredient": ingredient, "accepted": accepted, "points": _points(points)})

func _points(points: Array[Vector2i]) -> Array:
	var result: Array = []
	for point in points:
		result.append([point.x, point.y])
	return result

func _record(kind: String, payload: Dictionary) -> void:
	var row := payload.duplicate(true)
	row.merge({"kind": kind, "timestamp_usec": Time.get_ticks_usec(), "gesture_probe_seq": gesture_probe_seq, "counts": counts.duplicate()}, true)
	if retain_records:
		records.append(row)
	var line := JSON.stringify(row)
	print("INP_PROBE ", line)
	if _log != null:
		_log.store_line(line)
		if kind in ["chain_completed", "chain_cancelled", "reset", "scenario"] or (kind == "raw_input" and payload.get("pressed", true) == false):
			_log.flush()
	_refresh()

func _refresh() -> void:
	if is_instance_valid(status):
		status.text = "INP-01 diagnóstico · mouse desde touch: %s\nGesto correlacionado %d · inicios %d · try_add %d · finales %d\nCorrelación temporal, no prueba física. %s" % [Input.is_emulating_mouse_from_touch(), gesture_probe_seq, counts.chain_started, counts.try_add, counts.chain_completed, _log_path]
