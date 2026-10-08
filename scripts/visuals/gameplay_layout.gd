extends Control
## Reusable vertical arrangement. All gameplay children keep their names/APIs.

var _queued := false
var _main: Control
var touch_target_met := false

func _ready() -> void:
	_main = owner as Control
	resized.connect(queue_layout)
	_main.ready.connect(_bind, CONNECT_ONE_SHOT)

func _bind() -> void:
	for child in [get_node("Hud"), get_node("RunStatus"), get_node("FeedbackLayer")]:
		child.minimum_size_changed.connect(queue_layout)
	queue_layout()

func queue_layout() -> void:
	if _queued: return
	_queued = true
	call_deferred("_arrange")

func _arrange() -> void:
	_queued = false
	if _main == null or not _main.is_node_ready() or size.y <= 0: return
	var status := get_node("RunStatus") as Label
	var hud := get_node("Hud") as Control
	var feedback := get_node("FeedbackLayer") as Control
	var lanes := get_node("LaneField") as Control
	var counter := get_node("Counter") as Control
	var board_host := get_node("BoardHost") as Control
	var reserved := float(_main.get_meta("restart_reserved_width", 0.0))
	var header_width := maxf(400, size.x - reserved)
	status.position = Vector2.ZERO
	status.size.x = header_width
	var status_height := status.get_combined_minimum_size().y if status.visible else 0.0
	status.size.y = status_height
	hud.position = Vector2(0, status_height + 4)
	hud.size.x = header_width
	hud.size.y = hud.get_combined_minimum_size().y
	var header_height := maxf(hud.position.y + hud.size.y, float(_main.get_meta("restart_reserved_height", 0.0)))
	feedback.position = Vector2(0, header_height + 8)
	feedback.size.x = size.x
	feedback.size.y = feedback.get_combined_minimum_size().y
	var lane_top := feedback.position.y + feedback.size.y + 8
	var available := size.y - lane_top - 60
	var side := minf(size.x, minf(size.y * 0.56, available - 210))
	# Expanded-font fixtures may require smaller cells; expose the resulting metric.
	side = maxf(320, side)
	var unit := float(_main.get_meta("ui_units_per_point", 3.0))
	touch_target_met = (side - 64) / 5 >= 44 * unit
	board_host.position = Vector2((size.x - side) / 2, size.y - side)
	board_host.size = Vector2.ONE * side
	counter.position = Vector2(0, board_host.position.y - 52)
	counter.size = Vector2(size.x, 44)
	lanes.position = Vector2(0, lane_top)
	lanes.size = Vector2(size.x, maxf(120, counter.position.y - lane_top - 8))
	# ART-01B spatial invariant: HUD -> lanes -> counter -> square board.
