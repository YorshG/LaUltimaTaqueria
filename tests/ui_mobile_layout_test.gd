extends SceneTree

const APP := preload("res://scenes/App.tscn")

var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in [Vector2i(1080, 1620), Vector2i(1080, 1920), Vector2i(1080, 2400)]:
		await _exercise(viewport_size)

	if failures == 0:
		print("UI-MOBILE-01 PASS: %d checks; lanes above board, compact top restart and adaptive mobile layout." % checks)
	else:
		push_error("UI-MOBILE-01 FAIL: %d/%d checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


func _exercise(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	root.add_child(viewport)

	var app = APP.instantiate()
	viewport.add_child(app)
	await process_frame
	await process_frame

	var layout := app.get_node("Layout") as VBoxContainer
	var top_bar := app.get_node("Layout/TopBar") as MarginContainer
	var restart := app.get_node("%RestartButton") as Button
	var session_host := app.get_node("%SessionHost") as Control
	var main = app.get_session()
	main.auto_start_run = false

	var content := main.get_node("Margin/Content") as VBoxContainer
	var lanes := main.get_node("%LaneField") as Control
	var board_host := main.get_node("Margin/Content/BoardHost") as Control
	var board := main.get_node("%BoardView") as Control
	var feedback := main.get_node("%FeedbackLayer") as Control

	var child_names: Array[String] = []
	for child in content.get_children():
		child_names.append(child.name)

	_expect(layout.get_child(0) == top_bar, "top bar precedes session at %s" % viewport_size)
	_expect(layout.get_child(1) == session_host, "session follows top bar at %s" % viewport_size)
	_expect(restart.custom_minimum_size.y <= 64.0, "restart action stays compact at %s" % viewport_size)
	_expect(child_names.find("LaneField") < child_names.find("BoardHost"), "lane content precedes board in VBox at %s" % viewport_size)
	_expect(child_names.find("FeedbackLayer") < child_names.find("BoardHost"), "feedback remains above board at %s" % viewport_size)
	_expect(lanes.get_global_rect().get_center().y < board_host.get_global_rect().get_center().y, "clients render above board at %s" % viewport_size)
	_expect(board.get_global_rect().get_center().y > viewport_size.y * 0.50, "board lives in lower half at %s" % viewport_size)
	_expect(board.get_global_rect().size.x >= 300.0 and board.get_global_rect().size.y >= 300.0, "board remains playable size at %s" % viewport_size)
	_expect(restart.get_global_rect().get_center().y < lanes.get_global_rect().get_center().y, "restart action stays above gameplay at %s" % viewport_size)
	_expect(feedback.get_global_rect().get_center().y < board.get_global_rect().get_center().y, "feedback does not push below board at %s" % viewport_size)

	viewport.queue_free()
	await process_frame


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
