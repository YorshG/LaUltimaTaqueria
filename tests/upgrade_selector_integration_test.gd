extends SceneTree

var failures := 0
var Selector = preload("res://scripts/upgrades/upgrade_selector.gd")
var Director = preload("res://scripts/waves/wave_director.gd")
var Registry = preload("res://scripts/content/content_registry.gd")


func _init() -> void:
	var registry_result: Dictionary = Registry.new().load_and_validate()
	_expect(registry_result["ok"], "content must validate before UPG-01 integration tests")
	if not registry_result["ok"]:
		quit(1)
		return

	_test_wave_completed_signal_flow(registry_result["content"])
	await _test_main_wiring()

	if failures == 0:
		print("UPG-01 integration tests passed: WaveDirector signal and Main bridge.")
		quit(0)
	else:
		push_error("UPG-01 integration tests failed: %d" % failures)
		quit(1)


func _test_wave_completed_signal_flow(content: Dictionary) -> void:
	var director: WaveDirector = Director.new()
	var selector: UpgradeSelector = Selector.new()
	_expect(selector.configure(content)["ok"], "selector integration fixture must configure")
	_expect(selector.start_run(314159)["ok"], "selector integration fixture must start")
	director.wave_completed.connect(selector.receive_wave_completed)

	director.wave_completed.emit({"wave_id": "wave_01"})
	_expect(selector.state == Selector.State.OFFER_READY, "wave 1 completion must create first offer")
	var first_offer := selector.get_current_offer()
	_expect(first_offer.size() == Selector.OFFER_SIZE, "wave completion offer must contain three options")
	director.wave_completed.emit({"wave_id": "wave_02"})
	_expect(selector.get_current_offer() == first_offer, "pending offer must reject another completion without replacement")

	var selected_events: Array[Dictionary] = []
	selector.upgrade_selected.connect(func(payload: Dictionary): selected_events.append(payload))
	selector.select_upgrade(str(first_offer[0]["id"]))
	_expect(selector.state == Selector.State.IDLE, "selection must close pending offer")

	for wave_number in range(2, Selector.MAX_SELECTIONS + 1):
		director.wave_completed.emit({"wave_id": "wave_%02d" % wave_number})
		_expect(selector.state == Selector.State.OFFER_READY, "next wave completion must create next offer")
		var offer := selector.get_current_offer()
		_expect(offer.size() == Selector.OFFER_SIZE, "every integrated offer must contain three options")
		selector.select_upgrade(str(offer[0]["id"]))

	_expect(selector.is_selection_complete(), "fifth integrated selection must complete selector")
	_expect(selector.get_selection_count() == Selector.MAX_SELECTIONS, "integrated flow must record five choices")
	_expect(selected_events.size() == Selector.MAX_SELECTIONS, "integrated flow must emit five selections")
	_expect(selected_events[-1]["wave_id"] == "wave_05", "final selection must retain wave association")
	_expect(selected_events[-1]["is_final_selection"], "final integrated selection must be marked final")
	var selected_before_sixth := selector.get_selected_upgrade_ids()
	director.wave_completed.emit({"wave_id": "wave_06"})
	_expect(selector.get_current_offer().is_empty(), "completion after fifth choice must not create sixth offer")
	_expect(selector.get_selected_upgrade_ids() == selected_before_sixth, "sixth completion must not mutate selected state")
	director.free()
	selector.free()


func _test_main_wiring() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var main = packed.instantiate()
	get_root().add_child(main)
	await process_frame

	_expect(main.wave_director.state == Director.State.IDLE, "Main must not auto-start a wave")
	_expect(main.upgrade_selector.state == Selector.State.IDLE, "Main must start selector without creating an offer")
	_expect(main.upgrade_selector.get_selection_count() == 0, "Main must not auto-select an upgrade")
	main.wave_director.wave_completed.emit({"wave_id": "wave_01"})
	_expect(main.upgrade_selector.state == Selector.State.OFFER_READY, "Main bridge must forward wave_completed")
	_expect(main.upgrade_selector.get_current_offer().size() == Selector.OFFER_SIZE, "Main bridge must expose three options")
	_expect(main.wave_director.state == Director.State.IDLE, "upgrade offer must not auto-start another wave")

	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
