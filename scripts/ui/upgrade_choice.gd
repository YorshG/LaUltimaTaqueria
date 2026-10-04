extends PanelContainer

signal choice_requested(upgrade_id: String)

@onready var title: Label = %ChoiceTitle
@onready var options: VBoxContainer = %Options
var _localization: Dictionary = {}
var _accepting_choice := false


func configure(localization: Dictionary) -> void:
	_localization = localization.duplicate(true)


func present(offer: Array, wave_number: int) -> void:
	_clear_options()
	title.text = "Oleada %d completada\nElige una mejora" % wave_number
	for upgrade in offer:
		var button := Button.new()
		button.text = "%s\n%s" % [_localization[upgrade["display_name_key"]], _localization[upgrade["description_key"]]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 180)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 32)
		button.set_meta("upgrade_id", str(upgrade["id"]))
		button.pressed.connect(_request_choice.bind(str(upgrade["id"])))
		options.add_child(button)
	_accepting_choice = true
	show()


func allow_choice() -> void:
	_accepting_choice = true
	for button in options.get_children():
		button.disabled = false


func dismiss() -> void:
	_accepting_choice = false
	hide()
	# Keep controls until the next offer; a pressed signal may be on the stack.


func _request_choice(upgrade_id: String) -> void:
	if not visible or not _accepting_choice or not can_process():
		return
	_accepting_choice = false
	for button in options.get_children():
		button.disabled = true
	choice_requested.emit(upgrade_id)


func _clear_options() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
