## Test-only decorator. Every attempt delegates to the unchanged ChainPath rule.
extends "res://scripts/board/chain_path.gd"

var on_attempt: Callable

func try_add(point: Vector2i, ingredient: String) -> bool:
	var accepted := super.try_add(point, ingredient)
	if on_attempt.is_valid():
		on_attempt.call(point, ingredient, accepted, points())
	return accepted
