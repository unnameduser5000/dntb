class_name MapData
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")
const INVALID_CELL := Vector2i(-1, -1)

var width: int = 0
var height: int = 0
var cells: Dictionary = {}
var seed: String = ""
var player_spawn: Vector2i = Vector2i.ZERO
var tavern_cell: Vector2i = INVALID_CELL
var challenge_cells: Array[Vector2i] = []
var chest_cells: Array[Vector2i] = []
var ruin_cells: Array[Vector2i] = []
var easter_egg_cells: Array[Vector2i] = []
var shrine_cells: Array[Vector2i] = []
var reachable_count: int = 0
var unreachable_poi_count: int = 0
var carved_pass_count: int = 0
var connectivity_report: Dictionary = {}
var generation_total_ms: float = 0.0
var generation_breakdown_ms: Dictionary = {}
var poi_records: Array[Dictionary] = []
var building_stamp_results: Array[Dictionary] = []
var stamp_success_count: int = 0
var stamp_failure_count: int = 0
var stamp_failures: Array[Dictionary] = []
var building_failure_summary: Dictionary = {}
var _all_cells_cache: Array[Vector2i] = []
var _walkable_cells_cache: Array[Vector2i] = []
var _walkable_cache_dirty: bool = true


func setup(new_width: int, new_height: int) -> void:
	width = new_width
	height = new_height
	cells.clear()
	player_spawn = Vector2i.ZERO
	tavern_cell = INVALID_CELL
	challenge_cells.clear()
	chest_cells.clear()
	ruin_cells.clear()
	easter_egg_cells.clear()
	shrine_cells.clear()
	reachable_count = 0
	unreachable_poi_count = 0
	carved_pass_count = 0
	connectivity_report.clear()
	generation_total_ms = 0.0
	generation_breakdown_ms.clear()
	poi_records.clear()
	building_stamp_results.clear()
	stamp_success_count = 0
	stamp_failure_count = 0
	stamp_failures.clear()
	building_failure_summary.clear()
	_all_cells_cache.clear()
	_walkable_cells_cache.clear()
	_walkable_cache_dirty = true


func get_size() -> Vector2i:
	return Vector2i(width, height)


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_cell(cell: Vector2i):
	return cells.get(cell)


func get_or_create_cell(cell: Vector2i):
	if not is_in_bounds(cell):
		return null
	var existing = cells.get(cell)
	if existing != null:
		return existing
	var created = MapCellScript.new()
	created.cell = cell
	cells[cell] = created
	return created


func set_cell(cell: Vector2i, map_cell) -> void:
	if map_cell == null or not is_in_bounds(cell):
		return
	map_cell.cell = cell
	cells[cell] = map_cell
	_walkable_cache_dirty = true


func set_terrain(cell: Vector2i, terrain_type: int) -> void:
	var map_cell = get_or_create_cell(cell)
	if map_cell == null:
		return
	map_cell.terrain_type = terrain_type
	_apply_terrain_profile(map_cell, terrain_type)
	_walkable_cache_dirty = true


func add_blocked(cell: Vector2i, opaque: bool = true) -> void:
	if not is_in_bounds(cell):
		return
	var map_cell = get_or_create_cell(cell)
	if map_cell == null:
		return
	map_cell.walkable = false
	map_cell.blocks_vision = opaque
	map_cell.move_cost = 999
	map_cell.terrain_type = MapCellScript.TerrainType.MOUNTAIN if opaque else MapCellScript.TerrainType.RIVER
	if opaque:
		if not map_cell.tags.has("blocked"):
			map_cell.tags.append("blocked")
	else:
		if not map_cell.tags.has("shallow_block"):
			map_cell.tags.append("shallow_block")
	_walkable_cache_dirty = true


func is_walkable(cell: Vector2i) -> bool:
	var map_cell = get_cell(cell)
	if map_cell == null:
		return false
	return bool(map_cell.walkable)


func blocks_vision(cell: Vector2i) -> bool:
	var map_cell = get_cell(cell)
	if map_cell == null:
		return true
	return bool(map_cell.blocks_vision)


func get_all_cells() -> Array[Vector2i]:
	if _all_cells_cache.is_empty() and width > 0 and height > 0:
		for y in range(height):
			for x in range(width):
				_all_cells_cache.append(Vector2i(x, y))
	return _all_cells_cache


func set_player_spawn(cell: Vector2i) -> void:
	if not is_in_bounds(cell):
		return
	if player_spawn != Vector2i.ZERO and is_in_bounds(player_spawn):
		var previous_cell = get_cell(player_spawn)
		if previous_cell != null:
			previous_cell.tags.erase("poi:player_spawn")
	player_spawn = cell
	_add_tag(cell, "poi:player_spawn")


