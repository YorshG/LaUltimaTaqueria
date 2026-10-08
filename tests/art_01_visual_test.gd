extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, height)
		root.add_child(viewport)
		var main = MAIN.instantiate()
		main.auto_start_run = false
		viewport.add_child(main)
		await process_frame
		await process_frame
		var board: BoardView = main.board_view
		var field: LaneField = main.lane_field
		var visual = field.get_node("LaneVisual")
		_expect(board.get_cell_count() == 25 and board.get_column_count() == 5, "exact 5x5")
		_expect(main.hud.get_node("CoinsPending").text == "Monedas —", "pending coins, no invented value")
		_expect(main.hud.reputation_label.text == "Reputación 100 / 100", "reputation remains factual")
		_expect(visual.target_sequence() == -1 and not main.boss_has_started, "no fabricated target/boss")
		for cell in board.grid.get_children():
			var icon := cell.get_node("IngredientVisual") as Control
			_expect(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "icon never captures touch")
			_expect(icon.get_global_rect().is_equal_approx(cell.get_global_rect()), "icon tracks cell geometry")
			_expect(cell.get_meta("ingredient_id") in ["tortilla", "meat", "veggie"], "three ingredients only")
		_expect(board.get_node("BoardVisual").mouse_filter == Control.MOUSE_FILTER_IGNORE, "chain overlay ignores input")
		_expect(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "lane overlay ignores input")
		board.begin_chain_at(Vector2i.ZERO)
		_expect(not board.extend_chain_to(Vector2i(1, 1)), "diagonal remains rejected")
		board.extend_chain_to(Vector2i(1, 0))
		board.extend_chain_to(Vector2i(2, 0))
		_expect(board.get_node("BoardVisual")._points == [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "draw only accepted orthogonal path")
		board.finish_chain()
		_expect(board.get_node("BoardVisual")._points.is_empty(), "clear visual chain after refill")
		var left := field.spawn_runner(0, 55, "N", "nibbler", 30)
		var center := field.spawn_runner(1, 30, "S", "salsa_tank", 70)
		var right := field.spawn_runner(2, 90, "H", "swift_hopper", 18)
		for runner in [left, center, right]:
			runner.auto_advance = false
			runner.motion.progress = 0.4
		_expect(visual.target_sequence() == center.monster_state.spawn_sequence, "actual center tie priority")
		right.motion.progress = 0.7
		_expect(visual.target_sequence() == right.monster_state.spawn_sequence, "actual nearest priority")
		var track := Rect2(0, 0, 300, 360)
		_expect(visual.proxy_center(right, track).y > visual.proxy_center(center, track).y, "visual distance follows logical advance across roles")
		var shown: int = visual.target_sequence()
		var served := field.resolve_dish({"ok": true, "satisfaction_final": 30.0})
		_expect(served.served.spawn_sequence == shown, "shown target equals actual served target")
		_expect(visual.target_sequence() == center.monster_state.spawn_sequence, "retired runner no longer marked")
		center.motion.progress = 1.0
		_expect(visual.target_sequence() == left.monster_state.spawn_sequence, "breached runner excluded")
		left.monster_state.active = false
		_expect(visual.target_sequence() == -1, "no stale preview")
		var rect: Rect2 = board.get_global_rect()
		_expect(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(rect), "board inside viewport")
		# Synthetic masks are observations, not actual iOS safe-area coordinates.
		var safe := Rect2(0, 177, 1080, height - 177 - 102)
		print("ART_LAYOUT height=%d board=%s cell=%s synthetic_safe_board=%s hud=%s" % [height, rect, board.grid.get_child(0).size, safe.encloses(rect), safe.encloses(main.hud.get_global_rect())])
		viewport.queue_free()
		await process_frame
	print("ART_VISUAL %d checks %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ART_VISUAL: " + message)
