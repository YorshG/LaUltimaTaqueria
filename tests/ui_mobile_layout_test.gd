extends SceneTree
## Spatial assertions recovered from #62, without its VBox casts/child order.
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, height)
		root.add_child(viewport)
		var app = load("res://scenes/App.tscn").instantiate()
		viewport.add_child(app)
		var main = app.get_session()
		main.feedback_audio.playback_enabled = false
		main.process_mode = Node.PROCESS_MODE_DISABLED
		for frame in range(8): await process_frame
		var board: Rect2 = main.board_view.get_global_rect()
		var lanes: Rect2 = main.lane_field.get_global_rect()
		var restart: Rect2 = app.restart_button.get_global_rect()
		var feedback: Rect2 = main.feedback_layer.get_global_rect()
		_expect(lanes.end.y < board.position.y, "clients physically above board")
		_expect(board.get_center().y > height / 2.0, "board center in lower half")
		_expect(board.size.x >= 300 and board.size.y >= 300, "board remains usable size")
		_expect(restart.end.y < lanes.position.y, "restart above gameplay")
		_expect(feedback.end.y < board.position.y, "feedback above board")
		_expect(main.board_view.get_cell_count() == 25, "full 5x5 board")
		viewport.queue_free()
		await process_frame
	print("UI_MOBILE_LAYOUT %d checks %d failures" % [checks, failures])
	quit(0 if checks > 0 and failures == 0 else 1)
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
