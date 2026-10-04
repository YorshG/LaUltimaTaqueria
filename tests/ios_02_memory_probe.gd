extends SceneTree
## IOS-02 desktop preflight.
## Replaces the complete App/Main session repeatedly and records structural and memory monitors.
## MEMORY_STATIC is observational only; IOS-02 acceptance still requires physical-device profiling.

const APP := preload("res://scenes/App.tscn")
const AppScript := preload("res://scripts/app.gd")

class ProbeHost extends AppScript:
	func _create_session() -> Node:
		var session := super._create_session()
		for property in session.get_property_list():
			if property["name"] == "auto_start_run":
				session.set("auto_start_run", false)
				break
		return session

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cycles := int(args[0]) if args.size() >= 1 else 1000
	var warmup := int(args[1]) if args.size() >= 2 else 100
	var sample_every := int(args[2]) if args.size() >= 3 else 100
	if cycles <= warmup or warmup < 1 or sample_every < 1:
		push_error("IOS-02 probe requires cycles > warmup >= 1 and sample_every >= 1")
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1080, 1920)
	root.add_child(viewport)

	var app = APP.instantiate()
	app.set_script(ProbeHost)
	viewport.add_child(app)
	await process_frame
	await process_frame

	var env := {
		"godot": Engine.get_version_info().get("string", ""),
		"os": OS.get_name(),
		"display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"cycles": cycles,
		"warmup": warmup,
		"sample_every": sample_every,
	}
	print("IOS02_ENV=" + JSON.stringify(env))

	var baseline: Dictionary = {}
	var last_sample: Dictionary = {}
	for cycle in range(1, cycles + 1):
		var generation_before: int = app.get_generation()
		app.request_restart()
		_expect(app.is_confirmation_pending(), "restart confirmation must open at cycle %d" % cycle)
		app.confirm_restart()
		_expect(app.get_generation() == generation_before + 1, "generation must advance exactly once at cycle %d" % cycle)
		await process_frame

		if cycle == warmup or cycle % sample_every == 0 or cycle == cycles:
			await process_frame
			var sample := _sample(cycle)
			if baseline.is_empty() and cycle >= warmup:
				baseline = sample.duplicate(true)
			if not baseline.is_empty() and cycle > warmup:
				_expect(sample["node_count"] == baseline["node_count"], "node count drift at cycle %d" % cycle)
				_expect(sample["object_count"] == baseline["object_count"], "object count drift at cycle %d" % cycle)
				_expect(sample["resource_count"] == baseline["resource_count"], "resource count drift at cycle %d" % cycle)
				_expect(sample["orphan_count"] == baseline["orphan_count"], "orphan count drift at cycle %d" % cycle)
			if not baseline.is_empty():
				sample["memory_delta_from_warmup"] = sample["memory_static"] - baseline["memory_static"]
			print("IOS02_SAMPLE=" + JSON.stringify(sample))
			last_sample = sample

	app.free()
	await process_frame
	await process_frame

	if baseline.is_empty() or last_sample.is_empty():
		_expect(false, "probe did not collect baseline/final samples")
	else:
		var result := {
			"cycles": cycles,
			"warmup": warmup,
			"baseline": baseline,
			"final": last_sample,
			"memory_delta": last_sample["memory_static"] - baseline["memory_static"],
			"failures": failures,
		}
		print("IOS02_RESULT=" + JSON.stringify(result))

	if failures == 0:
		print("IOS-02 MEMORY PREFLIGHT PASS")
	else:
		push_error("IOS-02 MEMORY PREFLIGHT FAIL: %d structural checks" % failures)
	quit(0 if failures == 0 else 1)


func _sample(cycle: int) -> Dictionary:
	return {
		"cycle": cycle,
		"memory_static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"message_buffer_max": int(Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX)),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"process_sec": Performance.get_monitor(Performance.TIME_PROCESS),
	}


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