func set_tavern_cell(cell: Vector2i) -> void:
	if not is_in_bounds(cell):
		return
	tavern_cell = cell
	_add_tag(cell, "poi:tavern")


func add_challenge_cell(cell: Vector2i) -> void:
	if is_in_bounds(cell) and not challenge_cells.has(cell):
		challenge_cells.append(cell)
		_add_tag(cell, "poi:challenge_entrance")


func add_chest_cell(cell: Vector2i) -> void:
	if is_in_bounds(cell) and not chest_cells.has(cell):
		chest_cells.append(cell)
		_add_tag(cell, "poi:chest")


func add_ruin_cell(cell: Vector2i) -> void:
	if is_in_bounds(cell) and not ruin_cells.has(cell):
		ruin_cells.append(cell)
		_add_tag(cell, "poi:ruin")


func add_easter_egg_cell(cell: Vector2i) -> void:
	if is_in_bounds(cell) and not easter_egg_cells.has(cell):
		easter_egg_cells.append(cell)
		_add_tag(cell, "poi:easter_egg")


func add_shrine_cell(cell: Vector2i) -> void:
	if is_in_bounds(cell) and not shrine_cells.has(cell):
		shrine_cells.append(cell)
		_add_tag(cell, "poi:shrine")


func get_walkable_cells() -> Array[Vector2i]:
	if _walkable_cache_dirty:
		_walkable_cells_cache.clear()
		for cell in get_all_cells():
			if is_walkable(cell):
				_walkable_cells_cache.append(cell)
		_walkable_cache_dirty = false
	return _walkable_cells_cache


func get_all_poi_entries() -> Array[Dictionary]:
	if not poi_records.is_empty():
		var records: Array[Dictionary] = []
		if player_spawn != INVALID_CELL:
			records.append({"kind": "player_spawn", "cell": player_spawn})
		for record in poi_records:
			var entry: Dictionary = {
				"id": String(record.get("id", "")),
				"kind": String(record.get("type", "")),
				"type": String(record.get("type", "")),
				"pattern_id": String(record.get("pattern_id", "")),
				"cell": Vector2i(record.get("interaction_cell", INVALID_CELL)),
				"interaction_cell": Vector2i(record.get("interaction_cell", INVALID_CELL)),
				"origin": Vector2i(record.get("origin", INVALID_CELL)),
				"size": Vector2i(record.get("size", Vector2i.ZERO)),
				"entrance_cells": Array(record.get("entrance_cells", [])),
				"occupied_cells": Array(record.get("occupied_cells", [])),
				"tags": Array(record.get("tags", [])),
			}
			records.append(entry)
		return records

	var result: Array[Dictionary] = []
	if player_spawn != INVALID_CELL:
		result.append({"kind": "player_spawn", "cell": player_spawn})
	if tavern_cell != INVALID_CELL:
		result.append({"kind": "tavern", "cell": tavern_cell})
	for cell in challenge_cells:
		result.append({"kind": "challenge_entrance", "cell": cell})
	for cell in chest_cells:
		result.append({"kind": "chest", "cell": cell})
	for cell in ruin_cells:
		result.append({"kind": "ruin", "cell": cell})
	for cell in easter_egg_cells:
		result.append({"kind": "easter_egg", "cell": cell})
	for cell in shrine_cells:
		result.append({"kind": "shrine", "cell": cell})
	return result


func get_all_poi_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in get_all_poi_entries():
		var cell: Vector2i = entry.get("cell", INVALID_CELL)
		if cell != INVALID_CELL and not result.has(cell):
			result.append(cell)
	return result


func get_terrain_counts() -> Dictionary:
	var counts: Dictionary = {
		"plain": 0,
		"forest": 0,
		"tree": 0,
		"rock": 0,
		"statue": 0,
		"structure_wall": 0,
		"hill": 0,
		"mountain": 0,
		"peak": 0,
		"water": 0,
		"river": 0,
		"bridge": 0,
		"swamp": 0,
		"desert": 0,
	}
	for map_cell in cells.values():
		if map_cell == null:
			continue
		var terrain_name: String = map_cell.terrain_name() if map_cell.has_method("terrain_name") else "unknown"
		counts[terrain_name] = int(counts.get(terrain_name, 0)) + 1
	return counts


