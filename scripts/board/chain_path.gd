class_name ChainPath
extends RefCounted

var _points: Array[Vector2i] = []
var _ingredient_id := ""


func reset() -> void:
	_points.clear()
	_ingredient_id = ""


func try_add(point: Vector2i, ingredient_id: String) -> bool:
	if ingredient_id.is_empty():
		return false

	if _points.is_empty():
		_points.append(point)
		_ingredient_id = ingredient_id
		return true

	if ingredient_id != _ingredient_id:
		return false

	if point in _points:
		return false

	var last := _points[-1]
	var manhattan := abs(point.x - last.x) + abs(point.y - last.y)
	if manhattan != 1:
		return false

	_points.append(point)
	return true


func is_valid(min_length: int = 3) -> bool:
	return _points.size() >= min_length


func points() -> Array[Vector2i]:
	return _points.duplicate()


func ingredient_id() -> String:
	return _ingredient_id


func size() -> int:
	return _points.size()
