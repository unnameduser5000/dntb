class_name ConnectivityService
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")
const CARDINAL_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func flood_fill_walkable(map_data, start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	var snapshot: Dictionary = _build_reachable_snapshot(map_data, start)
	var visited_mask: PackedByteArray = PackedByteArray(snapshot.get("mask", PackedByteArray()))
	if map_data == null or visited_mask.is_empty():
		return visited
	for index in range(visited_mask.size()):
		if visited_mask[index] == 0:
			continue
		visited[_index_to_cell(index, map_data.width)] = true
	return visited


func is_reachable(map_data, from: Vector2i, to: Vector2i) -> bool:
	return flood_fill_walkable(map_data, from).has(to)


func ensure_core_pois_reachable(map_data, config = null, rng: RandomNumberGenerator = null) -> Dictionary:
	var report: Dictionary = {
		"carved_passes": [],
		"stitched_regions": [],
		"bonus_passes": [],
		"local_gap_clears": [],
		"failed_pois": [],
	}
	if map_data == null:
		return report
	if not map_data.is_walkable(map_data.player_spawn):
		map_data.connectivity_report = report.duplicate(true)
		return report

	_rescue_unreachable_pois(map_data, report, config, rng)
	_stitch_all_secondary_regions(map_data, report, config, rng)
	_add_bonus_shortcuts(map_data, report, config, rng)

	var final_walkable_mask: PackedByteArray = _build_walkable_mask(map_data)
	var final_reachable: Dictionary = _build_reachable_snapshot(map_data, map_data.player_spawn, final_walkable_mask)
	var final_reachable_mask: PackedByteArray = PackedByteArray(final_reachable.get("mask", PackedByteArray()))
	report["failed_pois"] = find_unreachable_pois(map_data, final_reachable_mask)
	map_data.carved_pass_count = report["carved_passes"].size()
	map_data.reachable_count = int(final_reachable.get("count", 0))
	map_data.unreachable_poi_count = report["failed_pois"].size()
	map_data.connectivity_report = report.duplicate(true)
	return report


func summarize(map_data) -> void:
	if map_data == null:
		return
	var walkable_mask: PackedByteArray = _build_walkable_mask(map_data)
	var reachable: Dictionary = _build_reachable_snapshot(map_data, map_data.player_spawn, walkable_mask)
	var reachable_mask: PackedByteArray = PackedByteArray(reachable.get("mask", PackedByteArray()))
	map_data.reachable_count = int(reachable.get("count", 0))
	map_data.unreachable_poi_count = find_unreachable_pois(map_data, reachable_mask).size()


func find_unreachable_pois(map_data, reachable_mask: PackedByteArray = PackedByteArray()) -> Array:
	var result: Array = []
	if map_data == null or not map_data.is_walkable(map_data.player_spawn):
		return result

	var mask: PackedByteArray = reachable_mask
	if mask.size() != map_data.width * map_data.height:
		var walkable_mask: PackedByteArray = _build_walkable_mask(map_data)
		var reachable: Dictionary = _build_reachable_snapshot(map_data, map_data.player_spawn, walkable_mask)
		mask = PackedByteArray(reachable.get("mask", PackedByteArray()))
	for entry in map_data.get_all_poi_entries():
		var kind: String = String(entry.get("kind", ""))
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
		if kind == "player_spawn" or cell == Vector2i(-1, -1):
			continue
		if not _mask_has_cell(mask, map_data.width, map_data.height, cell):
			result.append({"kind": kind, "cell": cell})
	return result


func carve_pass_between_regions(map_data, from_cell: Vector2i, to_cell: Vector2i, config = null, rng: RandomNumberGenerator = null) -> bool:
	return not _carve_pass_between_regions(map_data, from_cell, to_cell, config, rng).is_empty()


func _rescue_unreachable_pois(map_data, report: Dictionary, config = null, rng: RandomNumberGenerator = null) -> void:
	var max_attempts: int = 3
	for _attempt in range(max_attempts):
		var walkable_mask: PackedByteArray = _build_walkable_mask(map_data)
		var reachable: Dictionary = _build_reachable_snapshot(map_data, map_data.player_spawn, walkable_mask)
		var reachable_mask: PackedByteArray = PackedByteArray(reachable.get("mask", PackedByteArray()))
		var unreachable: Array = find_unreachable_pois(map_data, reachable_mask)
		if unreachable.is_empty():
			return

		var carved_any: bool = false
		for entry in unreachable:
			var poi_cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
			var anchor: Vector2i = _find_nearest_reachable_cell_in_mask(reachable_mask, map_data.width, map_data.height, poi_cell)
			if anchor == Vector2i(-1, -1):
				continue
			var record := _carve_pass_between_regions(map_data, anchor, poi_cell, config, rng)
			if record.is_empty():
				continue
			record["poi_kind"] = String(entry.get("kind", ""))
			record["reason"] = "poi_rescue"
			report["carved_passes"].append(record)
			carved_any = true
		if not carved_any:
			return


func _stitch_all_secondary_regions(map_data, report: Dictionary, config = null, rng: RandomNumberGenerator = null) -> void:
	var pass_budget: int = maxi(1, int(config.extra_region_connection_budget) if config != null else 4)
	var local_region_limit: int = int(config.local_gap_region_max_cells) if config != null else 24
	var local_gap_max_distance: int = int(config.local_gap_max_distance) if config != null else 6
	for _iteration in range(4):
		var walkable_mask: PackedByteArray = _build_walkable_mask(map_data)
		var regions: Array = _collect_walkable_regions_fast(map_data, walkable_mask)
		if regions.size() <= 1:
			return

		var main_region: Dictionary = _pick_main_region_fast(regions)
		if main_region.is_empty():
			return
		var main_region_id: int = int(main_region.get("id", -1))
		var main_edges: Array = _sample_cells(Array(main_region.get("edge_cells", [])), 192)
		var changed: bool = false
		var used_budget: int = 0
		var secondary_regions: Array[Dictionary] = []
		for region in regions:
			if int(region.get("id", -1)) == main_region_id:
				continue
			secondary_regions.append(region)
		secondary_regions.sort_custom(func(a, b): return int(a.get("size", 0)) < int(b.get("size", 0)))
		var connection_budget: int = mini(64, maxi(pass_budget, secondary_regions.size()))
		for region in secondary_regions:
			if used_budget >= connection_budget:
				break
			var target_edges: Array = _sample_cells(Array(region.get("edge_cells", [])), 128)
			var bridge := _find_best_region_bridge_sampled(main_edges, target_edges)
			if bridge.is_empty():
				continue

			var from_cell: Vector2i = Vector2i(bridge.get("from", Vector2i(-1, -1)))
			var to_cell: Vector2i = Vector2i(bridge.get("to", Vector2i(-1, -1)))
			var path := _cardinal_corridor(from_cell, to_cell, _pick_horizontal_first(from_cell, to_cell, rng))
			var blocked_profile: Dictionary = _count_blocked_profile_on_path(map_data, path)
			var region_size: int = int(region.get("size", 0))
			if region_size <= local_region_limit and path.size() <= local_gap_max_distance + 1:
				if int(blocked_profile.get("mountain_like", 0)) == 0 and int(blocked_profile.get("water_like", 0)) == 0:
					if _clear_local_tree_gap(map_data, path):
						report["local_gap_clears"].append({
							"from": from_cell,
							"to": to_cell,
							"path_len": path.size(),
							"region_size": region_size,
						})
						changed = true
						used_budget += 1
						main_edges.append_array(target_edges)
						continue

			var record := _carve_pass_between_regions(map_data, from_cell, to_cell, config, rng)
			if record.is_empty():
				continue
			record["reason"] = "region_stitch"
			record["region_size"] = region_size
			report["carved_passes"].append(record)
			report["stitched_regions"].append(record.duplicate(true))
			main_edges.append_array(target_edges)
			changed = true
			used_budget += 1

		if not changed:
			return


func _stitch_secondary_regions(map_data, report: Dictionary, config = null, rng: RandomNumberGenerator = null) -> void:
	var budget: int = int(config.extra_region_connection_budget) if config != null else 3
	var min_region_cells: int = int(config.secondary_region_min_cells) if config != null else 6
	var area_scaled_budget: int = maxi(0, int(ceil(float(max(1, map_data.width * map_data.height)) / 2048.0)))
	for _attempt in range(maxi(budget, area_scaled_budget)):
		var regions: Array = _collect_walkable_regions(map_data)
		if regions.size() <= 1:
			return

		var main_region: Dictionary = _pick_main_region(regions, map_data.player_spawn)
		if main_region.is_empty():
			return

		var target_region: Dictionary = _pick_largest_secondary_region(regions, int(main_region.get("id", -1)), min_region_cells)
		if target_region.is_empty():
			return

		var bridge := _find_best_region_bridge(map_data, Array(main_region.get("cells", [])), Array(target_region.get("cells", [])))
		if bridge.is_empty():
			return

		var record := _carve_pass_between_regions(
			map_data,
			Vector2i(bridge.get("from", Vector2i(-1, -1))),
			Vector2i(bridge.get("to", Vector2i(-1, -1))),
			config,
			rng
		)
		if record.is_empty():
			return
		record["reason"] = "region_stitch"
		record["region_size"] = int(target_region.get("size", 0))
		report["carved_passes"].append(record)
		report["stitched_regions"].append(record.duplicate(true))


func _resolve_remaining_regions_with_local_gaps(map_data, report: Dictionary, config = null, rng: RandomNumberGenerator = null) -> void:
	var local_region_limit: int = int(config.local_gap_region_max_cells) if config != null else 24
	var local_gap_max_distance: int = int(config.local_gap_max_distance) if config != null else 6
	var base_attempt_budget: int = maxi(6, int(config.extra_region_connection_budget) if config != null else 4) + 12
	var area_scaled_attempt_budget: int = maxi(24, int(ceil(float(max(1, map_data.width * map_data.height)) / 1024.0)))
	var attempt_budget: int = maxi(base_attempt_budget, area_scaled_attempt_budget)
	for _attempt in range(attempt_budget):
		var regions: Array = _collect_walkable_regions(map_data)
		if regions.size() <= 1:
			return

		var main_region: Dictionary = _pick_main_region(regions, map_data.player_spawn)
		if main_region.is_empty():
			return

		var target_region: Dictionary = _pick_largest_secondary_region(regions, int(main_region.get("id", -1)), 1)
		if target_region.is_empty():
			return

		var bridge := _find_best_region_bridge(map_data, Array(main_region.get("cells", [])), Array(target_region.get("cells", [])))
		if bridge.is_empty():
			return

		var from_cell: Vector2i = Vector2i(bridge.get("from", Vector2i(-1, -1)))
		var to_cell: Vector2i = Vector2i(bridge.get("to", Vector2i(-1, -1)))
		var path := _cardinal_corridor(from_cell, to_cell, _pick_horizontal_first(from_cell, to_cell, rng))
		var blocked_profile: Dictionary = _count_blocked_profile_on_path(map_data, path)
		if int(target_region.get("size", 0)) <= local_region_limit and path.size() <= local_gap_max_distance + 1:
			if int(blocked_profile.get("mountain_like", 0)) == 0 and int(blocked_profile.get("water_like", 0)) == 0:
				if _clear_local_tree_gap(map_data, path):
					report["local_gap_clears"].append({
						"from": from_cell,
						"to": to_cell,
						"path_len": path.size(),
						"region_size": int(target_region.get("size", 0)),
					})
					continue

		var record := _carve_pass_between_regions(map_data, from_cell, to_cell, config, rng)
		if record.is_empty():
			return
		record["reason"] = "final_stitch"
		record["region_size"] = int(target_region.get("size", 0))
		report["carved_passes"].append(record)
		report["stitched_regions"].append(record.duplicate(true))


func _add_bonus_shortcuts(map_data, report: Dictionary, config = null, rng: RandomNumberGenerator = null) -> void:
	var budget: int = int(config.bonus_shortcut_passes) if config != null else 1
	if budget <= 0:
		return

	var min_blocked_cells: int = int(config.shortcut_min_blocked_cells) if config != null else 3
	var pairs: Array = _build_shortcut_pairs(map_data)
	var created: int = 0
	for pair in pairs:
		if created >= budget:
			return
		var from_cell: Vector2i = Vector2i(pair.get("from", Vector2i(-1, -1)))
		var to_cell: Vector2i = Vector2i(pair.get("to", Vector2i(-1, -1)))
		if from_cell == Vector2i(-1, -1) or to_cell == Vector2i(-1, -1):
			continue
		var direct_path := _cardinal_corridor(from_cell, to_cell, _pick_horizontal_first(from_cell, to_cell, rng))
		if _count_blocked_cells_on_path(map_data, direct_path) < min_blocked_cells:
			continue
		var record := _carve_pass_between_regions(map_data, from_cell, to_cell, config, rng)
		if record.is_empty():
			continue
		record["reason"] = "shortcut"
		report["carved_passes"].append(record)
		report["bonus_passes"].append(record.duplicate(true))
		created += 1


func _carve_pass_between_regions(map_data, from_cell: Vector2i, to_cell: Vector2i, config = null, rng: RandomNumberGenerator = null) -> Dictionary:
	if map_data == null or not map_data.is_in_bounds(from_cell) or not map_data.is_in_bounds(to_cell):
		return {}

	var path := _cardinal_corridor(from_cell, to_cell, _pick_horizontal_first(from_cell, to_cell, rng))
	if path.is_empty():
		return {}

	var base_width: int = _pick_base_pass_width(config, rng)
	var max_width: int = _pick_max_pass_width(config, base_width)
	var changed: bool = false
	var tagged_cells: Dictionary = {}
	var width_sum: int = 0
	var min_width: int = max_width
	var sampled_max_width: int = base_width
	for index in range(path.size()):
		var width: int = _pick_width_for_step(index, path.size(), base_width, max_width, config, rng)
		width_sum += width
		min_width = mini(min_width, width)
		sampled_max_width = maxi(sampled_max_width, width)
		for carve_cell in _expanded_pass_cells(map_data, path[index], width):
			tagged_cells[carve_cell] = true
			if _carve_pass_cell(map_data, carve_cell):
				changed = true

	if not changed:
		return {}

	for cell in tagged_cells.keys():
		_add_pass_tag(map_data, cell)

	return {
		"from": from_cell,
		"to": to_cell,
		"width": base_width,
		"min_width": min_width,
		"max_width": sampled_max_width,
		"avg_width": float(width_sum) / float(maxi(1, path.size())),
		"path_len": path.size(),
	}


func _find_nearest_reachable_cell_in_mask(reachable_mask: PackedByteArray, width: int, height: int, target: Vector2i) -> Vector2i:
	if _mask_has_cell(reachable_mask, width, height, target):
		return target
	var max_radius: int = 32
	for radius in range(1, max_radius + 1):
		for x in range(target.x - radius, target.x + radius + 1):
			var top := Vector2i(x, target.y - radius)
			if _mask_has_cell(reachable_mask, width, height, top):
				return top
			var bottom := Vector2i(x, target.y + radius)
			if _mask_has_cell(reachable_mask, width, height, bottom):
				return bottom
		for y in range(target.y - radius + 1, target.y + radius):
			var left := Vector2i(target.x - radius, y)
			if _mask_has_cell(reachable_mask, width, height, left):
				return left
			var right := Vector2i(target.x + radius, y)
			if _mask_has_cell(reachable_mask, width, height, right):
				return right
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for index in range(reachable_mask.size()):
		if reachable_mask[index] == 0:
			continue
		var cell: Vector2i = _index_to_cell(index, width)
		var distance: float = float(cell.distance_squared_to(target))
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _add_pass_tag(map_data, cell: Vector2i) -> void:
	var map_cell = map_data.get_or_create_cell(cell)
	if map_cell == null:
		return
	if not map_cell.tags.has("mountain_pass"):
		map_cell.tags.append("mountain_pass")


func _cardinal_corridor(from_cell: Vector2i, to_cell: Vector2i, horizontal_first: bool = true) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var current: Vector2i = from_cell
	points.append(current)

	if horizontal_first:
		_walk_x(points, current, to_cell.x)
		current = points[points.size() - 1]
		_walk_y(points, current, to_cell.y)
	else:
		_walk_y(points, current, to_cell.y)
		current = points[points.size() - 1]
		_walk_x(points, current, to_cell.x)

	return points


func _walk_x(points: Array[Vector2i], start: Vector2i, target_x: int) -> void:
	var current: Vector2i = start
	var step_x: int = 1 if target_x > current.x else -1
	while current.x != target_x:
		current = Vector2i(current.x + step_x, current.y)
		points.append(current)


func _walk_y(points: Array[Vector2i], start: Vector2i, target_y: int) -> void:
	var current: Vector2i = start
	var step_y: int = 1 if target_y > current.y else -1
	while current.y != target_y:
		current = Vector2i(current.x, current.y + step_y)
		points.append(current)


func _pick_horizontal_first(from_cell: Vector2i, to_cell: Vector2i, rng: RandomNumberGenerator = null) -> bool:
	if from_cell.x == to_cell.x:
		return false
	if from_cell.y == to_cell.y:
		return true
	if rng == null:
		return absi(to_cell.x - from_cell.x) >= absi(to_cell.y - from_cell.y)
	return rng.randf() < 0.5


func _pick_base_pass_width(config, rng: RandomNumberGenerator = null) -> int:
	var min_width: int = maxi(1, int(config.pass_width_min) if config != null else 1)
	var max_width: int = maxi(min_width, int(config.pass_width_max) if config != null else 2)
	if rng == null or min_width == max_width:
		return min_width
	return rng.randi_range(min_width, max_width)


func _pick_max_pass_width(config, base_width: int) -> int:
	var configured_max: int = maxi(1, int(config.pass_width_max) if config != null else 2)
	return maxi(base_width, configured_max)


func _pick_width_for_step(index: int, path_size: int, base_width: int, max_width: int, config, rng: RandomNumberGenerator = null) -> int:
	if max_width <= base_width:
		return base_width
	var widen_chance: float = float(config.pass_widen_chance) if config != null else 0.35
	var near_join: bool = index <= 1 or index >= path_size - 2
	if near_join:
		return max_width
	if rng != null and rng.randf() < widen_chance:
		return max_width
	return base_width


func _expanded_pass_cells(map_data, center: Vector2i, width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var radius: int = maxi(1, int(floor(float(width) * 0.5)))
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if not map_data.is_in_bounds(cell):
				continue
			if absi(cell.x - center.x) + absi(cell.y - center.y) > radius:
				continue
			result.append(cell)
	return result


func _carve_pass_cell(map_data, cell: Vector2i) -> bool:
	if map_data == null or not map_data.is_in_bounds(cell):
		return false
	if map_data.is_walkable(cell):
		return false

	var map_cell = map_data.get_or_create_cell(cell)
	if map_cell == null:
		return false
	match int(map_cell.terrain_type):
		MapCellScript.TerrainType.TREE:
			map_data.set_terrain(cell, MapCellScript.TerrainType.FOREST)
		MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.WATER:
			map_data.set_terrain(cell, MapCellScript.TerrainType.BRIDGE)
		MapCellScript.TerrainType.PEAK, MapCellScript.TerrainType.MOUNTAIN:
			map_data.set_terrain(cell, MapCellScript.TerrainType.HILL)
		_:
			map_data.set_terrain(cell, MapCellScript.TerrainType.PLAIN)
	return true


func _collect_walkable_regions(map_data) -> Array:
	var seen: Dictionary = {}
	var regions: Array = []
	var next_region_id: int = 0
	for cell in map_data.get_all_cells():
		if seen.has(cell) or not map_data.is_walkable(cell):
			continue
		var region_cells := _collect_region_cells(map_data, cell, seen)
		regions.append({
			"id": next_region_id,
			"cells": region_cells,
			"size": region_cells.size(),
		})
		next_region_id += 1
	return regions


func _collect_walkable_regions_fast(map_data, walkable_mask: PackedByteArray = PackedByteArray()) -> Array:
	var regions: Array = []
	if map_data == null or map_data.width <= 0 or map_data.height <= 0:
		return regions
	var width: int = map_data.width
	var height: int = map_data.height
	var cell_count: int = width * height
	var walkable: PackedByteArray = walkable_mask
	if walkable.size() != cell_count:
		walkable = _build_walkable_mask(map_data)
	var visited := PackedByteArray()
	visited.resize(cell_count)
	var region_id: int = 0
	var spawn_index: int = _cell_to_index(map_data.player_spawn, width)
	for start_index in range(cell_count):
		if walkable[start_index] == 0 or visited[start_index] != 0:
			continue
		var queue: Array[int] = [start_index]
		visited[start_index] = 1
		var queue_index: int = 0
		var size: int = 0
		var contains_spawn: bool = start_index == spawn_index
		var edge_cells: Array[Vector2i] = []
		while queue_index < queue.size():
			var current_index: int = int(queue[queue_index])
			queue_index += 1
			size += 1
			if current_index == spawn_index:
				contains_spawn = true
			var current_x: int = current_index % width
			var current_y: int = int(current_index / width)
			var is_edge: bool = false
			if current_y <= 0:
				is_edge = true
			else:
				var up_index: int = current_index - width
				if walkable[up_index] == 0:
					is_edge = true
				elif visited[up_index] == 0:
					visited[up_index] = 1
					queue.append(up_index)
			if current_y >= height - 1:
				is_edge = true
			else:
				var down_index: int = current_index + width
				if walkable[down_index] == 0:
					is_edge = true
				elif visited[down_index] == 0:
					visited[down_index] = 1
					queue.append(down_index)
			if current_x <= 0:
				is_edge = true
			else:
				var left_index: int = current_index - 1
				if walkable[left_index] == 0:
					is_edge = true
				elif visited[left_index] == 0:
					visited[left_index] = 1
					queue.append(left_index)
			if current_x >= width - 1:
				is_edge = true
			else:
				var right_index: int = current_index + 1
				if walkable[right_index] == 0:
					is_edge = true
				elif visited[right_index] == 0:
					visited[right_index] = 1
					queue.append(right_index)
			if is_edge:
				edge_cells.append(Vector2i(current_x, current_y))
		regions.append({
			"id": region_id,
			"size": size,
			"contains_spawn": contains_spawn,
			"edge_cells": edge_cells,
		})
		region_id += 1
	return regions


func _collect_region_cells(map_data, start: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var queue_index: int = 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		cells.append(current)
		for dir in CARDINAL_DIRS:
			var next: Vector2i = current + dir
			if seen.has(next) or not map_data.is_walkable(next):
				continue
			seen[next] = true
			queue.append(next)
	return cells


func _pick_main_region(regions: Array, player_spawn: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_size: int = -1
	for region in regions:
		var cells: Array = region.get("cells", [])
		if cells.has(player_spawn):
			return region
		var size: int = int(region.get("size", 0))
		if size > best_size:
			best = region
			best_size = size
	return best


func _pick_main_region_fast(regions: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_size: int = -1
	for region in regions:
		if bool(region.get("contains_spawn", false)):
			return region
		var size: int = int(region.get("size", 0))
		if size > best_size:
			best = region
			best_size = size
	return best


func _pick_largest_secondary_region(regions: Array, main_region_id: int, min_region_cells: int) -> Dictionary:
	var best: Dictionary = {}
	var best_size: int = -1
	for region in regions:
		if int(region.get("id", -1)) == main_region_id:
			continue
		var size: int = int(region.get("size", 0))
		if size < min_region_cells or size <= best_size:
			continue
		best = region
		best_size = size
	return best


func _find_best_region_bridge(map_data, from_cells: Array, to_cells: Array) -> Dictionary:
	var from_candidates := _filter_region_edge_cells(map_data, from_cells)
	var to_candidates := _filter_region_edge_cells(map_data, to_cells)
	if from_candidates.is_empty():
		from_candidates = from_cells.duplicate()
	if to_candidates.is_empty():
		to_candidates = to_cells.duplicate()

	var best_from: Vector2i = Vector2i(-1, -1)
	var best_to: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	for from_cell in from_candidates:
		for to_cell in to_candidates:
			var distance: int = absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)
			if distance < best_distance:
				best_distance = distance
				best_from = from_cell
				best_to = to_cell
	return {} if best_from == Vector2i(-1, -1) else {"from": best_from, "to": best_to}


func _find_best_region_bridge_sampled(from_cells: Array, to_cells: Array) -> Dictionary:
	if from_cells.is_empty() or to_cells.is_empty():
		return {}
	var best_from: Vector2i = Vector2i(-1, -1)
	var best_to: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1_000_000
	for from_value in from_cells:
		var from_cell := Vector2i(from_value)
		for to_value in to_cells:
			var to_cell := Vector2i(to_value)
			var distance: int = absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y)
			if distance < best_distance:
				best_distance = distance
				best_from = from_cell
				best_to = to_cell
	return {} if best_from == Vector2i(-1, -1) else {"from": best_from, "to": best_to}


func _filter_region_edge_cells(map_data, cells: Array) -> Array:
	var result: Array = []
	for cell_value in cells:
		var cell := Vector2i(cell_value)
		for dir in CARDINAL_DIRS:
			if not map_data.is_walkable(cell + dir):
				result.append(cell)
				break
	return result


func _build_shortcut_pairs(map_data) -> Array:
	var anchors: Array[Vector2i] = map_data.get_all_poi_cells()
	var pairs: Array = []
	for from_index in range(anchors.size()):
		for to_index in range(from_index + 1, anchors.size()):
			var from_cell: Vector2i = anchors[from_index]
			var to_cell: Vector2i = anchors[to_index]
			if not map_data.is_walkable(from_cell) or not map_data.is_walkable(to_cell):
				continue
			pairs.append({
				"from": from_cell,
				"to": to_cell,
				"distance": absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y),
			})
	pairs.sort_custom(func(a, b): return int(a.get("distance", 0)) > int(b.get("distance", 0)))
	return pairs


func _count_blocked_cells_on_path(map_data, path: Array[Vector2i]) -> int:
	var blocked_count: int = 0
	for cell in path:
		if not map_data.is_walkable(cell):
			blocked_count += 1
	return blocked_count


func _count_blocked_profile_on_path(map_data, path: Array[Vector2i]) -> Dictionary:
	var profile: Dictionary = {
		"tree": 0,
		"mountain_like": 0,
		"water_like": 0,
		"other_blocked": 0,
	}
	for cell in path:
		var map_cell = map_data.get_cell(cell)
		if map_cell == null or bool(map_cell.walkable):
			continue
		match int(map_cell.terrain_type):
			MapCellScript.TerrainType.TREE:
				profile["tree"] = int(profile["tree"]) + 1
			MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK:
				profile["mountain_like"] = int(profile["mountain_like"]) + 1
			MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER:
				profile["water_like"] = int(profile["water_like"]) + 1
			_:
				profile["other_blocked"] = int(profile["other_blocked"]) + 1
	return profile


func _clear_local_tree_gap(map_data, path: Array[Vector2i]) -> bool:
	var changed: bool = false
	for cell in path:
		changed = _clear_tree_blocker(map_data, cell) or changed
		for dir in CARDINAL_DIRS:
			changed = _clear_tree_blocker(map_data, cell + dir) or changed
	return changed


func _clear_tree_blocker(map_data, cell: Vector2i) -> bool:
	if map_data == null or not map_data.is_in_bounds(cell):
		return false
	var map_cell = map_data.get_cell(cell)
	if map_cell == null or int(map_cell.terrain_type) != MapCellScript.TerrainType.TREE:
		return false
	map_data.set_terrain(cell, MapCellScript.TerrainType.FOREST)
	return true


func _sample_cells(cells: Array, max_count: int) -> Array:
	if cells.size() <= max_count:
		return cells.duplicate()
	var result: Array = []
	var step: float = float(cells.size()) / float(max_count)
	for index in range(max_count):
		var picked_index: int = mini(cells.size() - 1, int(floor(float(index) * step)))
		result.append(cells[picked_index])
	return result


func _build_walkable_mask(map_data) -> PackedByteArray:
	var mask := PackedByteArray()
	if map_data == null or map_data.width <= 0 or map_data.height <= 0:
		return mask
	var width: int = map_data.width
	var height: int = map_data.height
	mask.resize(width * height)
	var index: int = 0
	for y in range(height):
		for x in range(width):
			var map_cell = map_data.get_cell(Vector2i(x, y))
			if map_cell != null and bool(map_cell.walkable):
				mask[index] = 1
			index += 1
	return mask


func _build_reachable_snapshot(map_data, start: Vector2i, walkable_mask: PackedByteArray = PackedByteArray()) -> Dictionary:
	var snapshot: Dictionary = {
		"mask": PackedByteArray(),
		"count": 0,
	}
	if map_data == null or map_data.width <= 0 or map_data.height <= 0:
		return snapshot
	if not map_data.is_in_bounds(start):
		return snapshot
	var width: int = map_data.width
	var height: int = map_data.height
	var cell_count: int = width * height
	var walkable: PackedByteArray = walkable_mask
	if walkable.size() != cell_count:
		walkable = _build_walkable_mask(map_data)
	var start_index: int = _cell_to_index(start, width)
	if start_index < 0 or start_index >= cell_count or walkable[start_index] == 0:
		return snapshot
	var visited := PackedByteArray()
	visited.resize(cell_count)
	var queue: Array[int] = [start_index]
	visited[start_index] = 1
	var queue_index: int = 0
	var reachable_count: int = 0
	while queue_index < queue.size():
		var current_index: int = int(queue[queue_index])
		queue_index += 1
		reachable_count += 1
		var current_x: int = current_index % width
		var current_y: int = int(current_index / width)
		if current_y > 0:
			var up_index: int = current_index - width
			if walkable[up_index] != 0 and visited[up_index] == 0:
				visited[up_index] = 1
				queue.append(up_index)
		if current_y < height - 1:
			var down_index: int = current_index + width
			if walkable[down_index] != 0 and visited[down_index] == 0:
				visited[down_index] = 1
				queue.append(down_index)
		if current_x > 0:
			var left_index: int = current_index - 1
			if walkable[left_index] != 0 and visited[left_index] == 0:
				visited[left_index] = 1
				queue.append(left_index)
		if current_x < width - 1:
			var right_index: int = current_index + 1
			if walkable[right_index] != 0 and visited[right_index] == 0:
				visited[right_index] = 1
				queue.append(right_index)
	snapshot["mask"] = visited
	snapshot["count"] = reachable_count
	return snapshot


func _mask_has_cell(mask: PackedByteArray, width: int, height: int, cell: Vector2i) -> bool:
	if mask.is_empty() or cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return mask[_cell_to_index(cell, width)] != 0


func _cell_to_index(cell: Vector2i, width: int) -> int:
	return cell.y * width + cell.x


func _index_to_cell(index: int, width: int) -> Vector2i:
	return Vector2i(index % width, int(index / width))


func _bresenham_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy

	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var err2: int = err * 2
		if err2 > -dy:
			err -= dy
			x0 += sx
		if err2 < dx:
			err += dx
			y0 += sy

	return points
