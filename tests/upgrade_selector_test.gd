extends SceneTree

var failures := 0
var Selector = preload("res://scripts/upgrades/upgrade_selector.gd")
var Registry = preload("res://scripts/content/content_registry.gd")
var content: Dictionary
var catalog_ids: Array[String] = []
var allocated_selectors: Array[UpgradeSelector] = []


func _init() -> void:
	var registry_result: Dictionary = Registry.new().load_and_validate()
	_expect(registry_result["ok"], "content must validate before UPG-01 tests")
	if not registry_result["ok"]:
		quit(1)
		return
	content = registry_result["content"]
	for upgrade in content["upgrades"]:
		catalog_ids.append(str(upgrade["id"]))
	catalog_ids.sort()

	_test_configuration_and_explicit_errors()
	_test_offer_shape_determinism_and_copies()
	_test_selection_validation_and_non_repetition()
	_test_conflicts()
	_test_strong_defense()
	_test_synergies_and_rarity_are_metadata()
	_test_insufficient_pool()
	_test_complete_runs_across_seeds()
	for selector in allocated_selectors:
		selector.free()

	if failures == 0:
		print("UPG-01 tests passed: deterministic offers, exclusions and five selections.")
		quit(0)
	else:
		push_error("UPG-01 tests failed: %d" % failures)
		quit(1)


func _test_configuration_and_explicit_errors() -> void:
	var selector := _new_selector()
	_expect_error(selector.start_run(10), Selector.NOT_CONFIGURED, "start without configure")
	_expect_error(
		selector.receive_wave_completed({"wave_id": "wave_01"}),
		Selector.NOT_CONFIGURED,
		"wave completion without configure"
	)
	_expect_error(selector.select_upgrade("taco_power_1"), Selector.NOT_CONFIGURED, "select without configure")
	_expect_error(selector.configure({}), Selector.INVALID_CONTENT, "configure without upgrades")
	_expect(selector.configure(content)["ok"], "validated content must configure")
	_expect(selector.get_state_name() == "IDLE", "configured selector must be idle")
	_expect_error(
		selector.receive_wave_completed({"wave_id": "wave_01"}),
		Selector.RUN_NOT_STARTED,
		"wave completion before run"
	)
	_expect_error(selector.select_upgrade("taco_power_1"), Selector.RUN_NOT_STARTED, "select before run")
	_expect(selector.start_run(10)["ok"], "explicit seed must start run")
	_expect_error(selector.configure(content), Selector.RUN_ALREADY_STARTED, "configure during run")
	_expect_error(
		selector.receive_wave_completed({}),
		Selector.INVALID_WAVE_COMPLETION,
		"wave payload without id"
	)


func _test_offer_shape_determinism_and_copies() -> void:
	var source_snapshot: Dictionary = content.duplicate(true)
	var first := _new_started_selector(7123)
	var second := _new_started_selector(7123)
	var first_offer_result: Dictionary = first.receive_wave_completed({"wave_id": "wave_01"})
	var second_offer_result: Dictionary = second.receive_wave_completed({"wave_id": "wave_01"})
	_expect(first_offer_result["ok"] and second_offer_result["ok"], "same-seed first offers must succeed")
	var first_ids := _offer_ids(first.get_current_offer())
	var second_ids := _offer_ids(second.get_current_offer())
	_expect(first_ids == second_ids, "same seed and history must produce the same ordered offer")
	_expect(first_ids.size() == Selector.OFFER_SIZE, "offer must contain exactly three options")
	_expect(_unique_count(first_ids) == Selector.OFFER_SIZE, "offer ids must be unique")
	for upgrade_id in first_ids:
		_expect(upgrade_id in catalog_ids, "offer must only contain catalog upgrades: %s" % upgrade_id)

	var first_choice: String = first_ids[0]
	first.select_upgrade(first_choice)
	second.select_upgrade(first_choice)
	first.receive_wave_completed({"wave_id": "wave_02"})
	second.receive_wave_completed({"wave_id": "wave_02"})
	_expect(
		_offer_ids(first.get_current_offer()) == _offer_ids(second.get_current_offer()),
		"same seed and selected history must keep later offers deterministic"
	)

	var changed_seed := _new_started_selector(99173)
	changed_seed.receive_wave_completed({"wave_id": "wave_01"})
	_expect(
		_offer_ids(changed_seed.get_current_offer()) != first_ids,
		"a fixed different seed must be able to produce a different offer"
	)

	var exposed_offer := first_offer_result["offer"] as Array
	exposed_offer[0]["effect"]["value"] = -999.0
	exposed_offer[0]["tags"].append("mutated")
	var fresh_offer := first.get_selected_upgrades()
	_expect(not fresh_offer.is_empty(), "selected upgrade must be stored")
	if not fresh_offer.is_empty():
		_expect(float(fresh_offer[0]["effect"]["value"]) > 0.0, "returned offer must not mutate selected state")
		_expect("mutated" not in fresh_offer[0]["tags"], "returned tags must be copied deeply")
	_expect(content == source_snapshot, "selector must not mutate source content")


