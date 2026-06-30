extends SceneTree

const WorldGeneratorScript := preload("res://scripts/core/WorldGenerator.gd")
const MapDataScript := preload("res://scripts/core/MapData.gd")
const MapGenConfigScript := preload("res://scripts/core/MapGenConfig.gd")
const MapCellScript := preload("res://scripts/core/MapCell.gd")

const SIZE_PRESETS := [
	Vector2i(80, 80),
	Vector2i(128, 128),
	Vector2i(256, 256),
]

const SAMPLE_SEEDS := [
	"world_slice_demo",
]

const WINDOW_SIZE_SMALL := 41
const WINDOW_SIZE_LARGE := 31
const WINDOW_SIZE_MINOR := 21
const SHOW_FULL_MAP := false


func _init() -> void:
	var generator = WorldGeneratorScript.new()
	print("Legend: @ player, T tavern, C challenge, $ chest, U ruin, E egg, . plain, F forest floor, t tree block, ^ hill, M mountain, P peak, S swamp, D desert, R river, = bridge, + carved/debug pass overlay")
	print("")

	for map_size in SIZE_PRESETS:
		print("######## MAP SIZE %s ########" % str(map_size))
		for seed in SAMPLE_SEEDS:
			var cfg = MapGenConfigScript.new()
			cfg.map_size = map_size
			var map_data = generator.generate_world("%s_%dx%d" % [seed, map_size.x, map_size.y], cfg)
			_print_map_block(map_data)
		print("")

	quit()