func get_debug_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Map seed: %s" % seed)
	lines.append("Map size: %dx%d" % [width, height])
	var terrain_counts: Dictionary = get_terrain_counts()
	lines.append("Terrain: plain %d forest %d tree %d hill %d mountain %d peak %d water %d river %d bridge %d swamp %d desert %d" % [
		int(terrain_counts.get("plain", 0)),
		int(terrain_counts.get("forest", 0)),
		int(terrain_counts.get("tree", 0)),
		int(terrain_counts.get("hill", 0)),
		int(terrain_counts.get("mountain", 0)),
		int(terrain_counts.get("peak", 0)),
		int(terrain_counts.get("water", 0)),
		int(terrain_counts.get("river", 0)),
		int(terrain_counts.get("bridge", 0)),
		int(terrain_counts.get("swamp", 0)),
		int(terrain_counts.get("desert", 0)),
	])
	lines.append("Structures: wall %d rock %d statue %d | Stamp success %d failure %d" % [
		int(terrain_counts.get("structure_wall", 0)),
		int(terrain_counts.get("rock", 0)),
		int(terrain_counts.get("statue", 0)),
		int(stamp_success_count),
		int(stamp_failure_count),
	])
	lines.append("POI: spawn %s tavern %s challenge %d chest %d ruin %d egg %d shrine %d" % [
		str(player_spawn),
		str(tavern_cell),
		challenge_cells.size(),
		chest_cells.size(),
		ruin_cells.size(),
		easter_egg_cells.size(),
		shrine_cells.size(),
	])
	lines.append("Reachable: %d | Unreachable POI: %d | Carved passes: %d" % [reachable_count, unreachable_poi_count, carved_pass_count])
	if generation_total_ms > 0.0:
		lines.append("Generation: %.2f ms" % generation_total_ms)
		if not generation_breakdown_ms.is_empty():
			var parts: Array[String] = []
			for key in [
				"fill_plain_ms",
				"mountain_generation_ms",
				"terrain_generation_ms",
				"river_generation_ms",
				"poi_placement_ms",
				"obstacle_generation_ms",
				"connectivity_ms",
			]:
				if generation_breakdown_ms.has(key):
					parts.append("%s %.2f" % [String(key).trim_suffix("_ms"), float(generation_breakdown_ms[key])])
			if not parts.is_empty():
				lines.append("Generation breakdown: %s" % ", ".join(parts))
	return lines


func get_poi_records() -> Array[Dictionary]:
	return poi_records.duplicate(true)


func register_poi_record(record: Dictionary) -> void:
	if record.is_empty():
		return
	var poi_type: String = String(record.get("type", ""))
	var existing_type_count: int = 0
	for existing in poi_records:
		if String(existing.get("type", "")) == poi_type:
			existing_type_count += 1
	if existing_type_count == 0 and poi_type == "tavern":
		tavern_cell = INVALID_CELL
	elif existing_type_count == 0 and poi_type == "challenge_entrance":
		challenge_cells.clear()
	elif existing_type_count == 0 and poi_type == "chest":
		chest_cells.clear()
	elif existing_type_count == 0 and poi_type == "ruin":
		ruin_cells.clear()
	elif existing_type_count == 0 and poi_type == "easter_egg":
		easter_egg_cells.clear()
	elif existing_type_count == 0 and poi_type == "shrine":
		shrine_cells.clear()
	poi_records.append(record.duplicate(true))
	var interaction_cell: Vector2i = Vector2i(record.get("interaction_cell", INVALID_CELL))
	match poi_type:
		"tavern":
			tavern_cell = interaction_cell
		"challenge_entrance":
			if interaction_cell != INVALID_CELL and not challenge_cells.has(interaction_cell):
				challenge_cells.append(interaction_cell)
		"chest":
			if interaction_cell != INVALID_CELL and not chest_cells.has(interaction_cell):
				chest_cells.append(interaction_cell)
		"ruin":
			if interaction_cell != INVALID_CELL and not ruin_cells.has(interaction_cell):
				ruin_cells.append(interaction_cell)
		"easter_egg":
			if interaction_cell != INVALID_CELL and not easter_egg_cells.has(interaction_cell):
				easter_egg_cells.append(interaction_cell)
		"shrine":
			if interaction_cell != INVALID_CELL and not shrine_cells.has(interaction_cell):
				shrine_cells.append(interaction_cell)


func add_building_stamp_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	building_stamp_results.append(result.duplicate(true))
	if bool(result.get("success", false)):
		stamp_success_count += 1
	else:
		stamp_failure_count += 1
		stamp_failures.append(result.duplicate(true))
		_track_building_failure(result)


func get_building_count_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for record in poi_records:
		var poi_type: String = String(record.get("type", ""))
		if poi_type.is_empty():
			continue
		counts[poi_type] = int(counts.get(poi_type, 0)) + 1
	return counts


func get_building_failure_summary() -> Dictionary:
	return building_failure_summary.duplicate(true)