func _test_selection_validation_and_non_repetition() -> void:
	var selector := _new_started_selector(44)
	_expect_error(selector.select_upgrade("taco_power_1"), Selector.NO_ACTIVE_OFFER, "select without offer")
	_expect(selector.receive_wave_completed({"wave_id": "wave_01"})["ok"], "first completion must create offer")
	var offer := selector.get_current_offer()
	_expect(selector.state == Selector.State.OFFER_READY, "created offer must enter OFFER_READY")
	_expect_error(
		selector.receive_wave_completed({"wave_id": "wave_02"}),
		Selector.OFFER_ALREADY_PENDING,
		"second completion while offer pending"
	)
	var before_invalid := selector.get_selection_count()
	_expect_error(selector.select_upgrade("not_in_offer"), Selector.UPGRADE_NOT_IN_OFFER, "id outside offer")
	_expect(selector.get_selection_count() == before_invalid, "invalid selection must not mutate count")
	_expect(_offer_ids(selector.get_current_offer()) == _offer_ids(offer), "invalid selection must preserve offer")

	var selected_id: String = str(offer[0]["id"])
	var selected_result: Dictionary = selector.select_upgrade(selected_id)
	_expect(selected_result["ok"], "offered upgrade must be selectable")
	_expect(selector.state == Selector.State.IDLE, "non-final selection must return to IDLE")
	_expect(selector.get_selection_count() == 1, "valid selection must increment count once")
	selected_result["selection"]["effect"]["value"] = -999.0
	_expect(
		float(selector.get_selected_upgrades()[0]["effect"]["value"]) > 0.0,
		"returned selection payload must not mutate stored upgrade"
	)
	_expect_error(selector.select_upgrade(selected_id), Selector.NO_ACTIVE_OFFER, "select consumed offer twice")
	_expect_error(
		selector.receive_wave_completed({"wave_id": "wave_01"}),
		Selector.DUPLICATE_WAVE_COMPLETION,
		"duplicate consumed wave completion"
	)
	selector.receive_wave_completed({"wave_id": "wave_02"})
	_expect(selected_id not in _offer_ids(selector.get_current_offer()), "selected upgrade must never reappear")


func _test_conflicts() -> void:
	_assert_conflict_exclusion("taco_power_1", "taco_power_2")
	_assert_conflict_exclusion("taco_power_2", "taco_power_1")
	_assert_conflict_exclusion("slow_salsa", "slow_salsa_plus")
	_assert_conflict_exclusion("slow_salsa_plus", "slow_salsa")


