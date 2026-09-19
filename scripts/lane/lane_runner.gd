class_name LaneRunner
extends Control

var motion := LaneMotion.new()
var auto_advance := true

@onready var label: Label = %Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_position()


func configure(lane_index: int, speed_relative: float, display_text: String = "M") -> void:
	motion.configure(lane_index, speed_relative)
	if is_node_ready():
		label.text = display_text
		_apply_position()
	else:
		set_meta("pending_label", display_text)


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)


func advance(delta: float) -> float:
	var value := motion.advance(delta)
	_apply_position()
	return value


func effective_speed() -> float:
	return motion.effective_speed()


func set_global_speed_multiplier(value: float) -> void:
	assert(value > 0.0)
	motion.global_speed_multiplier = value


func set_phase_multiplier(value: float) -> void:
	assert(value > 0.0)
	motion.phase_multiplier = value


func _apply_position() -> void:
	if not is_node_ready():
		return
	if has_meta("pending_label"):
		label.text = str(get_meta("pending_label"))
		remove_meta("pending_label")
	var host := get_parent() as Control
	if host == null:
		return
	var travel := maxf(host.size.y - size.y, 0.0)
	position.x = maxf((host.size.x - size.x) * 0.5, 0.0)
	position.y = travel * motion.progress
