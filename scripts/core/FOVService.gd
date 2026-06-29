class_name FOVService
extends RefCounted

## Minimal grid-based field-of-view helper.
## This stays deliberately small:
## - no lighting
## - no per-frame updates
## - no AI dependency
## - no combat dependency


func compute_fov(origin: Vector2i, radius: int, map_data) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	if map_data == null or radius < 0:
		return visible

	var size: Vector2i = map_data.get_size()
	var max_dist_sq: int = radius * radius
	for y in range(size.y):
		for x in range(size.x):
			var cell: Vector2i = Vector2i(x, y)
			var dx: int = cell.x - origin.x
			var dy: int = cell.y - origin.y
			if dx * dx + dy * dy > max_dist_sq:
				continue
			if has_line_of_sight(origin, cell, map_data):
				visible.append(cell)
	return visible


func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, map_data) -> bool:
	if map_data == null:
		return false
	if not map_data.is_in_bounds(from_cell) or not map_data.is_in_bounds(to_cell):
		return false
	if from_cell == to_cell:
		return true

	for cell in _bresenham_line(from_cell, to_cell):
		if cell == from_cell or cell == to_cell:
			continue
		if map_data.blocks_vision(cell):
			return false
	return true


func _bresenham_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y

	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy

	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

	return points
