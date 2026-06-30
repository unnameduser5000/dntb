class_name PatternStampService
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")

const INTERACTION_SYMBOLS := {
	"T": "tavern",
	"C": "challenge_entrance",
	"U": "ruin",
	"$": "chest",
	"E": "easter_egg",
	"H": "shrine",
}

const CARDINAL_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func parse_pattern(pattern_def: Dictionary) -> Dictionary:
	var lines_raw: Array = pattern_def.get("ascii", [])
	var lines: Array[String] = []
	for line in lines_raw:
		lines.append(String(line))
	if lines.is_empty():
		return {"ok": false, "reason": "empty_pattern"}

	var width: int = lines[0].length()
	for line in lines:
		if line.length() != width:
			return {"ok": false, "reason": "inconsistent_width"}

	var interaction_markers: Array[Vector2i] = []
	var entrance_markers: Array[Vector2i] = []
	for y in range(lines.size()):
		var row: String = lines[y]
		for x in range(width):
			var symbol := row.substr(x, 1)
			if INTERACTION_SYMBOLS.has(symbol):
				interaction_markers.append(Vector2i(x, y))
			elif symbol == "d":
				entrance_markers.append(Vector2i(x, y))

	return {
		"ok": true,
		"width": width,
		"height": lines.size(),
		"lines": lines,
		"interaction_markers": interaction_markers,
		"entrance_markers": entrance_markers,
	}


func transform_pattern(pattern_def: Dictionary, rotation: int = 0, mirrored: bool = false) -> Dictionary:
	var parsed := parse_pattern(pattern_def)
	if not bool(parsed.get("ok", false)):
		return parsed

	var grid: Array = []
	for line in parsed.get("lines", []):
		var row: Array[String] = []
		var source: String = String(line)
		for index in range(source.length()):
			row.append(source.substr(index, 1))
		grid.append(row)

	if mirrored:
		grid = _mirror_horizontal(grid)

	var normalized_rotation: int = int(posmod(rotation, 360))
	for _step in range(int(normalized_rotation / 90)):
		grid = _rotate_90(grid)

	var lines: Array[String] = []
	var interaction_markers: Array[Vector2i] = []
	var entrance_markers: Array[Vector2i] = []
	for y in range(grid.size()):
		var chars: PackedStringArray = []
		var row_chars: Array = grid[y]
		for x in range(row_chars.size()):
			var symbol := String(row_chars[x])
			chars.append(symbol)
			if INTERACTION_SYMBOLS.has(symbol):
				interaction_markers.append(Vector2i(x, y))
			elif symbol == "d":
				entrance_markers.append(Vector2i(x, y))
		lines.append("".join(chars))

	return {
		"ok": true,
		"width": lines[0].length() if not lines.is_empty() else 0,
		"height": lines.size(),
		"lines": lines,
		"interaction_markers": interaction_markers,
		"entrance_markers": entrance_markers,
		"rotation": normalized_rotation,
		"mirrored": mirrored,
	}


