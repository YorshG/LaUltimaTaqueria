extends SceneTree
const APP = preload("res://scenes/App.tscn")
const Safe = preload("res://scripts/visuals/safe_area_layout.gd")
const Registry = preload("res://scripts/content/content_registry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func settle() -> void:
	for frame in range(8): await process_frame

func _run() -> void:
	for height in [1620, 1920, 2400]:
		for scaled in [false, true]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1080, height)
			root.add_child(viewport)
			var app = APP.instantiate()
			viewport.add_child(app)
			var main = app.get_session()
			main.feedback_audio.playback_enabled = false
			main.wave_director.set_process(false)
			var layout = app.get_node("Layout")
			var safe := Rect2(12, 177, 1050, height - 279)
			var transform := Transform2D(0.0, Vector2.ONE * (2.0 / 3.0 if scaled else 1.0), 0.0, Vector2(37, 59))
			layout.set_test_metrics(transform * safe, transform, 2.0 if scaled else 3.0)
			await settle()
			_expect(layout.effective_safe_rect.is_equal_approx(safe), "screen pixels converted to local canvas")
			_expect(is_equal_approx(layout.units_per_point, 3), "physical points include display density and canvas scaling")
			_check_regions(app, safe, height)
			var board: BoardView = main.board_view
			board.reset_with_seed(20260920)
			var visual = main.lane_field.get_node("LaneVisual")
			for child in main.lane_field._runners.duplicate(): child.free()
			for index in range(9):
				var runner = main.lane_field.spawn_runner(index / 3, 55, "M", ["nibbler", "salsa_tank", "swift_hopper"][index % 3], 70)
				runner.auto_advance = false
				runner.motion.progress = 0.40 + 0.005 * index
				runner.monster_state.apply_satisfaction(index * 1.5)
			await settle()
			var cards: Array = visual.cards()
			_expect(cards.size() == 9, "all clustered clients represented")
			for i in range(cards.size()):
				var card: Dictionary = cards[i]
				var host: Control = main.lane_field.get_lane_host(card.runner.monster_state.lane)
				var area: Rect2 = visual.get_global_transform().affine_inverse() * host.get_global_rect()
				_expect(area.encloses(card.rect), "card with hunger stays in its lane")
				for j in range(i): _expect(not card.rect.intersects(cards[j].rect), "clustered cards never overlap")
				var old_y: float = card.rect.position.y
				card.runner.motion.progress += 0.1
				_expect(visual.cards()[i].rect.position.y > old_y, "each card follows real logical progress")
			var shown: int = visual.target_sequence()
			var served: Dictionary = main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 1.5})
			_expect(served.served.spawn_sequence == shown, "marked target receives actual dish")
			# Real viewport dispatch proves safe-area translation keeps touch wiring.
			var started: Array = []
			board.chain_started.connect(func(points): started.append(points.duplicate()))
			for index in range(25):
				var touch := InputEventScreenTouch.new()
				touch.position = board.grid.get_child(index).get_global_rect().get_center()
				touch.pressed = true
				viewport.push_input(touch, true)
				_expect(not started.is_empty() and started.back() == [Vector2i(index % 5, index / 5)], "translated touch reaches exact cell")
				touch.pressed = false
				viewport.push_input(touch, true)
			board.begin_chain_at(Vector2i.ZERO)
			_expect(not board.extend_chain_to(Vector2i.ONE), "diagonal still rejected")
			board.extend_chain_to(Vector2i(1, 0))
			_expect(board.get_node("BoardVisual")._points == [Vector2i.ZERO, Vector2i(1, 0)], "orthogonal chain observable")
			_click(viewport, app.restart_button)
			await settle()
			_expect(app.is_confirmation_pending(), "restart confirmation opens")
			_expect(safe.encloses(app.confirmation.get_node("Center/Panel").get_global_rect()), "entire restart panel safe")
			for button in [app.confirm_button, app.cancel_button]:
				_expect(safe.encloses(button.get_global_rect()) and button.size.y / layout.units_per_point >= 44, "modal touch control safe and >=44pt")
			_click(viewport, app.cancel_button)
			_expect(not app.is_confirmation_pending(), "modal cancel receives viewport input")
			var content: Dictionary = Registry.new().load_and_validate()["content"]
			main.upgrade_choice.present(content.upgrades.slice(0, 3), 1)
			await settle()
			for button in main.upgrade_choice.options.get_children():
				_expect(safe.encloses(button.get_global_rect()) and button.size.y / layout.units_per_point >= 44, "upgrade option safe and >=44pt")
			main.upgrade_choice.dismiss()
			app.request_restart()
			app.confirm_restart()
			app.get_session().feedback_audio.playback_enabled = false
			app.get_session().wave_director.set_process(false)
			await settle()
			_check_regions(app, safe, height)
			# Resize with different top/bottom exclusions; no restart/reload needed.
			viewport.size.y = 2400 if height == 1620 else 1620
			safe = Rect2(0, 96, 1080, viewport.size.y - 176)
			layout.set_test_metrics(transform * safe, transform, 2.0 if scaled else 3.0)
			await settle()
			_check_regions(app, safe, viewport.size.y)
			app.get_session().run_ended.emit({"outcome": "defeat"})
			await settle()
			_expect(app.restart_button.text == "Nueva partida", "terminal button uses existing lifecycle")
			_check_regions(app, safe, viewport.size.y)
			viewport.queue_free()
			await process_frame
	var bounds := Rect2(0, 0, 1080, 1920)
	_expect(Safe.project_safe_rect(Rect2(9999, 9999, 2, 2), Transform2D.IDENTITY, bounds) == bounds, "invalid/off-window safe area falls back to viewport")
	print("ART_01B_LAYOUT %d checks %d failures" % [checks, failures])
	quit(0 if checks > 0 and failures == 0 else 1)

func _check_regions(app, safe: Rect2, height: int) -> void:
	var main = app.get_session()
	var board: Rect2 = main.board_view.get_global_rect()
	var hud: Rect2 = main.hud.get_global_rect()
	var lanes: Rect2 = main.lane_field.get_global_rect()
	var counter: Rect2 = main.get_node("Margin/Content/Counter").get_global_rect()
	var restart: Rect2 = app.restart_button.get_global_rect()
	for rect in [board, hud, lanes, counter, restart, main.feedback_layer.get_global_rect()]:
		_expect(safe.grow(0.01).encloses(rect), "all gameplay regions within effective safe area")
	_expect(hud.end.y < lanes.position.y and lanes.end.y < counter.position.y and counter.end.y < board.position.y, "HUD -> lanes -> counter -> board, actual spatial order")
	_expect(not hud.intersects(restart) and restart.end.y < lanes.position.y, "restart separated from HUD and gestures")
	_expect(main.board_view.get_cell_count() == 25, "exact 5x5 grid retained")
	var unit: float = app.get_node("Layout").units_per_point
	for cell in main.board_view.grid.get_children():
		_expect(absf(cell.size.x - cell.size.y) <= 1, "square cells")
		_expect(minf(cell.size.x, cell.size.y) / unit >= 44, "each cell >=44 physical points")
	_expect(restart.size.y / unit >= 44, "restart >=44 physical points")
	print("ART_01B_SAFE height=%d source=synthetic safe=%s hud=%s lanes=%s counter=%s board=%s cell_pt=%s restart_pt=%s" % [height, safe, hud, lanes, counter, board, main.board_view.grid.get_child(0).size / unit, restart.size / unit])

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ART_01B_LAYOUT: " + message)

func _click(viewport: SubViewport, control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		viewport.push_input(event, true)
