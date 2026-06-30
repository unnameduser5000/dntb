class_name POIPlacementService
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")
const ConnectivityServiceScript := preload("res://scripts/core/ConnectivityService.gd")
const BuildingPlacementServiceScript := preload("res://scripts/core/BuildingPlacementService.gd")
const BuildingPatternLibraryScript := preload("res://scripts/core/BuildingPatternLibrary.gd")


enum POIType {
	PLAYER_SPAWN,
	TAVERN,
	CHALLENGE_ENTRANCE,
	CHEST,
	RUIN,
	EASTER_EGG,
}


var connectivity_service = ConnectivityServiceScript.new()
var building_placement_service = BuildingPlacementServiceScript.new()


func place_pois(map_data, rng: RandomNumberGenerator, config = null) -> void:
	if map_data == null:
		return

	var walkable: Array[Vector2i] = map_data.get_walkable_cells()
	if walkable.is_empty():
		return
	var walkable_sample: Array[Vector2i] = _sample_cells(walkable, _anchor_sample_limit(map_data, 768), rng)
	var walkable_fallback_sample: Array[Vector2i] = _sample_cells(walkable, _anchor_fallback_limit(map_data, 2048), rng)

	var taken: Dictionary = {}
	var spawn_cell: Vector2i = _pick_player_spawn(map_data, walkable_sample, config)
	if spawn_cell == Vector2i(-1, -1):
		spawn_cell = _pick_player_spawn(map_data, walkable_fallback_sample, config)
	if spawn_cell == Vector2i(-1, -1):
		spawn_cell = _pick_nearest_available(walkable_fallback_sample, Vector2i(map_data.width / 2, map_data.height / 2), taken)
	if spawn_cell == Vector2i(-1, -1):
		return

	map_data.set_player_spawn(spawn_cell)
	taken[spawn_cell] = true

	var reachable: Dictionary = connectivity_service.flood_fill_walkable(map_data, spawn_cell)
	var reachable_cells: Array[Vector2i] = []
	for cell in reachable.keys():
		reachable_cells.append(cell)
	if reachable_cells.is_empty():
		reachable_cells = walkable_fallback_sample.duplicate()
	var reachable_sample: Array[Vector2i] = _sample_cells(reachable_cells, _anchor_sample_limit(map_data, 640), rng)
	var reachable_fallback_sample: Array[Vector2i] = _sample_cells(reachable_cells, _anchor_fallback_limit(map_data, 1664), rng)

	var tavern_cell: Vector2i = _pick_tavern(map_data, reachable_sample, spawn_cell, taken)
	if tavern_cell == Vector2i(-1, -1):
		tavern_cell = _pick_tavern(map_data, reachable_fallback_sample, spawn_cell, taken)
	if tavern_cell != Vector2i(-1, -1):
		map_data.set_tavern_cell(tavern_cell)
		taken[tavern_cell] = true

	for _index in range(int(config.challenge_count) if config != null else 1):
		var challenge_cell: Vector2i = _pick_challenge_entrance(map_data, walkable_sample, spawn_cell, taken)
		if challenge_cell == Vector2i(-1, -1):
			challenge_cell = _pick_challenge_entrance(map_data, walkable_fallback_sample, spawn_cell, taken)
		if challenge_cell == Vector2i(-1, -1):
			break
		map_data.add_challenge_cell(challenge_cell)
		taken[challenge_cell] = true

	for _index in range(int(config.chest_count) if config != null else 1):
		var chest_cell: Vector2i = _pick_chest(map_data, walkable_sample, spawn_cell, taken)
		if chest_cell == Vector2i(-1, -1):
			chest_cell = _pick_chest(map_data, walkable_fallback_sample, spawn_cell, taken)
		if chest_cell == Vector2i(-1, -1):
			break
		map_data.add_chest_cell(chest_cell)
		taken[chest_cell] = true

	for _index in range(int(config.ruin_count) if config != null else 1):
		var ruin_cell: Vector2i = _pick_ruin(map_data, walkable_sample, spawn_cell, taken)
		if ruin_cell == Vector2i(-1, -1):
			ruin_cell = _pick_ruin(map_data, walkable_fallback_sample, spawn_cell, taken)
		if ruin_cell == Vector2i(-1, -1):
			break
		map_data.add_ruin_cell(ruin_cell)
		taken[ruin_cell] = true

	for _index in range(int(config.easter_egg_count) if config != null else 1):
		var egg_cell: Vector2i = _pick_easter_egg(map_data, walkable_sample, spawn_cell, taken)
		if egg_cell == Vector2i(-1, -1):
			egg_cell = _pick_easter_egg(map_data, walkable_fallback_sample, spawn_cell, taken)
		if egg_cell == Vector2i(-1, -1):
			break
		map_data.add_easter_egg_cell(egg_cell)
		taken[egg_cell] = true

	var anchor_cells := {
		BuildingPatternLibraryScript.POI_TYPE_TAVERN: map_data.tavern_cell,
		BuildingPatternLibraryScript.POI_TYPE_CHALLENGE: _first_or_invalid_cell(map_data.challenge_cells),
		BuildingPatternLibraryScript.POI_TYPE_RUIN: _first_or_invalid_cell(map_data.ruin_cells),
		BuildingPatternLibraryScript.POI_TYPE_CHEST: _first_or_invalid_cell(map_data.chest_cells),
		BuildingPatternLibraryScript.POI_TYPE_EGG: _first_or_invalid_cell(map_data.easter_egg_cells),
	}

	_clear_legacy_poi_tags(map_data)
	map_data.tavern_cell = Vector2i(-1, -1)
	map_data.challenge_cells.clear()
	map_data.chest_cells.clear()
	map_data.ruin_cells.clear()
	map_data.easter_egg_cells.clear()
	map_data.shrine_cells.clear()
	map_data.poi_records.clear()
	map_data.building_stamp_results.clear()
	map_data.stamp_success_count = 0
	map_data.stamp_failure_count = 0
	map_data.stamp_failures.clear()

	# Legacy single-cell picks above remain as placement anchors for the first
	# PatternStamp pass. Successful building stamps then replace the effective
	# POI footprint data without deleting this older scaffold outright.
	building_placement_service.place_buildings(map_data, rng, config, anchor_cells)
	_relocate_spawn_into_tavern(map_data)


