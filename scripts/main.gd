extends Control

const Registry = preload("res://scripts/content/content_registry.gd")
const Resolver = preload("res://scripts/recipes/recipe_resolver.gd")
const DEFAULT_RUN_SEED := 20260921

@onready var board_view: BoardView = %BoardView
@onready var lane_field: LaneField = %LaneField
@onready var wave_director: WaveDirector = %WaveDirector
@onready var upgrade_selector: UpgradeSelector = %UpgradeSelector

var recipe_resolver: RecipeResolver


func _ready() -> void:
	var content_result := Registry.new().load_and_validate()
	if not content_result.get("ok", false):
		push_error("LANE-02 temporary wiring could not load validated content")
		return
	recipe_resolver = Resolver.new(content_result["content"])
	var wave_result := wave_director.configure(content_result["content"], lane_field)
	if not wave_result.get("ok", false):
		push_error("WAV-01 temporary wiring could not configure WaveDirector")
		return
	var upgrade_result := upgrade_selector.configure(content_result["content"])
	if not upgrade_result.get("ok", false):
		push_error("UPG-01 temporary wiring could not configure UpgradeSelector")
		return
	var run_result := upgrade_selector.start_run(DEFAULT_RUN_SEED)
	if not run_result.get("ok", false):
		push_error("UPG-01 temporary wiring could not start UpgradeSelector run")
		return
	board_view.chain_completed.connect(_on_chain_completed)
	wave_director.wave_completed.connect(_on_wave_completed)
	print("La Última Taquería — UPG-01 temporary wiring ready.")


# Temporary BoardView -> RecipeResolver -> LaneField bridge.
# A future GameSession implementation can replace this without moving rules into Main.
func _on_chain_completed(points: Array[Vector2i], ingredient_id: String) -> Dictionary:
	if recipe_resolver == null:
		return {"ok": false, "target_found": false}
	var resolution := recipe_resolver.resolve(ingredient_id, points.size())
	if not resolution.get("ok", false):
		return resolution
	return lane_field.resolve_dish(resolution)


# Temporary WaveDirector -> UpgradeSelector bridge.
# A future GameSession implementation can replace this without moving rules into Main.
func _on_wave_completed(payload: Dictionary) -> Dictionary:
	return upgrade_selector.receive_wave_completed(payload)
