class_name ObstacleGenerator
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")

const CARDINAL_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const EIGHT_DIRS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]


func generate(map_data, config, rng: RandomNumberGenerator) -> void:
	if map_data == null or config == null or rng == null:
		return

	var protected_cells: Dictionary = _build_protected_cells(map_data, config)
	_place_forest_blockers(map_data, config, rng, protected_cells)
	_clear_poi_approach_areas(map_data, config)


func _build_protected_cells(map_data, config) -> Dictionary:
	var protected: Dictionary = {}
	_mark_radius(protected, map_data.player_spawn, int(config.spawn_clear_radius))
	_mark_radius(protected, map_data.tavern_cell, int(config.tavern_clear_radius))
	for cell in map_data.challenge_cells:
		_mark_radius(protected, cell, int(config.challenge_clear_radius))
	for cell in map_data.chest_cells:
		_mark_radius(protected, cell, int(config.poi_clear_radius))
	for cell in map_data.ruin_cells:
		_mark_radius(protected, cell, int(config.poi_clear_radius))
	for cell in map_data.easter_egg_cells:
		_mark_radius(protected, cell, int(config.poi_clear_radius))
	for cell in map_data.shrine_cells:
		_mark_radius(protected, cell, int(config.poi_clear_radius))
	return protected


func _mark_radius(protected: Dictionary, center: Vector2i, radius: int) -> void:
	if center == Vector2i(-1, -1):
		return
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			protected[Vector2i(x, y)] = true


func _place_forest_blockers(map_data, config, rng: RandomNumberGenerator, protected_cells: Dictionary) -> void:
	var forest_cells: Array[Vector2i] = _get_forest_floor_cells(map_data)
	if forest_cells.is_empty():
		return

	var density_min: float = clampf(float(config.forest_blocker_density_min), 0.0, 0.9)
	var density_max: float = clampf(float(config.forest_blocker_density_max), density_min, 0.95)
	var target_density: float = rng.randf_range(density_min, density_max)
	var target_blocker_count: int = maxi(0, int(round(float(forest_cells.size()) * target_density)))
	var placed_cells: Dictionary = {}
	var attempts: int = 0
	var attempt_limit: int = maxi(40, target_blocker_count * 10)

	while placed_cells.size() < target_blocker_count and attempts < attempt_limit:
		attempts += 1
		var seed: Vector2i = forest_cells[rng.randi_range(0, forest_cells.size() - 1)]
		if protected_cells.has(seed):
			continue
		if not _is_forest_floor(map_data, seed):
			continue

		var cluster_target: int = rng.randi_range(
			int(config.forest_blocker_cluster_min_size),
			maxi(int(config.forest_blocker_cluster_min_size), int(config.forest_blocker_cluster_max_size))
		)
		var cluster: Array[Vector2i] = _grow_cluster(map_data, seed, cluster_target, int(config.forest_blocker_cluster_radius), protected_cells, placed_cells, rng, int(config.forest_blocker_max_local_density))
		for cell in cluster:
			map_data.set_terrain(cell, MapCellScript.TerrainType.TREE)
			placed_cells[cell] = true
			if placed_cells.size() >= target_blocker_count:
				break


func _grow_cluster(map_data, seed: Vector2i, target_size: int, radius: int, protected_cells: Dictionary, placed_cells: Dictionary, rng: RandomNumberGenerator, max_local_density: int) -> Array[Vector2i]:
	var cluster: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [seed]
	var local_seen: Dictionary = {seed: true}

	while not frontier.is_empty() and cluster.size() < target_size:
		var current_index: int = rng.randi_range(0, frontier.size() - 1)
		var current: Vector2i = frontier[current_index]
		frontier.remove_at(current_index)
		if not _can_place_tree(map_data, current, protected_cells, placed_cells, cluster, max_local_density):
			continue
		cluster.append(current)

		for offset in _neighbor_offsets(radius):
			var next: Vector2i = current + offset
			if local_seen.has(next):
				continue
			local_seen[next] = true
			if not map_data.is_in_bounds(next):
				continue
			if not _is_forest_floor(map_data, next):
				continue
			if protected_cells.has(next) or placed_cells.has(next):
				continue
			if rng.randf() < 0.72:
				frontier.append(next)
		if frontier.is_empty() and cluster.size() < target_size:
			for dir in EIGHT_DIRS:
				var neighbor: Vector2i = seed + dir
				if local_seen.has(neighbor):
					continue
				local_seen[neighbor] = true
				if map_data.is_in_bounds(neighbor) and _is_forest_floor(map_data, neighbor) and not protected_cells.has(neighbor) and not placed_cells.has(neighbor):
					frontier.append(neighbor)
	return cluster