func _add_tag(cell: Vector2i, tag: String) -> void:
	var map_cell = get_or_create_cell(cell)
	if map_cell == null or tag.is_empty():
		return
	if not map_cell.tags.has(tag):
		map_cell.tags.append(tag)


func _apply_terrain_profile(map_cell, terrain_type: int) -> void:
	var preserved_tags: Array[String] = []
	for tag in map_cell.tags:
		if String(tag).begins_with("poi:") or String(tag).begins_with("building:") or String(tag).begins_with("structure:") or String(tag).begins_with("stamp:") or String(tag) in ["entrance", "interactable", "building_floor", "building_wall", "building_open_ground", "building_door", "rubble", "tree_block", "forest_blocker", "statue", "mountain_pass"]:
			preserved_tags.append(String(tag))
	map_cell.tags = preserved_tags
	if terrain_type in [MapCellScript.TerrainType.PLAIN, MapCellScript.TerrainType.FOREST, MapCellScript.TerrainType.HILL, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK, MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.BRIDGE, MapCellScript.TerrainType.SWAMP, MapCellScript.TerrainType.DESERT]:
		map_cell.display_symbol_override = ""
	match terrain_type:
		MapCellScript.TerrainType.PLAIN:
			map_cell.walkable = true
			map_cell.blocks_vision = false
			map_cell.move_cost = 1
		MapCellScript.TerrainType.FOREST:
			map_cell.walkable = true
			map_cell.blocks_vision = false
			map_cell.move_cost = 2
			map_cell.tags.append("forest")
		MapCellScript.TerrainType.TREE:
			map_cell.walkable = false
			map_cell.blocks_vision = true
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "tree_block")
			_append_unique_tag(map_cell, "forest_blocker")
		MapCellScript.TerrainType.ROCK:
			map_cell.walkable = false
			map_cell.blocks_vision = true
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "rubble")
		MapCellScript.TerrainType.STATUE:
			map_cell.walkable = false
			map_cell.blocks_vision = true
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "statue")
		MapCellScript.TerrainType.STRUCTURE_WALL:
			map_cell.walkable = false
			map_cell.blocks_vision = true
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "building_wall")
		MapCellScript.TerrainType.HILL:
			map_cell.walkable = true
			map_cell.blocks_vision = false
			map_cell.move_cost = 2
			_append_unique_tag(map_cell, "hill")
		MapCellScript.TerrainType.MOUNTAIN:
			map_cell.walkable = false
			map_cell.blocks_vision = true
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "mountain")
		MapCellScript.TerrainType.PEAK:
			map_cell.walkable = false
			map_cell.blocks_vision = true
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "peak")
		MapCellScript.TerrainType.WATER:
			map_cell.walkable = false
			map_cell.blocks_vision = false
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "water")
		MapCellScript.TerrainType.RIVER:
			map_cell.walkable = false
			map_cell.blocks_vision = false
			map_cell.move_cost = 999
			_append_unique_tag(map_cell, "river")
		MapCellScript.TerrainType.BRIDGE:
			map_cell.walkable = true
			map_cell.blocks_vision = false
			map_cell.move_cost = 1
			_append_unique_tag(map_cell, "bridge")
		MapCellScript.TerrainType.SWAMP:
			map_cell.walkable = true
			map_cell.blocks_vision = false
			map_cell.move_cost = 3
			_append_unique_tag(map_cell, "swamp")
		MapCellScript.TerrainType.DESERT:
			map_cell.walkable = true
			map_cell.blocks_vision = false
			map_cell.move_cost = 2
			_append_unique_tag(map_cell, "desert")


func _append_unique_tag(map_cell, tag: String) -> void:
	if map_cell == null or tag.is_empty():
		return
	if not map_cell.tags.has(tag):
		map_cell.tags.append(tag)


func _track_building_failure(result: Dictionary) -> void:
	var poi_type: String = String(result.get("poi_type", "unknown"))
	var reason: String = String(result.get("reason", "unknown"))
	if not building_failure_summary.has(poi_type):
		building_failure_summary[poi_type] = {
			"attempts": 0,
			"reasons": {},
			"last_failure": {},
		}
	var bucket: Dictionary = building_failure_summary[poi_type]
	bucket["attempts"] = int(bucket.get("attempts", 0)) + int(maxi(1, int(result.get("attempt_count", 1))))
	var reasons: Dictionary = bucket.get("reasons", {})
	reasons[reason] = int(reasons.get(reason, 0)) + 1
	bucket["reasons"] = reasons
	bucket["last_failure"] = result.duplicate(true)
	building_failure_summary[poi_type] = bucket