func _print_map_block(map_data) -> void:
	print("=== Seed: %s ===" % String(map_data.seed))
	var terrain_counts: Dictionary = map_data.get_terrain_counts()
	var building_counts: Dictionary = map_data.get_building_count_by_type()
	var pass_stats: Dictionary = _collect_pass_stats(map_data)
	var forest_floor: int = int(terrain_counts.get("forest", 0))
	var tree_blocks: int = int(terrain_counts.get("tree", 0))
	var forest_biome_total: int = forest_floor + tree_blocks
	var total_cells: int = max(1, map_data.width * map_data.height)
	var walkable_count: int = _count_walkable(map_data)
	var blocked_count: int = total_cells - walkable_count
	var mountain_block_cells: int = int(terrain_counts.get("mountain", 0)) + int(terrain_counts.get("peak", 0))
	print("summary: size=%s walkable=%d/%d blocked=%d (%.2f%%) reachable=%d (%.2f%%) unreachable_poi=%d" % [
		str(map_data.get_size()),
		walkable_count,
		total_cells,
		blocked_count,
		(float(blocked_count) / float(total_cells)) * 100.0,
		int(map_data.reachable_count),
		(float(map_data.reachable_count) / float(max(1, walkable_count))) * 100.0,
		int(map_data.unreachable_poi_count),
	])
	print("terrain: plain=%d forest=%d tree=%d hill=%d mountain=%d peak=%d water=%d river=%d bridge=%d swamp=%d desert=%d" % [
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
	print("terrain_stats: mountain_blocked_ratio=%.2f%% forest_blocker_density=%.2f%% total_blocked_ratio=%.2f%%" % [
		(float(mountain_block_cells) / float(total_cells)) * 100.0,
		(float(tree_blocks) / float(max(1, forest_biome_total))) * 100.0,
		(float(blocked_count) / float(total_cells)) * 100.0,
	])
	print("pass_stats: count=%d avg_width=%.2f min_width=%d max_width=%d avg_path_len=%.1f local_gap_clears=%d" % [
		int(pass_stats.get("count", 0)),
		float(pass_stats.get("avg_width", 0.0)),
		int(pass_stats.get("min_width", 0)),
		int(pass_stats.get("max_width", 0)),
		float(pass_stats.get("avg_path_len", 0.0)),
		int(map_data.connectivity_report.get("local_gap_clears", []).size()),
	])
	print("generation: total=%.2fms | %s" % [
		float(map_data.generation_total_ms),
		_generation_breakdown_text(map_data.generation_breakdown_ms),
	])
	print("buildings: tavern=%d challenge=%d ruin=%d chest=%d egg=%d shrine=%d | stamp_success=%d stamp_failure=%d" % [
		int(building_counts.get("tavern", 0)),
		int(building_counts.get("challenge_entrance", 0)),
		int(building_counts.get("ruin", 0)),
		int(building_counts.get("chest", 0)),
		int(building_counts.get("easter_egg", 0)),
		int(building_counts.get("shrine", 0)),
		int(map_data.stamp_success_count),
		int(map_data.stamp_failure_count),
	])
	print("challenge_present=%s" % ("yes" if int(building_counts.get("challenge_entrance", 0)) > 0 else "no"))
	print("poi: spawn=%s tavern=%s challenge=%s chest=%s ruin=%s egg=%s shrine=%s" % [
		str(map_data.player_spawn),
		str(map_data.tavern_cell),
		str(map_data.challenge_cells),
		str(map_data.chest_cells),
		str(map_data.ruin_cells),
		str(map_data.easter_egg_cells),
		str(map_data.shrine_cells),
	])
	print("poi_distances: spawn->tavern=%s spawn->challenge=%s spawn->ruin=%s spawn->egg=%s" % [
		_path_length_text(map_data, map_data.player_spawn, map_data.tavern_cell),
		_path_length_text(map_data, map_data.player_spawn, _first_or_invalid(map_data.challenge_cells)),
		_path_length_text(map_data, map_data.player_spawn, _first_or_invalid(map_data.ruin_cells)),
		_path_length_text(map_data, map_data.player_spawn, _first_or_invalid(map_data.easter_egg_cells)),
	])
	_print_failure_summary(map_data)
	_print_building_records(map_data)

	if SHOW_FULL_MAP and map_data.width <= 80 and map_data.height <= 80:
		print("-- full map --")
		for line in _render_window(map_data, Rect2i(Vector2i.ZERO, map_data.get_size())):
			print(line)
	else:
		_print_focus_window(map_data, "spawn", map_data.player_spawn, WINDOW_SIZE_SMALL if map_data.width <= 80 else WINDOW_SIZE_LARGE)
		_print_poi_windows(map_data)
	print("")


func _print_focus_window(map_data, label: String, center: Vector2i, size: int) -> void:
	if center == MapDataScript.INVALID_CELL:
		print("-- %s window: none --" % label)
		return
	var window := _window_rect_around(map_data, center, size)
	print("-- %s window center=%s rect=%s --" % [label, str(center), str(window)])
	for line in _render_window(map_data, window):
		print(line)


func _window_rect_around(map_data, center: Vector2i, size: int) -> Rect2i:
	var width: int = mini(size, map_data.width)
	var height: int = mini(size, map_data.height)
	var half_w: int = int(width / 2)
	var half_h: int = int(height / 2)
	var origin := Vector2i(
		clampi(center.x - half_w, 0, max(0, map_data.width - width)),
		clampi(center.y - half_h, 0, max(0, map_data.height - height))
	)
	return Rect2i(origin, Vector2i(width, height))


func _render_window(map_data, rect: Rect2i) -> Array[String]:
	var lines: Array[String] = []
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		var chars: PackedStringArray = []
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)
			chars.append(_render_cell_char(map_data, cell))
		lines.append("".join(chars))
	return lines


func _render_cell_char(map_data, cell: Vector2i) -> String:
	if cell == map_data.player_spawn:
		return "@"

	var map_cell = map_data.get_cell(cell)
	if map_cell == null:
		return "?"
	if not String(map_cell.display_symbol_override).is_empty():
		return String(map_cell.display_symbol_override)
	if map_cell.tags.has("mountain_pass") and int(map_cell.terrain_type) != int(MapCellScript.TerrainType.BRIDGE):
		return "+"
	return String(map_cell.terrain_symbol())


func _count_walkable(map_data) -> int:
	var count: int = 0
	for cell in map_data.get_all_cells():
		if map_data.is_walkable(cell):
			count += 1
	return count


func _path_length_text(map_data, from_cell: Vector2i, to_cell: Vector2i) -> String:
	var path_length: int = _shortest_path_length(map_data, from_cell, to_cell)
	return str(path_length) if path_length >= 0 else "unreachable"


func _shortest_path_length(map_data, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if map_data == null or not map_data.is_walkable(from_cell) or not map_data.is_walkable(to_cell):
		return -1
	if from_cell == to_cell:
		return 0

	var queue: Array[Vector2i] = [from_cell]
	var visited: Dictionary = {from_cell: 0}
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	var queue_index: int = 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		var distance: int = int(visited[current])
		for dir in directions:
			var next: Vector2i = current + dir
			if visited.has(next) or not map_data.is_walkable(next):
				continue
			if next == to_cell:
				return distance + 1
			visited[next] = distance + 1
			queue.append(next)
	return -1


func _first_or_invalid(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return MapDataScript.INVALID_CELL
	return cells[0]


func _collect_pass_stats(map_data) -> Dictionary:
	var carved_passes: Array = map_data.connectivity_report.get("carved_passes", [])
	if carved_passes.is_empty():
		return {"count": 0, "avg_width": 0.0, "min_width": 0, "max_width": 0, "avg_path_len": 0.0}

	var width_sum: float = 0.0
	var path_len_sum: float = 0.0
	var min_width: int = 9999
	var max_width: int = 0
	for pass_data in carved_passes:
		var avg_width: float = float(pass_data.get("avg_width", pass_data.get("width", 0)))
		var pass_min: int = int(pass_data.get("min_width", int(round(avg_width))))
		var pass_max: int = int(pass_data.get("max_width", int(round(avg_width))))
		width_sum += avg_width
		path_len_sum += float(pass_data.get("path_len", 0))
		min_width = mini(min_width, pass_min)
		max_width = maxi(max_width, pass_max)

	return {
		"count": carved_passes.size(),
		"avg_width": width_sum / float(max(1, carved_passes.size())),
		"min_width": min_width if min_width != 9999 else 0,
		"max_width": max_width,
		"avg_path_len": path_len_sum / float(max(1, carved_passes.size())),
	}


func _generation_breakdown_text(breakdown: Dictionary) -> String:
	if breakdown == null or breakdown.is_empty():
		return "-"
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
		if breakdown.has(key):
			parts.append("%s=%.2fms" % [String(key).trim_suffix("_ms"), float(breakdown[key])])
	return ", ".join(parts)


func _print_building_records(map_data) -> void:
	var records: Array[Dictionary] = map_data.get_poi_records()
	if records.is_empty():
		print("building_records: none")
		return
	print("building_records:")
	for record in records:
		var interaction_cell: Vector2i = Vector2i(record.get("interaction_cell", MapDataScript.INVALID_CELL))
		var reachable: String = "yes" if _shortest_path_length(map_data, map_data.player_spawn, interaction_cell) >= 0 else "no"
		print("  - %s pattern=%s origin=%s size=%s interaction=%s entrances=%s occupied=%d reachable=%s" % [
			String(record.get("type", "")),
			String(record.get("pattern_id", "")),
			str(record.get("origin", Vector2i.ZERO)),
			str(record.get("size", Vector2i.ZERO)),
			str(interaction_cell),
			str(record.get("entrance_cells", [])),
			Array(record.get("occupied_cells", [])).size(),
			reachable,
		])


func _print_poi_windows(map_data) -> void:
	var records: Array[Dictionary] = map_data.get_poi_records()
	for record in records:
		var poi_type: String = String(record.get("type", ""))
		var center: Vector2i = Vector2i(record.get("interaction_cell", MapDataScript.INVALID_CELL))
		var window_size: int = WINDOW_SIZE_LARGE if poi_type in ["tavern", "challenge_entrance", "ruin"] else WINDOW_SIZE_MINOR
		print("-- %s pattern=%s interaction=%s origin=%s entrances=%s --" % [
			poi_type,
			String(record.get("pattern_id", "")),
			str(center),
			str(record.get("origin", Vector2i.ZERO)),
			str(record.get("entrance_cells", [])),
		])
		var window := _window_rect_around(map_data, center, window_size)
		for line in _render_window(map_data, window):
			print(line)


func _print_failure_summary(map_data) -> void:
	var summary: Dictionary = map_data.get_building_failure_summary()
	if summary.is_empty():
		print("building_failure_summary: none")
		return
	print("building_failure_summary:")
	for poi_type in summary.keys():
		var bucket: Dictionary = summary.get(poi_type, {})
		var top_parts: Array[String] = []
		var reasons: Dictionary = bucket.get("reasons", {})
		var pairs: Array[Dictionary] = []
		for reason in reasons.keys():
			pairs.append({"reason": String(reason), "count": int(reasons.get(reason, 0))})
		pairs.sort_custom(func(a, b): return int(a.get("count", 0)) > int(b.get("count", 0)))
		for pair in pairs.slice(0, mini(5, pairs.size())):
			top_parts.append("%s=%d" % [String(pair.get("reason", "")), int(pair.get("count", 0))])
		var last_failure: Dictionary = bucket.get("last_failure", {})
		print("  - %s attempts=%d top=[%s] fallback=%s last_origins=%s" % [
			String(poi_type),
			int(bucket.get("attempts", 0)),
			", ".join(top_parts),
			str(bool(last_failure.get("fallback_ran", false))),
			str(last_failure.get("last_attempted_origins", [])),
		])
