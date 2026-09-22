extends Control

const Registry = preload("res://scripts/content/content_registry.gd")
const Resolver = preload("res://scripts/recipes/recipe_resolver.gd")

@onready var board_view: BoardView = %BoardView
@onready var lane_field: LaneField = %LaneField

var recipe_resolver: RecipeResolver


func _ready() -> void:
	var content_result := Registry.new().load_and_validate()
	if not content_result.get("ok", false):
		push_error("LANE-02 temporary wiring could not load validated content")
		return
	recipe_resolver = Resolver.new(content_result["content"])
	board_view.chain_completed.connect(_on_chain_completed)
	print("La Última Taquería — LANE-02 temporary wiring ready.")


# Temporary BoardView -> RecipeResolver -> LaneField bridge.
# A future WAV-01/GameSession implementation can replace this without moving rules into Main.
func _on_chain_completed(points: Array[Vector2i], ingredient_id: String) -> Dictionary:
	if recipe_resolver == null:
		return {"ok": false, "target_found": false}
	var resolution := recipe_resolver.resolve(ingredient_id, points.size())
	if not resolution.get("ok", false):
		return resolution
	return lane_field.resolve_dish(resolution)
