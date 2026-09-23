extends VBoxContainer

const MAX_MESSAGES := 4

@onready var message_labels: Array[Label] = [%Message0, %Message1, %Message2, %Message3]

var _localization: Dictionary = {}
var _messages: Array[Dictionary] = []


func configure(localization: Dictionary) -> void:
	_localization = localization.duplicate(true)


func present(payload: Dictionary) -> void:
	var key := str(payload.get("text_key", ""))
	if not _localization.has(key):
		return
	var message := {
		"cue_id": str(payload["cue_id"]),
		"text": str(_localization[key]).format(payload.get("values", {})),
	}
	# Keep a short, static history so synchronous created/served/satisfied cues
	# remain readable together. No flashes, motion, overlay or visual timer.
	if not _messages.is_empty() and _messages.back() == message:
		return
	_messages.append(message)
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	for index in range(MAX_MESSAGES):
		message_labels[index].text = _messages[index]["text"] if index < _messages.size() else ""


func get_messages() -> Array[Dictionary]:
	return _messages.duplicate(true)
