class_name GridMapData
extends RefCounted

var width: int = 0
var height: int = 0
var blocked_cells: Dictionary = {}
var opaque_cells: Dictionary = {}


func setup(new_width: int, new_height: int) -> void:
	width = new_width
	height = new_height
	blocked_cells.clear()
	opaque_cells.clear()


func get_size() -> Vector2i:
	return Vector2i(width, height)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not blocked_cells.has(cell)


func blocks_vision(cell: Vector2i) -> bool:
	return not is_in_bounds(cell) or opaque_cells.has(cell)


func add_blocked(cell: Vector2i, opaque: bool = true) -> void:
	if not is_in_bounds(cell):
		return
	blocked_cells[cell] = true
	if opaque:
		opaque_cells[cell] = true


func add_opaque(cell: Vector2i) -> void:
	if is_in_bounds(cell):
		opaque_cells[cell] = true