func can_stamp(map_data, pattern_def: Dictionary, origin: Vector2i, rotation: int = 0, mirrored: bool = false) -> Dictionary:
	if map_data == null:
		return _failed_check(pattern_def, origin, rotation, mirrored, "missing_map")

	var transformed := transform_pattern(pattern_def, rotation, mirrored)
	if not bool(transformed.get("ok", false)):
		return _failed_check(pattern_def, origin, rotation, mirrored, String(transformed.get("reason", "invalid_pattern")))

	var width: int = int(transformed.get("width", 0))
	var height: int = int(transformed.get("height", 0))
	if width <= 0 or height <= 0:
		return _failed_check(pattern_def, origin, rotation, mirrored, "empty_pattern")

	var occupied_cells: Array[Vector2i] = []
	for y in range(height):
		var row: String = String(transformed["lines"][y])
		for x in range(width):
			var symbol := row.substr(x, 1)
			if symbol == ".":
				continue
			var cell := origin + Vector2i(x, y)
			if not map_data.is_in_bounds(cell):
				return _failed_check(pattern_def, origin, rotation, mirrored, "out_of_bounds")
			if cell == map_data.player_spawn:
				return _failed_check(pattern_def, origin, rotation, mirrored, "overlaps_spawn")
			var map_cell = map_data.get_cell(cell)
			if map_cell == null:
				return _failed_check(pattern_def, origin, rotation, mirrored, "missing_target_cell")
			if _has_existing_structure(map_cell):
				return _failed_check(pattern_def, origin, rotation, mirrored, "overlaps_existing_structure")
			if _has_existing_poi(map_cell):
				return _failed_check(pattern_def, origin, rotation, mirrored, "overlaps_existing_poi")
			if _is_forbidden_terrain(int(map_cell.terrain_type), pattern_def):
				return _failed_check(pattern_def, origin, rotation, mirrored, "forbidden_terrain")
			occupied_cells.append(cell)

	var interaction_cell: Vector2i = _first_world_marker(origin, Array(transformed.get("interaction_markers", [])))
	var entrance_cells: Array[Vector2i] = _world_cells(origin, Array(transformed.get("entrance_markers", [])))
	var validation := validate_accessibility(map_data, pattern_def, occupied_cells, interaction_cell, entrance_cells)
	if not bool(validation.get("ok", false)):
		return _failed_check(pattern_def, origin, rotation, mirrored, String(validation.get("reason", "validation_failed")))

	return {
		"success": true,
		"pattern_id": String(pattern_def.get("id", "")),
		"origin": origin,
		"rotation": int(transformed.get("rotation", rotation)),
		"mirrored": bool(transformed.get("mirrored", mirrored)),
		"interaction_cell": interaction_cell,
		"entrance_cells": entrance_cells,
		"occupied_cells": occupied_cells,
		"transformed": transformed,
		"validation": validation,
		"reason": "",
	}


