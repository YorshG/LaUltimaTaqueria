extends VBoxContainer

@export var reputation_format := "Reputación %s / %s"
@export var defeat_text := "Derrota — reputación agotada"
@export var victory_text := "Victoria"

@onready var reputation_label: Label = %ReputationLabel
@onready var reputation_bar: ProgressBar = %ReputationBar
@onready var outcome_label: Label = %OutcomeLabel


func show_reputation(payload: Dictionary) -> void:
	reputation_label.text = reputation_format % [
		String.num(float(payload["current"])).trim_suffix(".0"),
		String.num(float(payload["maximum"])).trim_suffix(".0"),
	]
	reputation_bar.max_value = float(payload["maximum"])
	reputation_bar.value = float(payload["current"])
	if payload.get("defeated", false):
		show_outcome("defeat")


func show_outcome(outcome: String) -> void:
	outcome_label.text = defeat_text if outcome == "defeat" else victory_text
	outcome_label.show()