func _pick_player_spawn(map_data, walkable: Array[Vector2i], config) -> Vector2i:
	var edge_margin: int = int(config.spawn_edge_margin) if config != null else 3
	var open_radius: int = int(config.spawn_open_radius) if config != null else 2
	var open_min: int = int(config.spawn_open_min_cells) if config != null else 8
	var center: Vector2 = Vector2(map_data.width * 0.5, map_data.height * 0.5)
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF

	for cell in walkable:
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		if _distance_from_edge(map_data, cell) < edge_margin:
			continue
		if map_cell.terrain_type != MapCellScript.TerrainType.PLAIN and map_cell.terrain_type != MapCellScript.TerrainType.HILL:
			continue
		var open_space: int = _count_walkable_nearby(map_data, cell, open_radius)
		if open_space < open_min:
			continue
		var terrain_bonus: float = 2.5 if map_cell.terrain_type == MapCellScript.TerrainType.PLAIN else 1.25
		var score: float = terrain_bonus * 4.0 + float(open_space) * 1.5 - cell.distance_to(center) * 0.8
		if score > best_score:
			best = cell
			best_score = score

	return best


func _pick_tavern(map_data, reachable_cells: Array[Vector2i], spawn_cell: Vector2i, taken: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in reachable_cells:
		if taken.has(cell):
			continue
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		var distance: float = cell.distance_to(spawn_cell)
		var open_space: int = _count_walkable_nearby(map_data, cell, 2)
		var cardinal_open: int = _count_walkable_cardinal_neighbors(map_data, cell)
		var terrain_bonus: float = 3.0 if map_cell.terrain_type == MapCellScript.TerrainType.PLAIN else 1.0
		var score: float = terrain_bonus * 4.0 + float(open_space) * 1.4 + float(cardinal_open) * 1.5 - absf(distance - 7.0) * 0.7
		if _distance_from_edge(map_data, cell) < 2:
			score -= 6.0
		if score > best_score:
			best = cell
			best_score = score
	return best


func _pick_challenge_entrance(map_data, walkable: Array[Vector2i], spawn_cell: Vector2i, taken: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in walkable:
		if taken.has(cell):
			continue
		var distance: float = cell.distance_to(spawn_cell)
		var mountain_touch: int = _adjacent_terrain_count(map_data, cell, [
			MapCellScript.TerrainType.MOUNTAIN,
			MapCellScript.TerrainType.PEAK,
		])
		var forest_touch: int = _adjacent_terrain_count(map_data, cell, [MapCellScript.TerrainType.FOREST])
		var open_space: int = _count_walkable_nearby(map_data, cell, 2)
		var cardinal_open: int = _count_walkable_cardinal_neighbors(map_data, cell)
		if cardinal_open <= 1:
			continue
		var score: float = float(mountain_touch) * 2.4 + float(forest_touch) * 1.2 + distance * 0.35 + float(open_space) * 0.8 + float(cardinal_open) * 1.6
		if score > best_score:
			best = cell
			best_score = score
	return best


func _pick_chest(map_data, walkable: Array[Vector2i], spawn_cell: Vector2i, taken: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in walkable:
		if taken.has(cell):
			continue
		var distance: float = cell.distance_to(spawn_cell)
		var dead_end_bias: int = 4 - mini(4, _count_walkable_cardinal_neighbors(map_data, cell))
		var terrain_touch: int = _adjacent_terrain_count(map_data, cell, [
			MapCellScript.TerrainType.MOUNTAIN,
			MapCellScript.TerrainType.PEAK,
			MapCellScript.TerrainType.FOREST,
			MapCellScript.TerrainType.SWAMP,
		])
		var cardinal_open: int = _count_walkable_cardinal_neighbors(map_data, cell)
		var score: float = distance * 0.30 + float(dead_end_bias) * 1.2 + float(terrain_touch) * 1.1 + float(cardinal_open) * 0.8
		if score > best_score:
			best = cell
			best_score = score
	return best


func _pick_ruin(map_data, walkable: Array[Vector2i], spawn_cell: Vector2i, taken: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in walkable:
		if taken.has(cell):
			continue
		var distance: float = cell.distance_to(spawn_cell)
		var terrain_touch: int = _adjacent_terrain_count(map_data, cell, [
			MapCellScript.TerrainType.HILL,
			MapCellScript.TerrainType.MOUNTAIN,
			MapCellScript.TerrainType.PEAK,
			MapCellScript.TerrainType.FOREST,
			MapCellScript.TerrainType.DESERT,
			MapCellScript.TerrainType.SWAMP,
		])
		var cardinal_open: int = _count_walkable_cardinal_neighbors(map_data, cell)
		var score: float = float(terrain_touch) * 1.8 + distance * 0.28 + float(_distance_from_edge(map_data, cell)) * 0.18 + float(cardinal_open) * 1.0
		if score > best_score:
			best = cell
			best_score = score
	return best


func _pick_easter_egg(map_data, walkable: Array[Vector2i], spawn_cell: Vector2i, taken: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in walkable:
		if taken.has(cell):
			continue
		var distance: float = cell.distance_to(spawn_cell)
		var edge_bias: float = maxf(0.0, 5.0 - float(_distance_from_edge(map_data, cell)))
		var terrain_touch: int = _adjacent_terrain_count(map_data, cell, [
			MapCellScript.TerrainType.PEAK,
			MapCellScript.TerrainType.FOREST,
			MapCellScript.TerrainType.SWAMP,
			MapCellScript.TerrainType.DESERT,
		])
		var cardinal_open: int = _count_walkable_cardinal_neighbors(map_data, cell)
		var score: float = distance * 0.42 + edge_bias * 1.3 + float(terrain_touch) * 1.0 + float(cardinal_open) * 0.9
		if score > best_score:
			best = cell
			best_score = score
	return best


func _relocate_spawn_into_tavern(map_data) -> void:
	if map_data == null:
		return
	for record in map_data.get_poi_records():
		if String(record.get("type", "")) != "tavern":
			continue
		var spawn_cell: Vector2i = _pick_tavern_spawn_cell(map_data, record)
		if spawn_cell != Vector2i(-1, -1):
			map_data.set_player_spawn(spawn_cell)
		return


func _pick_tavern_spawn_cell(map_data, record: Dictionary) -> Vector2i:
	if map_data == null:
		return Vector2i(-1, -1)
	var interaction_cell: Vector2i = Vector2i(record.get("interaction_cell", Vector2i(-1, -1)))
	var occupied_cells: Array = record.get("occupied_cells", [])
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = INF
	for cell_value in occupied_cells:
		var cell: Vector2i = Vector2i(cell_value)
		if not map_data.is_walkable(cell):
			continue
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		var base_score: float = cell.distance_to(interaction_cell) if interaction_cell != Vector2i(-1, -1) else 0.0
		if map_cell.tags.has("building_floor"):
			base_score -= 2.0
		elif map_cell.tags.has("building_door"):
			base_score -= 1.0
		elif map_cell.tags.has("building_open_ground"):
			base_score += 0.5
		if base_score < best_score:
			best = cell
			best_score = base_score
	if best != Vector2i(-1, -1):
		return best
	if interaction_cell != Vector2i(-1, -1) and map_data.is_walkable(interaction_cell):
		return interaction_cell
	return Vector2i(-1, -1)


func _pick_nearest_available(candidates: Array[Vector2i], preferred: Vector2i, taken: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for cell in candidates:
		if taken.has(cell):
			continue
		var distance: float = float(cell.distance_squared_to(preferred))
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _count_walkable_nearby(map_data, center: Vector2i, radius: int) -> int:
	var count: int = 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if map_data.is_walkable(cell):
				count += 1
	return count


func _count_walkable_cardinal_neighbors(map_data, cell: Vector2i) -> int:
	var count: int = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if map_data.is_walkable(cell + dir):
			count += 1
	return count


func _adjacent_terrain_count(map_data, cell: Vector2i, terrain_types: Array) -> int:
	var count: int = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = map_data.get_cell(cell + dir)
		if neighbor != null and terrain_types.has(int(neighbor.terrain_type)):
			count += 1
	return count


func _distance_from_edge(map_data, cell: Vector2i) -> int:
	return mini(mini(cell.x, cell.y), mini(map_data.width - 1 - cell.x, map_data.height - 1 - cell.y))


func _first_or_invalid_cell(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[0]


func _clear_legacy_poi_tags(map_data) -> void:
	for cell in map_data.get_all_cells():
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		var kept: Array[String] = []
		for tag in map_cell.tags:
			var text := String(tag)
			if text.begins_with("poi:") and text != "poi:player_spawn":
				continue
			kept.append(text)
		map_cell.tags = kept


func _anchor_sample_limit(map_data, base_limit: int) -> int:
	if map_data == null:
		return base_limit
	var area: int = max(1, map_data.width * map_data.height)
	if area >= 256 * 256:
		return int(base_limit)
	if area >= 128 * 128:
		return int(maxi(384, int(base_limit * 0.75)))
	return int(maxi(192, int(base_limit * 0.5)))


func _anchor_fallback_limit(map_data, base_limit: int) -> int:
	if map_data == null:
		return base_limit
	var area: int = max(1, map_data.width * map_data.height)
	if area >= 1024 * 1024:
		return mini(base_limit, 2048)
	if area >= 512 * 512:
		return mini(base_limit, 1792)
	if area >= 256 * 256:
		return mini(base_limit, 1536)
	return base_limit


func _sample_cells(cells: Array[Vector2i], limit: int, rng: RandomNumberGenerator = null) -> Array[Vector2i]:
	if cells.size() <= limit:
		return cells.duplicate()
	var result: Array[Vector2i] = []
	var step: float = float(cells.size()) / float(limit)
	var offset: float = rng.randf() * step if rng != null else 0.0
	for index in range(limit):
		var picked_index: int = mini(cells.size() - 1, int(floor(offset + float(index) * step)))
		result.append(cells[picked_index])
	return result