func apply_stamp(map_data, pattern_def: Dictionary, origin: Vector2i, rotation: int = 0, mirrored: bool = false) -> Dictionary:
	var check := can_stamp(map_data, pattern_def, origin, rotation, mirrored)
	if not bool(check.get("success", false)):
		return check

	var transformed: Dictionary = check.get("transformed", {})
	var occupied_cells: Array[Vector2i] = Array(check.get("occupied_cells", []))
	var previous_cells: Dictionary = {}
	for cell in occupied_cells:
		var existing = map_data.get_cell(cell)
		previous_cells[cell] = existing.duplicate_cell() if existing != null and existing.has_method("duplicate_cell") else null
	var blocked_added: int = 0
	var walkable_added: int = 0
	var poi_type: String = String(pattern_def.get("poi_type", ""))
	var pattern_id: String = String(pattern_def.get("id", ""))
	var building_tag: String = "building:%s" % pattern_id
	var structure_tag: String = "structure:%s" % poi_type
	var stamp_tag: String = "stamp:%s" % pattern_id

	for y in range(int(transformed.get("height", 0))):
		var row: String = String(transformed["lines"][y])
		for x in range(int(transformed.get("width", 0))):
			var symbol := row.substr(x, 1)
			if symbol == ".":
				continue
			var cell := origin + Vector2i(x, y)
			var map_cell = map_data.get_or_create_cell(cell)
			if map_cell == null:
				continue

			match symbol:
				"p":
					map_data.set_terrain(cell, MapCellScript.TerrainType.PLAIN)
					map_cell.display_symbol_override = "p"
					_append_tag(map_cell, "building_open_ground")
					walkable_added += 1
				"_":
					map_data.set_terrain(cell, MapCellScript.TerrainType.PLAIN)
					map_cell.display_symbol_override = "_"
					_append_tag(map_cell, "building_floor")
					walkable_added += 1
				"d":
					map_data.set_terrain(cell, MapCellScript.TerrainType.PLAIN)
					map_cell.display_symbol_override = "d"
					_append_tag(map_cell, "entrance")
					_append_tag(map_cell, "building_door")
					walkable_added += 1
				"#":
					map_data.set_terrain(cell, MapCellScript.TerrainType.STRUCTURE_WALL)
					map_cell.display_symbol_override = "#"
					blocked_added += 1
				"t":
					map_data.set_terrain(cell, MapCellScript.TerrainType.TREE)
					map_cell.display_symbol_override = "t"
					blocked_added += 1
				"r":
					map_data.set_terrain(cell, MapCellScript.TerrainType.ROCK)
					map_cell.display_symbol_override = "r"
					blocked_added += 1
				"s":
					map_data.set_terrain(cell, MapCellScript.TerrainType.STATUE)
					map_cell.display_symbol_override = "s"
					blocked_added += 1
				"~":
					map_data.set_terrain(cell, MapCellScript.TerrainType.WATER)
					map_cell.display_symbol_override = "~"
				"=":
					map_data.set_terrain(cell, MapCellScript.TerrainType.BRIDGE)
					map_cell.display_symbol_override = "="
					walkable_added += 1
				"T", "C", "U", "$", "E", "H":
					map_data.set_terrain(cell, MapCellScript.TerrainType.PLAIN)
					map_cell.display_symbol_override = symbol
					_append_tag(map_cell, "interactable")
					walkable_added += 1
				_:
					pass

			_append_tag(map_cell, building_tag)
			_append_tag(map_cell, structure_tag)
			_append_tag(map_cell, stamp_tag)
			_append_tag(map_cell, "poi:%s" % poi_type)
			if symbol in INTERACTION_SYMBOLS:
				_append_tag(map_cell, "interactable")

	var result := {
		"success": true,
		"reason": "",
		"pattern_id": pattern_id,
		"origin": origin,
		"rotation": int(check.get("rotation", 0)),
		"mirrored": bool(check.get("mirrored", false)),
		"interaction_cell": Vector2i(check.get("interaction_cell", Vector2i(-1, -1))),
		"entrance_cells": Array(check.get("entrance_cells", [])),
		"occupied_cells": occupied_cells,
		"blocked_cells_added": blocked_added,
		"walkable_cells_added": walkable_added,
		"poi_type": poi_type,
		"validation": check.get("validation", {}),
		"previous_cells": previous_cells,
	}
	return result


func validate_accessibility(map_data, pattern_def: Dictionary, occupied_cells: Array[Vector2i], interaction_cell: Vector2i, entrance_cells: Array[Vector2i]) -> Dictionary:
	var poi_type: String = String(pattern_def.get("poi_type", ""))
	var walkable_count: int = 0
	for cell in occupied_cells:
		var map_cell = map_data.get_cell(cell)
		if map_cell != null and bool(map_cell.walkable):
			walkable_count += 1
	if walkable_count <= 0:
		return {"ok": false, "reason": "no_walkable_cells"}

	match poi_type:
		"tavern":
			var anchor := interaction_cell if interaction_cell != Vector2i(-1, -1) else _first_or_invalid(entrance_cells)
			if _count_walkable_area(map_data, occupied_cells, anchor, 1) < 6:
				return {"ok": false, "reason": "tavern_clearance_too_tight"}
		"challenge_entrance":
			if entrance_cells.is_empty():
				return {"ok": false, "reason": "challenge_missing_entrance"}
			var entrance := Vector2i(entrance_cells[0])
			if _count_walkable_area(map_data, occupied_cells, entrance, 2) < 12:
				return {"ok": false, "reason": "not_enough_front_clearance"}
			if _count_cardinal_walkable(map_data, occupied_cells, entrance) <= 1:
				return {"ok": false, "reason": "not_enough_interaction_space"}
		"ruin":
			if interaction_cell == Vector2i(-1, -1):
				return {"ok": false, "reason": "ruin_missing_interaction"}
			if _count_cardinal_walkable(map_data, occupied_cells, interaction_cell) < 2:
				return {"ok": false, "reason": "not_enough_interaction_space"}
		"chest", "easter_egg", "shrine":
			if interaction_cell == Vector2i(-1, -1):
				return {"ok": false, "reason": "missing_interaction"}
			if _count_cardinal_walkable(map_data, occupied_cells, interaction_cell) <= 0:
				return {"ok": false, "reason": "not_enough_interaction_space"}

	return {"ok": true, "reason": ""}


