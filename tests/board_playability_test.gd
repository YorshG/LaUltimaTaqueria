extends SceneTree

const BOARD_SIZE := 25

var failures := 0
var BoardStateModel = preload("res://scripts/board/board_state.gd")

var playable_layout := [
	"tortilla", "tortilla", "tortilla", "meat", "veggie",
	"meat", "veggie", "meat", "veggie", "tortilla",
	"veggie", "meat", "veggie", "tortilla", "meat",
	"tortilla", "veggie", "tortilla", "meat", "veggie",
	"meat", "tortilla", "meat", "veggie", "tortilla",
]
var dead_layout := [
	"tortilla", "meat", "veggie", "tortilla", "meat",
	"meat", "veggie", "tortilla", "meat", "veggie",
	"veggie", "tortilla", "meat", "veggie", "tortilla",
	"tortilla", "meat", "veggie", "tortilla", "meat",
	"meat", "veggie", "tortilla", "meat", "veggie",
]


func _init() -> void:
	_test_playable_board_is_unchanged()
	_test_dead_board_recovery()
	_test_recovery_is_deterministic()
	_test_distinct_known_seeds()
	_test_playability_after_refill()

	if failures == 0:
		print("BRD-04 tests passed: detection, recovery, multiset, determinism, refill integration.")
		quit(0)
	else:
		push_error("BRD-04 tests failed: %d" % failures)
		quit(1)


func _test_playable_board_is_unchanged() -> void:
	var board = BoardStateModel.new()
	var recovered: bool = board.reset(17, playable_layout)
	_expect(board.has_valid_chain(), "known playable board must expose a valid chain")
	_expect(not recovered, "known playable board must not be reorganized")
	_expect(board.snapshot() == playable_layout, "playable board layout must remain unchanged")


func _test_dead_board_recovery() -> void:
	var board = BoardStateModel.new()
	var before := _sorted_copy(dead_layout)
	var recovered: bool = board.reset(73, dead_layout)
	var after: Array[String] = board.snapshot()

	_expect(recovered, "known dead board must be detected and recovered")
	_expect(board.has_valid_chain(), "recovered board must contain a valid chain")
	_expect(not board.is_dead_board(), "recovered board must no longer be dead")
	_expect(after.size() == BOARD_SIZE, "recovery must preserve exactly 25 cells")
	_expect(not board.has_empty_cells(), "recovery must leave no empty cells")
	_expect(_contains_only_valid_ingredients(after), "recovery must leave only valid ingredients")
	_expect(_sorted_copy(after) == before, "recovery must preserve the ingredient multiset")


func _test_recovery_is_deterministic() -> void:
	var first = BoardStateModel.new()
	var second = BoardStateModel.new()
	first.reset(12345, dead_layout)
	second.reset(12345, dead_layout)
	_expect(first.snapshot() == second.snapshot(), "same seed and dead layout must recover identically")


func _test_distinct_known_seeds() -> void:
	var first = BoardStateModel.new()
	var second = BoardStateModel.new()
	first.reset(101, dead_layout)
	second.reset(202, dead_layout)
	_expect(first.snapshot() != second.snapshot(), "known distinct seeds must produce distinct recovered boards")


func _test_playability_after_refill() -> void:
	var board = BoardStateModel.new()
	board.reset(0, playable_layout)
	var chain: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var recovered: bool = board.resolve_chain(chain)

	_expect(recovered, "known refill must trigger automatic dead-board recovery")
	_expect(board.snapshot().size() == BOARD_SIZE, "refill integration must preserve exactly 25 cells")
	_expect(not board.has_empty_cells(), "refill integration must leave no empty cells")
	_expect(board.has_valid_chain(), "refill integration must return a playable board")


func _contains_only_valid_ingredients(layout: Array[String]) -> bool:
	for ingredient in layout:
		if ingredient not in BoardStateModel.INGREDIENT_IDS:
			return false
	return true


func _sorted_copy(layout: Array) -> Array:
	var result := layout.duplicate()
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
