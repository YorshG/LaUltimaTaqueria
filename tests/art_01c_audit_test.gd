extends SceneTree
const Fixture = preload("res://tests/art_01c_fixture.gd")
const LaneVisual = preload("res://scripts/visuals/lane_visual.gd")
const Art = preload("res://scripts/visuals/art_01_style.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for sample in [[27.5, 30.0, "28/30"], [67.625, 70.0, "68/70"], [17.6666666666667, 18.0, "18/18"], [0.49, 30.0, "0/30"], [123456789.375, 987654321.75, "123456789/987654322"]]:
		_expect(LaneVisual.hunger_text(sample[0], sample[1]) == sample[2], "nearest integer display, including stress values")
	_expect(not "provisional" in Art.catalog().labels.lane.to_lower(), "no provisional lane label")
	for height in [1620, 1920, 2400]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1080, height)
		root.add_child(viewport)
		var app = load("res://scenes/App.tscn").instantiate()
		viewport.add_child(app)
		app.get_node("Layout").set_test_metrics(Rect2(0, 177, 1080, height - 279), Transform2D.IDENTITY, 3.0)
		var main = app.get_session()
		var board: BoardView = main.board_view
		for mode in ["regular", "fractional", "crowded"]:
			var snapshot := Fixture.populate(main, mode)
			for frame in range(8): await process_frame
			var before_board := board.get_ingredient_snapshot()
			for coord in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(4, 0)]:
				var cell: Control = board.grid.get_child(coord.y * 5 + coord.x)
				var geometry := cell.get_global_rect()
				_expect(board.begin_chain_at(coord), "select each ingredient")
				_expect(cell.modulate == Color.WHITE and cell.get_node("IngredientVisual").modulate == Color.WHITE, "ingredient and parent retain neutral modulation")
				_expect(cell.get_global_rect() == geometry, "selection never alters hitbox")
				_expect(board.get_node("BoardVisual")._points == [coord], "independent selection outline observes accepted chain")
				board.finish_chain()
			_expect(board.get_ingredient_snapshot() == before_board, "single selections never mutate board")
			board.begin_chain_at(Vector2i.ZERO)
			_expect(not board.extend_chain_to(Vector2i.ONE), "diagonal rejected")
			_expect(board.extend_chain_to(Vector2i(1, 0)) and board.extend_chain_to(Vector2i(2, 0)), "orthogonal chain kept")
			for index in range(3): _expect(board.grid.get_child(index).modulate == Color.WHITE, "whole chain remains untinted")
			var visual = main.lane_field.get_node("LaneVisual")
			var cards: Array = visual.cards()
			_expect(cards.size() == snapshot.size(), "fixture count represented")
			for index in range(cards.size()):
				var card: Dictionary = cards[index]
				var state = card.runner.monster_state
				var record: Dictionary = snapshot.filter(func(row): return row.sequence == state.spawn_sequence)[0]
				_expect(state.hunger_max == {"nibbler": 30, "salsa_tank": 70, "swift_hopper": 18}[state.monster_id], "canonical hunger loaded from monsters.json")
				_expect(state.hunger_remaining == record.remaining and card.runner.motion.progress == record.progress, "fractional fixture frozen exactly")
				var before: float = state.hunger_remaining
				var text: String = visual.hunger_text(before, state.hunger_max)
				var fit: Dictionary = visual.text_fit(text, card.rect.size.x)
				_expect(not '\n' in text and not '.' in text and text.count('/') == 1, "one integer line")
				_expect(fit.width * fit.scale_x <= card.rect.size.x - 4 + 0.01 and fit.font_size >= 24, "real hunger fits with >=8pt height at density 3")
				_expect(fit.scale_x == 1.0, "canonical fixture never compresses glyphs horizontally")
				_expect(state.hunger_remaining == before, "formatting preserves exact model float")
				var long_fit: Dictionary = visual.text_fit(visual.hunger_text(123456789.375, 987654321.75), card.rect.size.x)
				_expect(long_fit.width * long_fit.scale_x <= card.rect.size.x - 4 + 0.01, "long values cannot overflow or wrap")
				for previous in range(index): _expect(not card.rect.intersects(cards[previous].rect), "coincident runners remain distinct")
			var target = main.lane_field.select_nearest_target()
			var shown: int = visual.target_sequence()
			var hunger_before: float = target.monster_state.hunger_remaining
			var served: Dictionary = main.lane_field.resolve_dish({"ok": true, "satisfaction_final": 1.375})
			_expect(served.served.spawn_sequence == shown, "marked target equals effective service")
			_expect(target.monster_state.hunger_remaining == hunger_before - 1.375, "fractional satisfaction stays precise")
			print("ART_01C_FIXTURE_TEST height=%d mode=%s shown=%d served=%d data=%s" % [height, mode, shown, served.served.spawn_sequence, JSON.stringify(snapshot)])
		for node in main.find_children("*", "Label", true, false):
			_expect(not "provisional" in node.text.to_lower() and not "debug" in node.text.to_lower(), "no debugging labels in gameplay")
		viewport.queue_free()
		await process_frame
	print("ART_01C_AUDIT %d checks %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ART_01C_AUDIT: " + message)