func _test_strong_defense() -> void:
	var strong_ids := ["safety_shield", "patient_service", "second_chance"]
	for chosen_id in strong_ids:
		var selector: UpgradeSelector = _selector_with_target_offer(chosen_id)
		_expect(selector != null, "must find deterministic offer containing %s" % chosen_id)
		if selector == null:
			continue
		_expect(selector.select_upgrade(chosen_id)["ok"], "%s must be selectable" % chosen_id)
		var eligible: Array[String] = selector.get_eligible_upgrade_ids()
		for other_id in strong_ids:
			if other_id != chosen_id:
				_expect(other_id not in eligible, "%s must exclude strong defense %s" % [chosen_id, other_id])


func _test_synergies_and_rarity_are_metadata() -> void:
	var selector: UpgradeSelector = _selector_with_target_offer("taco_power_1")
	_expect(selector != null, "must find offer for synergy metadata test")
	if selector != null:
		selector.select_upgrade("taco_power_1")
		var eligible: Array[String] = selector.get_eligible_upgrade_ids()
		for synergy_id in ["chain4_boost", "extra_bite", "warm_welcome"]:
			_expect(synergy_id in eligible, "synergy must not exclude %s" % synergy_id)

	var changed_synergies := content.duplicate(true)
	for upgrade in changed_synergies["upgrades"]:
		upgrade["synergies"] = []
	var synergy_base := _new_started_selector(31415)
	var synergy_changed := _new_selector()
	_expect(synergy_changed.configure(changed_synergies)["ok"], "metadata-only synergy fixture must configure")
	synergy_changed.start_run(31415)
	synergy_base.receive_wave_completed({"wave_id": "wave_01"})
	synergy_changed.receive_wave_completed({"wave_id": "wave_01"})
	_expect(
		_offer_ids(synergy_base.get_current_offer()) == _offer_ids(synergy_changed.get_current_offer()),
		"synergy metadata must not force options or alter deterministic selection"
	)

	var changed_rarities := content.duplicate(true)
	for upgrade in changed_rarities["upgrades"]:
		upgrade["rarity"] = "epic" if upgrade["rarity"] == "common" else "common"
	var base := _new_started_selector(5522)
	var changed := _new_selector()
	_expect(changed.configure(changed_rarities)["ok"], "metadata-only rarity fixture must configure")
	changed.start_run(5522)
	base.receive_wave_completed({"wave_id": "wave_01"})
	changed.receive_wave_completed({"wave_id": "wave_01"})
	_expect(
		_offer_ids(base.get_current_offer()) == _offer_ids(changed.get_current_offer()),
		"rarity metadata must not change deterministic selection"
	)
	_expect(selector.get_eligible_upgrade_ids().size() > 0, "metadata test must preserve eligible pool")


func _test_insufficient_pool() -> void:
	var selector := _new_selector()
	var too_small := {"upgrades": [content["upgrades"][0], content["upgrades"][1]]}
	_expect(selector.configure(too_small)["ok"], "small catalog can configure before offer validation")
	selector.start_run(1)
	var result: Dictionary = selector.receive_wave_completed({"wave_id": "wave_01"})
	_expect_error(result, Selector.INSUFFICIENT_ELIGIBLE_UPGRADES, "pool smaller than three")
	_expect(selector.state == Selector.State.IDLE, "insufficient pool must not create partial offer")
	_expect(selector.get_current_offer().is_empty(), "insufficient pool must expose no options")


