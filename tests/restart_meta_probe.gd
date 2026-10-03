extends SceneTree
## Refuses the real project/user directory; invoked only by the isolated driver.
const APP := preload("res://scenes/App.tscn")
const Save := preload("res://scripts/save/save_service.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].begins_with("rst_01_isolated_") or args[1] not in ["locate", "run"]:
		push_error("RST metadata probe requires its isolated driver")
		quit(1)
		return
	var directory := ProjectSettings.globalize_path("user://").trim_suffix("/").simplify_path()
	if not FileAccess.file_exists("res://.rst-01-isolated") or directory.get_file() != args[0] or ProjectSettings.get_setting("application/config/custom_user_dir_name", "") != args[0] or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("RST metadata probe refuses non-isolated project/user directory")
		quit(1)
		return
	print("RST_META_DIR=" + directory)
	if args[1] == "locate":
		quit(0)
		return
	if FileAccess.get_file_as_string("user://.rst-01-userdata") != args[0]:
		push_error("RST metadata probe requires its marked disposable user directory")
		quit(1)
		return
	var service := Save.new()
	service.set_record(987)
	service.set_coins(654)
	service.set_preference("audio", false)
	if service.save() != OK:
		quit(1)
		return
	var before := FileAccess.get_file_as_bytes(Save.DEFAULT_SAVE_PATH)
	var app = APP.instantiate()
	root.add_child(app)
	for cycle in range(20):
		app.request_restart()
		app.cancel_restart()
		app.request_restart()
		app.confirm_restart()
		app.get_session().reputation.apply_damage(1000.0)
		app.request_restart()
	app.free()
	var reader := Save.new()
	var ok := reader.load_save() == OK and reader.get_record() == 987 and reader.get_coins() == 654 and reader.get_preferences() == {"audio": false} and FileAccess.get_file_as_bytes(Save.DEFAULT_SAVE_PATH) == before
	if ok:
		print("RST metadata PASS: default user:// sentinel unchanged across 40 restarts and 20 cancels.")
	else:
		push_error("RST metadata FAIL: isolated default sentinel changed")
	quit(0 if ok else 1)
