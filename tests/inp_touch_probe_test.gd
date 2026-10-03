extends SceneTree
const PROBE = preload("res://tests/INPTouchProbe.tscn")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var initial := Input.is_emulating_mouse_from_touch()
	for kind in ["touch", "mouse", "forced_pair"]:
		var plain := await _gesture(kind, false)
		var instrumented := await _gesture(kind, true)
		_expect(plain == instrumented, "decorator preserves all game results: " + kind)
	await _matrix()
	_expect(Input.is_emulating_mouse_from_touch() == initial, "leaving probe restores emulation")
	print("INP_PROBE_TEST %d checks %d failures; synthetic evidence only" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _matrix() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	root.add_child(viewport)
	var probe = PROBE.instantiate()
	viewport.add_child(probe)
	probe._test_layout = true
	await process_frame
	await process_frame
	for cells in [[0], [0,1,2,3], [0,1,2,3,4], [0,5,6,1,2]]:
		probe.reset_probe()
		var first: Vector2 = probe.board.grid.get_child(cells[0]).get_global_rect().get_center()
		_press(viewport, first, true, true)
		for i in range(1,cells.size()):
			_drag(viewport, probe.board.grid.get_child(cells[i]).get_global_rect().get_center(), true)
		_press(viewport, probe.board.grid.get_child(cells[-1]).get_global_rect().get_center(), true, false)
		_expect(probe.counts.chain_started == 1, "matrix single start")
		_expect(probe.counts.chain_completed == (1 if cells.size() >= 3 else 0), "matrix valid lengths and tap")
		_expect(probe.counts.try_add == cells.size(), "matrix exact attempt count")
	var rect: Rect2 = probe.board.get_global_rect()
	for key in probe.counts: probe.counts[key] = 10000
	probe._refresh()
	await process_frame
	await process_frame
	_expect(probe.board.get_global_rect() == rect, "large counters do not move the board")
	var seq: int = probe.gesture_probe_seq
	var raw := InputEventScreenTouch.new(); raw.pressed = true; raw.position = Vector2(10,10)
	probe._input(raw)
	var mouse := InputEventMouseButton.new(); mouse.pressed = true; mouse.position = Vector2(100,100)
	probe._input(mouse)
	_expect(probe.gesture_probe_seq == seq + 2, "distant presses cannot share heuristic sequence")
	var toggle: CheckButton = probe.get_child(0).get_child(2)
	toggle.button_pressed = true
	_expect(not Input.is_emulating_mouse_from_touch(), "scenario B toggle disables runtime emulation")
	toggle.button_pressed = false
	_expect(Input.is_emulating_mouse_from_touch() == probe._original_emulation, "scenario A restores original setting")
	viewport.free()
	await process_frame

func _gesture(kind: String, decorated: bool) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	root.add_child(viewport)
	var probe = PROBE.instantiate()
	probe.retain_records = true
	viewport.add_child(probe)
	if not decorated:
		probe.board._chain = ChainPath.new()
	await process_frame
	await process_frame
	var centers: Array[Vector2] = []
	for i in range(3):
		centers.append(probe.board.grid.get_child(i).get_global_rect().get_center())
	var touch := kind != "mouse"
	var mouse := kind != "touch"
	if touch: _press(viewport, centers[0], true, true)
	if mouse: _press(viewport, centers[0], false, true)
	for i in range(1, 3):
		if touch: _drag(viewport, centers[i], true)
		if mouse: _drag(viewport, centers[i], false)
	if touch: _press(viewport, centers[2], true, false)
	if mouse: _press(viewport, centers[2], false, false)
	var expected := 2 if kind == "forced_pair" else 1
	_expect(probe.counts.chain_started == expected, "observes chain starts " + kind)
	_expect(probe.counts.chain_completed == 1, "observes one valid completion " + kind)
	_expect(probe.counts.raw == (8 if kind == "forced_pair" else 4), "records every raw event " + kind)
	_expect(probe.gesture_probe_seq == 1, "correlates this synthetic burst " + kind)
	if decorated:
		_expect(probe.counts.try_add == (6 if kind == "forced_pair" else 3), "counts actual attempts, including rejected duplicate points")
		var attempts := 0
		for row in probe.records:
			if row.kind == "try_add":
				attempts += 1
				_expect(row.has("ingredient") and row.has("accepted") and row.has("points") and row.has("timestamp_usec"), "attempt schema complete")
		_expect(attempts == probe.counts.try_add, "attempt records match counter")
	var result := {"board": probe.board.get_ingredient_snapshot(), "chain_started": probe.counts.chain_started, "chain_completed": probe.counts.chain_completed, "chain_cancelled": probe.counts.chain_cancelled}
	# Exercise experimental B without touching ProjectSettings or normal runtime.
	Input.set_emulate_mouse_from_touch(false)
	viewport.free()
	await process_frame
	return result

func _press(viewport: SubViewport, point: Vector2, touch: bool, pressed: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.global_position = point
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)

func _drag(viewport: SubViewport, point: Vector2, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.global_position = point
	event.position = point
	viewport.push_input(event, true)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