func _test_complete_runs_across_seeds() -> void:
	for seed in [0, 1, 7, 99, 20260921]:
		var selector: UpgradeSelector = _new_started_selector(seed)
		var emitted: Array[Dictionary] = []
		selector.upgrade_selected.connect(func(payload: Dictionary): emitted.append(payload))
		var selected_ids: Array[String] = []
		for wave_number in range(1, Selector.MAX_SELECTIONS + 1):
			var wave_id := "wave_%02d" % wave_number
			var offer_result: Dictionary = selector.receive_wave_completed({"wave_id": wave_id})
			_expect(offer_result["ok"], "seed %s wave %s must create an offer" % [seed, wave_number])
			if not offer_result["ok"]:
				break
			var offer := selector.get_current_offer()
			var offer_ids := _offer_ids(offer)
			_expect(offer_ids.size() == Selector.OFFER_SIZE, "every run offer must contain three options")
			_expect(_unique_count(offer_ids) == Selector.OFFER_SIZE, "every run offer must have unique ids")
			for prior_id in selected_ids:
				_expect(prior_id not in offer_ids, "selected upgrade must stay excluded across run")
			var choice: String = offer_ids[0]
			selected_ids.append(choice)
			var selection_result: Dictionary = selector.select_upgrade(choice)
			_expect(selection_result["ok"], "first offered option must be selectable")

		_expect(selector.get_selection_count() == Selector.MAX_SELECTIONS, "run must complete five selections")
		_expect(selector.is_selection_complete(), "fifth selection must mark cycle complete")
		_expect(_unique_count(selected_ids) == Selector.MAX_SELECTIONS, "five selected ids must be distinct")
		_expect(_count_strong_defenses(selector.get_selected_upgrades()) <= 1, "run must select at most one strong defense")
		_expect(emitted.size() == Selector.MAX_SELECTIONS, "run must emit exactly five selections")
		for index in range(emitted.size()):
			_expect(int(emitted[index]["selection_number"]) == index + 1, "selection number must be 1..5")
			_expect(
				bool(emitted[index]["is_final_selection"]) == (index == Selector.MAX_SELECTIONS - 1),
				"only fifth selection must be final"
			)
		_expect(selector.get_active_effects().size() == Selector.MAX_SELECTIONS, "all selected effects must remain accessible")
		_expect_error(
			selector.receive_wave_completed({"wave_id": "wave_06"}),
			Selector.SELECTION_CYCLE_COMPLETE,
			"sixth offer after complete run"
		)
		_expect(selector.get_current_offer().is_empty(), "complete run must not expose a sixth offer")


func _assert_conflict_exclusion(chosen_id: String, excluded_id: String) -> void:
	var selector: UpgradeSelector = _selector_with_target_offer(chosen_id)
	_expect(selector != null, "must find deterministic offer containing %s" % chosen_id)
	if selector == null:
		return
	_expect(selector.select_upgrade(chosen_id)["ok"], "%s must be selectable" % chosen_id)
	_expect(excluded_id not in selector.get_eligible_upgrade_ids(), "%s must exclude %s" % [chosen_id, excluded_id])
	selector.receive_wave_completed({"wave_id": "wave_02"})
	_expect(excluded_id not in _offer_ids(selector.get_current_offer()), "%s must stay out of later offer" % excluded_id)


func _selector_with_target_offer(target_id: String) -> UpgradeSelector:
	for seed in range(256):
		var selector := _new_started_selector(seed)
		var result: Dictionary = selector.receive_wave_completed({"wave_id": "wave_01"})
		if result["ok"] and target_id in _offer_ids(selector.get_current_offer()):
			return selector
	return null


func _new_started_selector(seed: int) -> UpgradeSelector:
	var selector := _new_selector()
	_expect(selector.configure(content)["ok"], "test selector must configure")
	_expect(selector.start_run(seed)["ok"], "test selector must start with explicit seed")
	return selector


func _new_selector() -> UpgradeSelector:
	var selector: UpgradeSelector = Selector.new()
	allocated_selectors.append(selector)
	return selector


func _offer_ids(offer: Array) -> Array[String]:
	var result: Array[String] = []
	for upgrade in offer:
		result.append(str(upgrade["id"]))
	return result


func _unique_count(ids: Array[String]) -> int:
	var unique: Dictionary = {}
	for upgrade_id in ids:
		unique[upgrade_id] = true
	return unique.size()


func _count_strong_defenses(upgrades: Array[Dictionary]) -> int:
	var count := 0
	for upgrade in upgrades:
		if "strong_defense" in upgrade.get("tags", []):
			count += 1
	return count


func _expect_error(result: Dictionary, error_code: String, label: String) -> void:
	_expect(not result.get("ok", true), "%s must fail" % label)
	_expect(result.get("error") == error_code, "%s must return %s: %s" % [label, error_code, result])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
