extends SceneTree
const Fixture = preload("res://tests/art_01c_fixture.gd")
## Bounded desktop observation; not an iPhone performance acceptance.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	main.auto_start_run = false
	root.add_child(main)
	Fixture.populate(main, "regular", 7)
	main.process_mode = Node.PROCESS_MODE_INHERIT
	for frame in range(60): await process_frame
	var before := counts()
	var times: Array[float] = []
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var after := counts()
	times.sort()
	intervals.sort()
	var passed := before == after
	print("ART_PERFORMANCE ", JSON.stringify({"desktop_only": true, "fixture": "canonical-seven", "frame_interval_ms_median": intervals[90], "frame_interval_ms_p95": intervals[171], "frame_interval_ms_max": intervals[-1], "warmup_frames": 60, "sample_frames": 180, "runners": 7, "before": before, "after": after, "stable_counts": passed, "process_ms_median": times[90], "process_ms_p95": times[171], "memory_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	main.queue_free()
	await process_frame
	quit(0 if passed else 1)

func counts() -> Array:
	return [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]