func _neighbor_offsets(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x == 0 and y == 0:
				continue
			if absi(x) + absi(y) > radius + 1:
				continue
			result.append(Vector2i(x, y))
	return result


func _can_place_tree(map_data, cell: Vector2i, protected_cells: Dictionary, placed_cells: Dictionary, cluster: Array[Vector2i], max_local_density: int) -> bool:
	if not map_data.is_in_bounds(cell):
		return false
	if protected_cells.has(cell) or placed_cells.has(cell):
		return false
	if not _is_forest_floor(map_data, cell):
		return false
	if _would_create_dense_patch(map_data, cell, cluster, max_local_density):
		return false
	if _would_create_solid_square(map_data, cell, cluster):
		return false
	return true


func _would_create_dense_patch(map_data, cell: Vector2i, cluster: Array[Vector2i], max_local_density: int) -> bool:
	var blocked_count: int = 0
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var probe := Vector2i(x, y)
			if probe == cell or cluster.has(probe):
				blocked_count += 1
				continue
			var map_cell = map_data.get_cell(probe)
			if map_cell != null and not bool(map_cell.walkable):
				blocked_count += 1
	return blocked_count > max_local_density


func _would_create_solid_square(map_data, cell: Vector2i, cluster: Array[Vector2i]) -> bool:
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
		var blocked_cells: int = 0
		for dy in range(2):
			for dx in range(2):
				var probe: Vector2i = cell + offset + Vector2i(dx, dy)
				if probe == cell or cluster.has(probe):
					blocked_cells += 1
					continue
				var map_cell = map_data.get_cell(probe)
				if map_cell != null and not bool(map_cell.walkable):
					blocked_cells += 1
		if blocked_cells >= 4:
			return true
	return false


func _clear_poi_approach_areas(map_data, config) -> void:
	_clear_radius_to_forest(map_data, map_data.player_spawn, int(config.spawn_clear_radius))
	_clear_radius_to_forest(map_data, map_data.tavern_cell, int(config.tavern_clear_radius))
	for cell in map_data.challenge_cells:
		_clear_radius_to_forest(map_data, cell, int(config.challenge_clear_radius))
	for cell in map_data.chest_cells:
		_clear_radius_to_forest(map_data, cell, int(config.poi_clear_radius))
	for cell in map_data.ruin_cells:
		_clear_radius_to_forest(map_data, cell, int(config.poi_clear_radius))
	for cell in map_data.easter_egg_cells:
		_clear_radius_to_forest(map_data, cell, int(config.poi_clear_radius))
	for cell in map_data.shrine_cells:
		_clear_radius_to_forest(map_data, cell, int(config.poi_clear_radius))


func _clear_radius_to_forest(map_data, center: Vector2i, radius: int) -> void:
	if center == Vector2i(-1, -1):
		return
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if not map_data.is_in_bounds(cell):
				continue
			var map_cell = map_data.get_cell(cell)
			if map_cell == null:
				continue
			if int(map_cell.terrain_type) == MapCellScript.TerrainType.TREE:
				map_data.set_terrain(cell, MapCellScript.TerrainType.FOREST)


func _get_forest_floor_cells(map_data) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in map_data.get_all_cells():
		if _is_forest_floor(map_data, cell):
			result.append(cell)
	return result


func _is_forest_floor(map_data, cell: Vector2i) -> bool:
	var map_cell = map_data.get_cell(cell)
	return map_cell != null and int(map_cell.terrain_type) == MapCellScript.TerrainType.FOREST
