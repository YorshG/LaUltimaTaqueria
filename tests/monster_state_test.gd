extends SceneTree

var failures := 0
var State = preload("res://scripts/lane/monster_state.gd")


func _init() -> void:
	_test_initial_and_partial_satisfaction()
	_test_exact_satisfaction_and_single_transition()
	_test_oversatisfaction_clamps_without_spillover()
	_test_invalid_satisfaction_is_rejected()

	if failures == 0:
		print("MonsterState tests passed: hunger, validation, clamping, single transition.")
		quit(0)
	else:
		push_error("MonsterState tests failed: %d" % failures)
		quit(1)


func _test_initial_and_partial_satisfaction() -> void:
	var state = State.new("nibbler", 1, 30.0, 7)
	_expect(state.monster_id == "nibbler", "monster id must be retained")
	_expect(state.lane == 1, "lane must be retained")
	_expect(state.spawn_sequence == 7, "spawn sequence must be retained")
	_expect(is_equal_approx(state.hunger_max, 30.0), "hunger max must initialize from content")
	_expect(is_equal_approx(state.hunger_remaining, 30.0), "remaining hunger must start full")
	_expect(state.active and not state.satisfied, "new monster must be active and unsatisfied")

	var result: Dictionary = state.apply_satisfaction(12.0)
	_expect(result["ok"], "positive partial satisfaction must be accepted")
	_expect(is_equal_approx(result["satisfaction_applied"], 12.0), "partial amount must be applied")
	_expect(is_equal_approx(state.hunger_remaining, 18.0), "partial satisfaction must reduce hunger")
	_expect(not result["transitioned_to_satisfied"], "partial satisfaction must not transition")
	_expect(state.active, "partially satisfied monster must remain active")
	_expect(not state.satisfied, "partially satisfied monster must remain unsatisfied")


func _test_exact_satisfaction_and_single_transition() -> void:
	var state = State.new("nibbler", 0, 30.0, 1)
	var first: Dictionary = state.apply_satisfaction(30.0)
	_expect(first["ok"], "exact satisfaction must be accepted")
	_expect(first["transitioned_to_satisfied"], "exact satisfaction must transition")
	_expect(state.satisfied, "exact satisfaction must mark state satisfied")
	_expect(not state.active, "exact satisfaction must retire state immediately")
	_expect(is_zero_approx(state.hunger_remaining), "exact satisfaction must leave zero hunger")
	_expect(not state.is_targetable(0.5), "satisfied monster must be excluded from targeting")

	var second: Dictionary = state.apply_satisfaction(1.0)
	_expect(not second["ok"], "second application to satisfied monster must be rejected")
	_expect(not second["transitioned_to_satisfied"], "second application must not transition again")
	_expect(is_zero_approx(second["satisfaction_applied"]), "second application must be a no-op")
	_expect(is_zero_approx(state.hunger_remaining), "second application must not change hunger")
	_expect(state.satisfied and not state.active, "second application must preserve retired satisfied state")


func _test_oversatisfaction_clamps_without_spillover() -> void:
	var state = State.new("swift_hopper", 2, 18.0, 2)
	var result: Dictionary = state.apply_satisfaction(100.0)
	_expect(result["ok"], "oversatisfaction must be accepted")
	_expect(is_equal_approx(result["satisfaction_applied"], 18.0), "only remaining hunger may be applied")
	_expect(is_zero_approx(state.hunger_remaining), "oversatisfaction must clamp at zero")
	_expect(state.hunger_remaining >= 0.0, "hunger must never become negative")
	_expect(result["transitioned_to_satisfied"], "oversatisfaction must transition once")
	_expect(state.satisfied, "oversatisfaction must mark state satisfied")
	_expect(not state.active, "oversatisfaction must retire state immediately")


func _test_invalid_satisfaction_is_rejected() -> void:
	for invalid_amount in [0.0, -1.0, NAN, INF, -INF]:
		var state = State.new("nibbler", 1, 30.0, 3)
		var result: Dictionary = state.apply_satisfaction(invalid_amount)
		_expect(not result["ok"], "invalid satisfaction must be rejected: %s" % invalid_amount)
		_expect(result["error"] == State.INVALID_SATISFACTION, "invalid amount must use explicit error")
		_expect(is_equal_approx(state.hunger_remaining, 30.0), "invalid amount must not change hunger")
		_expect(not state.satisfied, "invalid amount must not satisfy monster")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
