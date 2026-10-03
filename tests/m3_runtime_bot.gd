## Optional engine-driven smoke. Arguments: time_scale [restart] [capture].
## Chooses legal 3-cell chains through BoardView; never advances WaveDirector directly.
extends SceneTree

var app
var main
var failures := 0
var waves: Array[String] = []
var choices: Array[String] = []
var boss_count := 0
var clock_sec := 0.0
var next_dish := 0.0
var actions := 0
var restart_stages: Array[String] = []
var reset_done: Array[String] = []
var render_capture := false
var has_app := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Engine.time_scale = float(args[0]) if not args.is_empty() else 20.0
	if "restart" in args:
		restart_stages.assign(["wave", "upgrade", "boss"])
	render_capture = "capture" in args and DisplayServer.get_name() != "headless"
	app = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	get_root().add_child(app)
	has_app = app.has_method("get_session")
	if not restart_stages.is_empty() and not has_app:
		_expect(false, "restart smoke requires RST-01 App composition")
		app.free()
		quit(1)
		return
	_bind_session()
	await process_frame
	if render_capture:
		await _capture("start")
	while clock_sec < 600.0:
		await process_frame
		var delta := get_root().get_process_delta_time()
		clock_sec += delta
		var snapshot: Dictionary = main.get_run_snapshot()
		var phase := str(snapshot.phase)
		if phase in restart_stages and phase not in reset_done:
			if phase == "wave" and main.wave_director.get_spawned_count() == 0:
				continue
			var old = main
			var generation: int = app.get_generation()
			var board: Array = main.board_view.get_ingredient_snapshot()
			var offer: Array = main.upgrade_selector.get_current_offer()
			var logical: float = snapshot.logical_elapsed_sec
			app.request_restart()
			_expect(app.is_confirmation_pending(), "active %s requires confirmation" % phase)
			if phase == "upgrade":
				var selected_count: int = main.upgrade_selector.get_selection_count()
				main.upgrade_choice.options.get_child(0).pressed.emit()
				_expect(main.upgrade_selector.get_selection_count() == selected_count, "stale UI callback cannot select during restart modal")
			if render_capture:
				await _capture("restart_" + phase)
			await process_frame
			await process_frame
			_expect(main.get_run_snapshot().logical_elapsed_sec == logical, "modal stops logical time in " + phase)
			app.cancel_restart()
			_expect(main == old and app.get_generation() == generation, "cancel preserves session " + phase)
			_expect(main.board_view.get_ingredient_snapshot() == board, "cancel preserves board " + phase)
			_expect(main.upgrade_selector.get_current_offer() == offer, "cancel preserves offer " + phase)
			if phase == "upgrade":
				_expect(not main.upgrade_choice.options.get_child(0).disabled, "cancel preserves usable upgrade options")
			app.request_restart()
			app.confirm_restart()
			_expect(not is_instance_valid(old), "old session freed synchronously in " + phase)
			_expect(app.get_generation() == generation + 1, "one replacement in " + phase)
			_bind_session()
			_expect(main.wave_director.current_wave_id == "wave_01", "restart goes to wave1 " + phase)
			_expect(main.upgrade_selector.get_selection_count() == 0, "restart has no upgrades " + phase)
			_expect(not main.boss_has_started, "restart has no boss " + phase)
			reset_done.append(phase)
			print("BOT restart verified: ", phase)
			continue
		if snapshot.terminal:
			_expect(snapshot.outcome == "victory", "bot reaches real victory")
			_expect(waves == ["wave_01", "wave_02", "wave_03", "wave_04", "wave_05"], "five ordered wave completions")
			_expect(choices.size() == 5, "five choices")
			_expect(boss_count == 1, "one boss")
			var strong := 0
			for upgrade in main.upgrade_selector.get_selected_upgrades():
				if "strong_defense" in upgrade.tags:
					strong += 1
			_expect(strong <= 1, "at most one strong defense")
			if render_capture:
				await _capture("victory")
			print("BOT RESULT ", JSON.stringify({"snapshot": snapshot, "waves": waves, "choices": choices, "bosses": boss_count, "board_actions": actions, "time_scale": Engine.time_scale, "restart_stages": reset_done}))
			if has_app:
				var old = main
				app.request_restart()
				_expect(not is_instance_valid(old), "terminal restart direct")
				_expect(app.get_session().wave_director.current_wave_id == "wave_01", "victory restart starts wave1")
			app.free()
			await process_frame
			print("M3 RUNTIME BOT PASS" if failures == 0 else "M3 RUNTIME BOT FAIL")
			quit(0 if failures == 0 else 1)
			return
		if phase == "upgrade":
			_expect(main.upgrade_choice.visible, "upgrade UI visible")
			_expect(main.upgrade_choice.options.get_child_count() == 3, "three visible choices")
			if render_capture and choices.is_empty():
				await _capture("upgrade")
			main.upgrade_choice.options.get_child(0).pressed.emit()
		elif phase in ["wave", "boss"] and clock_sec >= next_dish:
			if main.lane_field.select_nearest_target() != null:
				var chain := _find_chain(main.board_view.get_ingredient_snapshot())
				_expect(chain.size() >= 3, "board has a valid chain")
				if chain.size() >= 3:
					main.board_view.begin_chain_at(chain[0])
					for i in range(1, chain.size()):
						main.board_view.extend_chain_to(chain[i])
					main.board_view.finish_chain()
					actions += 1
				next_dish = clock_sec + 0.5
	_expect(false, "runtime timeout")
	app.free()
	quit(1)

func _bind_session() -> void:
	main = app.get_session() if has_app else app
	waves.clear()
	choices.clear()
	boss_count = 0
	main.wave_director.wave_completed.connect(func(p: Dictionary):
		waves.append(p.wave_id)
		print("BOT wave completed: ", p.wave_id, " elapsed=", p.wave_elapsed_sec))
	main.upgrade_selector.upgrade_selected.connect(func(p: Dictionary): choices.append(p.upgrade_id))
	main.boss_started.connect(func(_p: Dictionary): boss_count += 1)

func _find_chain(board: Array) -> Array[Vector2i]:
	for i in range(board.size()):
		var path: Array[Vector2i] = [Vector2i(i % 5, i / 5)]
		var result := _walk(board, path)
		if result.size() >= 3:
			return result
	return []

func _walk(board: Array, path: Array[Vector2i]) -> Array[Vector2i]:
	if path.size() >= 3:
		return path
	var p: Vector2i = path[-1]
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var q: Vector2i = p + direction
		if q.x < 0 or q.x >= 5 or q.y < 0 or q.y >= 5 or q in path:
			continue
		if board[q.y * 5 + q.x] != board[p.y * 5 + p.x]:
			continue
		var next := path.duplicate()
		next.append(q)
		var result := _walk(board, next)
		if result.size() >= 3:
			return result
	return []

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var output_dir := OS.get_environment("TMPDIR")
	if output_dir.is_empty():
		output_dir = "/tmp"
	var path := output_dir.path_join("m3-" + label + ".png")
	_expect(get_root().get_texture().get_image().save_png(path) == OK, "save rendered screenshot")
	print("BOT screenshot: ", path)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