func _rotate_90(grid: Array) -> Array:
	if grid.is_empty():
		return []
	var height: int = grid.size()
	var width: int = Array(grid[0]).size()
	var result: Array = []
	for x in range(width):
		var row: Array[String] = []
		for y in range(height - 1, -1, -1):
			row.append(String(Array(grid[y])[x]))
		result.append(row)
	return result


func _mirror_horizontal(grid: Array) -> Array:
	var result: Array = []
	for row_value in grid:
		var row: Array = Array(row_value).duplicate()
		row.reverse()
		result.append(row)
	return result


func _first_world_marker(origin: Vector2i, local_markers: Array) -> Vector2i:
	if local_markers.is_empty():
		return Vector2i(-1, -1)
	return origin + Vector2i(local_markers[0])


func _world_cells(origin: Vector2i, local_markers: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for marker in local_markers:
		result.append(origin + Vector2i(marker))
	return result


func _failed_check(pattern_def: Dictionary, origin: Vector2i, rotation: int, mirrored: bool, reason: String) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"pattern_id": String(pattern_def.get("id", "")),
		"origin": origin,
		"rotation": rotation,
		"mirrored": mirrored,
		"interaction_cell": Vector2i(-1, -1),
		"entrance_cells": [],
		"occupied_cells": [],
		"blocked_cells_added": 0,
		"walkable_cells_added": 0,
	}


func _has_existing_poi(map_cell) -> bool:
	if map_cell == null:
		return false
	for tag in map_cell.tags:
		if String(tag).begins_with("poi:") and String(tag) != "poi:player_spawn":
			return true
	return false


func _has_existing_structure(map_cell) -> bool:
	if map_cell == null:
		return false
	for tag in map_cell.tags:
		var text := String(tag)
		if text.begins_with("building:") or text.begins_with("structure:") or text.begins_with("stamp:"):
			return true
	return false


func _is_forbidden_terrain(terrain_type: int, pattern_def: Dictionary) -> bool:
	for forbidden in pattern_def.get("forbidden_terrain", []):
		if typeof(forbidden) == TYPE_INT and int(forbidden) == terrain_type:
			return true
	return false


func _count_walkable_area(map_data, occupied_cells: Array[Vector2i], center: Vector2i, radius: int) -> int:
	if center == Vector2i(-1, -1):
		return 0
	var occupied: Dictionary = {}
	for cell in occupied_cells:
		occupied[cell] = true
	var count: int = 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				count += 1
				continue
			if map_data.is_walkable(cell):
				count += 1
	return count


func _count_cardinal_walkable(map_data, occupied_cells: Array[Vector2i], center: Vector2i) -> int:
	if center == Vector2i(-1, -1):
		return 0
	var occupied: Dictionary = {}
	for cell in occupied_cells:
		occupied[cell] = true
	var count: int = 0
	for dir in CARDINAL_DIRS:
		var probe: Vector2i = center + dir
		if occupied.has(probe) or map_data.is_walkable(probe):
			count += 1
	return count


func _first_or_invalid(cells: Array) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(cells[0])


func _append_tag(map_cell, tag: String) -> void:
	if map_cell == null or tag.is_empty():
		return
	if not map_cell.tags.has(tag):
		map_cell.tags.append(tag)

