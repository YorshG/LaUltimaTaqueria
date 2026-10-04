extends Control
## Owns one complete run. Gameplay remains inside Main; metadata lives elsewhere.

signal session_replaced(generation: int)

const MAIN_SCENE := preload("res://scenes/Main.tscn")

@onready var session_host: Control = %SessionHost
@onready var restart_button: Button = %RestartButton
@onready var confirmation: Control = %RestartConfirmation
@onready var confirm_button: Button = %ConfirmRestart
@onready var cancel_button: Button = %CancelRestart

var _session: Node
var _generation := 0
var _terminal := false
var _confirmation_pending := false
var _replacing := false
var _suspended_nodes: Array[Dictionary] = []


func _ready() -> void:
	restart_button.pressed.connect(request_restart)
	confirm_button.pressed.connect(confirm_restart)
	cancel_button.pressed.connect(cancel_restart)
	_replace_session()


func get_session() -> Node:
	return _session


func get_generation() -> int:
	return _generation


func is_confirmation_pending() -> bool:
	return _confirmation_pending


func is_terminal() -> bool:
	return _terminal


func request_restart() -> void:
	if _replacing or _confirmation_pending or not is_instance_valid(_session):
		return
	if _terminal:
		_replace_session()
		return
	_confirmation_pending = true
	_suspend_subtree(_session)
	confirmation.show()
	cancel_button.grab_focus()


func cancel_restart() -> void:
	if _replacing or not _confirmation_pending:
		return
	_confirmation_pending = false
	confirmation.hide()
	for saved in _suspended_nodes:
		var node: Node = saved["node"]
		if is_instance_valid(node):
			node.process_mode = saved["process_mode"]
			if saved.has("stream_paused"):
				node.set("stream_paused", saved["stream_paused"])
	_suspended_nodes.clear()
	restart_button.grab_focus()


func confirm_restart() -> void:
	if _replacing or not _confirmation_pending:
		return
	_replace_session()


func _suspend_subtree(node: Node) -> void:
	var saved := {"node": node, "process_mode": node.process_mode}
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		saved["stream_paused"] = node.get("stream_paused")
		node.set("stream_paused", true)
	_suspended_nodes.append(saved)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_suspend_subtree(child)


# This factory is a construction seam, not a second owner of run state.
func _create_session() -> Node:
	return MAIN_SCENE.instantiate()


func _replace_session() -> void:
	if _replacing:
		return
	_replacing = true
	var next := _create_session()
	_confirmation_pending = false
	confirmation.hide()
	_suspended_nodes.clear()
	if is_instance_valid(_session):
		_session.process_mode = Node.PROCESS_MODE_DISABLED
		session_host.remove_child(_session)
		# The old Main may still be emitting a terminal signal on this stack.
		# Retire ownership now; Godot destroys the detached subtree at frame end.
		_session.queue_free()
	_session = next
	_generation += 1
	_terminal = false
	restart_button.text = "Reiniciar"
	# Connect before add_child: ready may start the production run synchronously.
	_session.run_ended.connect(_on_terminal.bind(_generation))
	_session.boss_encounter_completed.connect(_on_terminal.bind(_generation))
	session_host.add_child(_session)
	session_replaced.emit(_generation)
	_replacing = false


func _on_terminal(_payload: Dictionary, generation: int) -> void:
	if generation != _generation:
		return
	_terminal = true
	restart_button.text = "Nueva partida"
