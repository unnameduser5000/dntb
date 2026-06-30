class_name VisibilityService
extends RefCounted

const FOVServiceScript := preload("res://scripts/core/FOVService.gd")

var _fov_service := FOVServiceScript.new()


func compute_visible_cells(map_data, origin: Vector2i, radius: int) -> Array[Vector2i]:
	if map_data == null:
		return []
	return _fov_service.compute_fov(origin, radius, map_data)


func reveal_all(map_data) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	if map_data == null:
		return visible
	for cell in map_data.get_all_cells():
		visible.append(cell)
	return visible
