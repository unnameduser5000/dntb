class_name BuildingPlacementService
extends RefCounted

const BuildingPatternLibraryScript := preload("res://scripts/core/BuildingPatternLibrary.gd")
const PatternStampServiceScript := preload("res://scripts/core/PatternStampService.gd")
const ConnectivityServiceScript := preload("res://scripts/core/ConnectivityService.gd")
const MapCellScript := preload("res://scripts/core/MapCell.gd")

const POI_ORDER := [
	BuildingPatternLibraryScript.POI_TYPE_TAVERN,
	BuildingPatternLibraryScript.POI_TYPE_CHALLENGE,
	BuildingPatternLibraryScript.POI_TYPE_RUIN,
	BuildingPatternLibraryScript.POI_TYPE_CHEST,
	BuildingPatternLibraryScript.POI_TYPE_EGG,
	BuildingPatternLibraryScript.POI_TYPE_SHRINE,
]

const DEFAULT_STAGE_LOCAL := "anchor_local"
const DEFAULT_STAGE_EXPANDED := "anchor_expanded"
const DEFAULT_STAGE_GLOBAL := "global_reachable"
const STAGE_SCAN_BUDGET_MULTIPLIER_LOCAL := 2
const STAGE_SCAN_BUDGET_MULTIPLIER_GLOBAL := 3
const CANDIDATE_GRID_STRIDE_SMALL := 2
const CANDIDATE_GRID_STRIDE_MEDIUM := 4
const CANDIDATE_GRID_STRIDE_LARGE := 8
const CONTEXT_SAMPLE_LIMIT_GLOBAL_SMALL := 1024
const CONTEXT_SAMPLE_LIMIT_GLOBAL_MEDIUM := 2048
const CONTEXT_SAMPLE_LIMIT_GLOBAL_LARGE := 4096
const CONTEXT_SAMPLE_LIMIT_LOCAL_SMALL := 2048
const CONTEXT_SAMPLE_LIMIT_LOCAL_MEDIUM := 4096
const CONTEXT_SAMPLE_LIMIT_LOCAL_LARGE := 8192

var pattern_library = BuildingPatternLibraryScript.new()
var stamp_service = PatternStampServiceScript.new()
var connectivity_service = ConnectivityServiceScript.new()


func place_buildings(map_data, rng: RandomNumberGenerator, config = null, anchor_cells: Dictionary = {}) -> Dictionary:
	var report := {
		"success_count": 0,
		"failure_count": 0,
		"placements": [],
		"failures": [],
	}
	if map_data == null or rng == null:
		return report
	if map_data.player_spawn == Vector2i(-1, -1):
		return report

	var placement_rules := _build_placement_rules(map_data, config)
	var placement_context := _build_placement_context(map_data, rng)
	var resolved_anchors := {
		BuildingPatternLibraryScript.POI_TYPE_TAVERN: Vector2i(anchor_cells.get(BuildingPatternLibraryScript.POI_TYPE_TAVERN, map_data.tavern_cell)),
		BuildingPatternLibraryScript.POI_TYPE_CHALLENGE: Vector2i(anchor_cells.get(BuildingPatternLibraryScript.POI_TYPE_CHALLENGE, _first_or_invalid_cell(map_data.challenge_cells))),
		BuildingPatternLibraryScript.POI_TYPE_RUIN: Vector2i(anchor_cells.get(BuildingPatternLibraryScript.POI_TYPE_RUIN, _first_or_invalid_cell(map_data.ruin_cells))),
		BuildingPatternLibraryScript.POI_TYPE_CHEST: Vector2i(anchor_cells.get(BuildingPatternLibraryScript.POI_TYPE_CHEST, _first_or_invalid_cell(map_data.chest_cells))),
		BuildingPatternLibraryScript.POI_TYPE_EGG: Vector2i(anchor_cells.get(BuildingPatternLibraryScript.POI_TYPE_EGG, _first_or_invalid_cell(map_data.easter_egg_cells))),
		BuildingPatternLibraryScript.POI_TYPE_SHRINE: Vector2i(anchor_cells.get(BuildingPatternLibraryScript.POI_TYPE_SHRINE, _pick_shrine_anchor(map_data, placement_context))),
	}
	for poi_type in POI_ORDER:
		var target_count: int = int(placement_rules.get(poi_type, {}).get("count", 0))
		for _index in range(target_count):
			var result := _place_single_poi(
				map_data,
				poi_type,
				rng,
				placement_rules,
				Vector2i(resolved_anchors.get(poi_type, Vector2i(-1, -1))),
				placement_context
			)
			if bool(result.get("success", false)):
				report["success_count"] = int(report["success_count"]) + 1
				report["placements"].append(result)
				map_data.add_building_stamp_result(result)
			else:
				report["failure_count"] = int(report["failure_count"]) + 1
				report["failures"].append(result)
				map_data.add_building_stamp_result(result)

	return report


func _place_single_poi(map_data, poi_type: String, rng: RandomNumberGenerator, placement_rules: Dictionary, anchor_cell: Vector2i, placement_context: Dictionary) -> Dictionary:
	var patterns: Array[Dictionary] = pattern_library.get_patterns_for_type(poi_type)
	if patterns.is_empty():
		return {"success": false, "reason": "missing_pattern", "poi_type": poi_type}

	var rule: Dictionary = placement_rules.get(poi_type, {})
	var search_stages: Array[Dictionary] = _build_search_stages(poi_type, anchor_cell)
	var failure_counts: Dictionary = {}
	var last_attempted_origins: Array[Vector2i] = []
	var attempt_count: int = 0
	var fallback_ran: bool = false
	for stage_index in range(search_stages.size()):
		var stage: Dictionary = search_stages[stage_index]
		if stage_index > 0:
			fallback_ran = true
		var candidates: Array[Dictionary] = _score_candidates(map_data, poi_type, patterns, rule, anchor_cell, placement_context, stage, rng)
		if candidates.is_empty():
			_increment_reason_count(
				failure_counts,
				"no_candidate_origin_near_anchor" if not bool(stage.get("global_search", false)) else "no_candidate_origin_global"
			)
			continue

		var attempts: int = mini(int(stage.get("max_attempts", 32)), candidates.size())
		for _attempt in range(attempts):
			var candidate: Dictionary = _pick_weighted_candidate(candidates, rng)
			if candidate.is_empty():
				break
			var pattern_def: Dictionary = Dictionary(candidate.get("pattern", {}))
			var origin: Vector2i = Vector2i(candidate.get("origin", Vector2i.ZERO))
			last_attempted_origins.append(origin)
			if last_attempted_origins.size() > 8:
				last_attempted_origins.remove_at(0)
			var variants: Array[Dictionary] = _build_transform_variants(pattern_def, rng)
			for variant in variants:
				attempt_count += 1
				var result := stamp_service.apply_stamp(
					map_data,
					pattern_def,
					origin,
					int(variant.get("rotation", 0)),
					bool(variant.get("mirrored", false))
				)
				if not bool(result.get("success", false)):
					_increment_reason_count(failure_counts, _normalize_failure_reason(String(result.get("reason", "unknown"))))
					continue
				if not _validate_reachability_post_stamp(map_data, result):
					_revert_stamp(map_data, result)
					_increment_reason_count(failure_counts, "not_reachable")
					continue
				var poi_record := _build_poi_record(map_data, poi_type, pattern_def, result)
				map_data.register_poi_record(poi_record)
				_refresh_cached_poi_entries(map_data, placement_context)
				result["poi_record"] = poi_record.duplicate(true)
				result["poi_type"] = poi_type
				result["search_stage"] = String(stage.get("id", ""))
				result["attempt_count"] = attempt_count
				result["fallback_ran"] = fallback_ran
				result["anchor_cell"] = anchor_cell
				return result

			candidates.erase(candidate)
			if candidates.is_empty():
				break

	var dominant_reason: String = _dominant_failure_reason(failure_counts, "max_attempts_exceeded")
	_increment_reason_count(failure_counts, "max_attempts_exceeded")
	return {
		"success": false,
		"reason": dominant_reason,
		"poi_type": poi_type,
		"pattern_id": _pattern_ids_text(patterns),
		"anchor_cell": anchor_cell,
		"attempt_count": attempt_count,
		"fallback_ran": fallback_ran,
		"failure_counts": failure_counts.duplicate(true),
		"top_failure_reasons": _top_failure_reasons(failure_counts, 5),
		"last_attempted_origins": last_attempted_origins.duplicate(),
	}


func _score_candidates(map_data, poi_type: String, patterns: Array[Dictionary], rule: Dictionary, anchor_cell: Vector2i, placement_context: Dictionary, stage: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pattern_def in patterns:
		var size: Vector2i = Vector2i(pattern_def.get("size", Vector2i.ZERO))
		if size == Vector2i.ZERO:
			continue
		for origin in _candidate_origins(map_data, size, anchor_cell, placement_context, stage, rng):
			var center: Vector2i = origin + Vector2i(int(size.x / 2), int(size.y / 2))
			var score: float = _score_position(map_data, poi_type, pattern_def, center, rule, placement_context)
			if score <= -INF / 2.0:
				continue
			result.append({
				"origin": origin,
				"center": center,
				"score": score,
				"pattern": pattern_def,
			})
	result.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var trim_to: int = mini(int(stage.get("keep_top", 24)), result.size())
	return result.slice(0, trim_to)


func _pick_weighted_candidate(candidates: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if candidates.is_empty():
		return {}
	var top_count: int = min(12, candidates.size())
	var pool: Array = candidates.slice(0, top_count)
	return Dictionary(pool[rng.randi_range(0, pool.size() - 1)])


func _build_transform_variants(pattern_def: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var rotations: Array[int] = [0]
	if bool(pattern_def.get("can_rotate", false)):
		rotations = [0, 90, 180, 270]
	var mirror_options: Array[bool] = [false]
	if bool(pattern_def.get("can_mirror", false)):
		mirror_options.append(true)
	var variants: Array[Dictionary] = []
	for rotation in rotations:
		for mirrored in mirror_options:
			variants.append({"rotation": rotation, "mirrored": mirrored})
	if rng != null:
		for index in range(variants.size() - 1, 0, -1):
			var swap_index: int = rng.randi_range(0, index)
			var temp: Dictionary = variants[index]
			variants[index] = variants[swap_index]
			variants[swap_index] = temp
	return variants


func _build_poi_record(map_data, poi_type: String, pattern_def: Dictionary, stamp_result: Dictionary) -> Dictionary:
	var interaction_cell: Vector2i = Vector2i(stamp_result.get("interaction_cell", Vector2i(-1, -1)))
	return {
		"id": "%s_%s_%d_%d" % [poi_type, String(pattern_def.get("id", "")), interaction_cell.x, interaction_cell.y],
		"type": poi_type,
		"pattern_id": String(pattern_def.get("id", "")),
		"origin": Vector2i(stamp_result.get("origin", Vector2i.ZERO)),
		"size": Vector2i(pattern_def.get("size", Vector2i.ZERO)),
		"interaction_cell": interaction_cell,
		"fixed_player_spawn_local": Vector2i(pattern_def.get("fixed_player_spawn_local", Vector2i(-1, -1))),
		"entrance_cells": Array(stamp_result.get("entrance_cells", [])),
		"occupied_cells": Array(stamp_result.get("occupied_cells", [])),
		"npc_spawn_slots": Array(pattern_def.get("npc_spawn_slots", [])),
		"tags": [
			"poi:%s" % poi_type,
			"building:%s" % String(pattern_def.get("id", "")),
		],
	}


func _validate_reachability_post_stamp(map_data, stamp_result: Dictionary) -> bool:
	return true


func _revert_stamp(map_data, stamp_result: Dictionary) -> void:
	var previous_cells: Dictionary = stamp_result.get("previous_cells", {})
	for cell in stamp_result.get("occupied_cells", []):
		var world_cell := Vector2i(cell)
		if previous_cells.has(world_cell):
			var previous = previous_cells[world_cell]
			if previous == null:
				map_data.set_terrain(world_cell, MapCellScript.TerrainType.PLAIN)
				var current = map_data.get_cell(world_cell)
				if current != null:
					current.display_symbol_override = ""
					current.tags = []
			else:
				map_data.set_cell(world_cell, previous)


func _candidate_origins(map_data, size: Vector2i, anchor_cell: Vector2i, placement_context: Dictionary, stage: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var centers: Array[Vector2i] = _candidate_centers_from_context(anchor_cell, placement_context, stage, rng)
	if centers.is_empty():
		centers = _build_stage_candidate_centers(map_data, anchor_cell, stage, rng)
	var half_size := Vector2i(int(size.x / 2), int(size.y / 2))
	var seen: Dictionary = {}
	var x_max: int = max(0, map_data.width - size.x)
	var y_max: int = max(0, map_data.height - size.y)
	for center in centers:
		var origin := Vector2i(
			clampi(center.x - half_size.x, 0, x_max),
			clampi(center.y - half_size.y, 0, y_max)
		)
		if seen.has(origin):
			continue
		seen[origin] = true
		result.append(origin)
	return result


func _candidate_centers_from_context(anchor_cell: Vector2i, placement_context: Dictionary, stage: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	if placement_context.is_empty():
		return []
	var global_search: bool = bool(stage.get("global_search", false))
	var source_key: String = "global_candidate_cells" if global_search else "local_candidate_cells"
	var source: Array[Vector2i] = _vector2i_array_from_any(placement_context.get(source_key, []))
	if source.is_empty():
		return []
	var radius: int = int(stage.get("radius", -1))
	var sample_limit: int = int(stage.get("sample_limit", 64))
	var sampled: Array[Vector2i] = _sample_candidate_centers(source, anchor_cell, radius, sample_limit, rng)
	if not sampled.is_empty():
		return sampled
	if not global_search:
		var fallback_source: Array[Vector2i] = _vector2i_array_from_any(placement_context.get("global_candidate_cells", []))
		if not fallback_source.is_empty():
			return _sample_candidate_centers(fallback_source, anchor_cell, radius, sample_limit, rng)
	return []


func _build_stage_candidate_centers(map_data, anchor_cell: Vector2i, stage: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map_data == null:
		return result
	var sample_limit: int = int(stage.get("sample_limit", 64))
	if sample_limit <= 0:
		return result
	var radius: int = int(stage.get("radius", -1))
	var global_search: bool = bool(stage.get("global_search", false))
	var stride: int = _candidate_grid_stride(map_data)
	if not global_search and radius > 0:
		stride = maxi(2, int(floor(float(stride) * 0.5)))
	var scan_radius: int = maxi(1, int(floor(float(stride) * 0.5)))
	var offset: int = int(floor(float(stride) * 0.5))
	var min_x: int = offset
	var min_y: int = offset
	var max_x: int = map_data.width - 1
	var max_y: int = map_data.height - 1
	if radius >= 0 and anchor_cell != Vector2i(-1, -1):
		min_x = maxi(offset, anchor_cell.x - radius)
		max_x = mini(max_x, anchor_cell.x + radius)
		min_y = maxi(offset, anchor_cell.y - radius)
		max_y = mini(max_y, anchor_cell.y + radius)
	var x_steps: int = maxi(1, int(ceil(float(maxi(0, max_x - min_x + 1)) / float(stride))))
	var y_steps: int = maxi(1, int(ceil(float(maxi(0, max_y - min_y + 1)) / float(stride))))
	var total_positions: int = x_steps * y_steps
	var scan_budget: int = sample_limit * (STAGE_SCAN_BUDGET_MULTIPLIER_GLOBAL if global_search else STAGE_SCAN_BUDGET_MULTIPLIER_LOCAL)
	if total_positions > scan_budget and scan_budget > 0:
		var skip_factor: int = int(ceil(sqrt(float(total_positions) / float(scan_budget))))
		stride *= maxi(1, skip_factor)
		scan_radius = maxi(1, int(floor(float(stride) * 0.5)))
		offset = int(floor(float(stride) * 0.5))
		if radius >= 0 and anchor_cell != Vector2i(-1, -1):
			min_x = maxi(offset, anchor_cell.x - radius)
			max_x = mini(map_data.width - 1, anchor_cell.x + radius)
			min_y = maxi(offset, anchor_cell.y - radius)
			max_y = mini(map_data.height - 1, anchor_cell.y + radius)
		else:
			min_x = offset
			min_y = offset
	var seen: Dictionary = {}
	for y in range(min_y, max_y + 1, stride):
		for x in range(min_x, max_x + 1, stride):
			var center := _pick_best_center_in_window(map_data, Vector2i(x, y), scan_radius, not global_search)
			if center == Vector2i(-1, -1) or seen.has(center):
				continue
			seen[center] = true
			result.append(center)
	if result.size() <= sample_limit:
		return result
	return _sample_candidate_centers(result, anchor_cell, radius, sample_limit, rng)


func _score_position(map_data, poi_type: String, pattern_def: Dictionary, center: Vector2i, rule: Dictionary, placement_context: Dictionary = {}) -> float:
	if not map_data.is_in_bounds(center):
		return -INF
	var distance_from_spawn: float = center.distance_to(map_data.player_spawn)
	var min_distance: float = float(rule.get("spawn_min", 0.0))
	var max_distance: float = float(rule.get("spawn_max", INF))
	if distance_from_spawn < min_distance or distance_from_spawn > max_distance:
		return -INF

	if _too_close_to_other_pois(map_data, center, poi_type, rule, placement_context):
		return -INF

	var map_cell = map_data.get_cell(center)
	if map_cell == null:
		return -INF

	if not _area_supports_pattern(map_data, center, Vector2i(pattern_def.get("size", Vector2i.ZERO)), pattern_def):
		return -INF

	var terrain_score: float = _terrain_preference_score(map_data, center, pattern_def, placement_context)
	if terrain_score <= -10.0:
		return -INF
	var terraform_report: Dictionary = _score_terraform_window(map_data, center, Vector2i(pattern_def.get("size", Vector2i.ZERO)), pattern_def)
	var open_score: float = float(terraform_report.get("walkable_nearby", 0))
	var obstacle_pressure: float = float(terraform_report.get("blocked_nearby", 0))
	var edge_penalty: float = float(_distance_from_edge(map_data, center))

	var terraform_cost: float = float(terraform_report.get("terraform_cost", 0.0))
	var score: float = terrain_score * 4.0 + open_score * 0.75 - obstacle_pressure * 0.35 + edge_penalty * 0.08 - terraform_cost
	if poi_type == BuildingPatternLibraryScript.POI_TYPE_EGG:
		score += edge_penalty * 0.6
	if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE:
		score += float(_adjacent_terrain_count(map_data, center, [MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK, MapCellScript.TerrainType.HILL])) * 1.8
	if poi_type == BuildingPatternLibraryScript.POI_TYPE_RUIN:
		score += float(_adjacent_terrain_count(map_data, center, [MapCellScript.TerrainType.FOREST, MapCellScript.TerrainType.HILL, MapCellScript.TerrainType.DESERT, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK])) * 0.8
	return score


func _terrain_preference_score(map_data, center: Vector2i, pattern_def: Dictionary, placement_context: Dictionary = {}) -> float:
	var map_cell = map_data.get_cell(center)
	if map_cell == null:
		return -10.0
	var terrain_name := String(map_cell.terrain_name())
	var preferred: Array = pattern_def.get("preferred_terrain", [])
	if preferred.is_empty():
		return 1.0

	var score: float = 0.0
	for pref in preferred:
		match String(pref):
			terrain_name:
				score = maxf(score, 2.0)
			BuildingPatternLibraryScript.TERRAIN_PREF_MOUNTAIN_EDGE:
				if _adjacent_terrain_count(map_data, center, [MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK]) >= 1:
					score = maxf(score, 1.8)
			BuildingPatternLibraryScript.TERRAIN_PREF_RUIN_EDGE:
				if _adjacent_poi_type_count(map_data, center, "ruin", placement_context) >= 1:
					score = maxf(score, 1.8)
	return score if score > 0.0 else -10.0


func _too_close_to_other_pois(map_data, center: Vector2i, poi_type: String, rule: Dictionary, placement_context: Dictionary = {}) -> bool:
	for entry in _cached_poi_entries(map_data, placement_context):
		var other_kind: String = String(entry.get("kind", ""))
		if other_kind == "player_spawn":
			continue
		var other_cell: Vector2i = Vector2i(entry.get("cell", Vector2i(-1, -1)))
		if other_cell == Vector2i(-1, -1):
			continue
		var min_distance: float = _poi_distance_rule(poi_type, other_kind, rule)
		if min_distance > 0.0 and center.distance_to(other_cell) < min_distance:
			return true
	return false


func _poi_distance_rule(poi_type: String, other_kind: String, rule: Dictionary) -> float:
	var distances: Dictionary = rule.get("min_distance_by_kind", {})
	return float(distances.get(other_kind, 0.0))


func _build_placement_rules(map_data, config) -> Dictionary:
	var short_side: float = float(mini(map_data.width, map_data.height))
	var tavern_count: int = _pick_tavern_count(map_data, config)
	var chest_count: int = int(config.chest_count) if config != null else 1
	var ruin_count: int = int(config.ruin_count) if config != null else 1
	var egg_count: int = int(config.easter_egg_count) if config != null else 1
	var tavern_spawn_max: float = short_side * (0.18 if tavern_count <= 1 else 0.45)
	var tavern_to_tavern_spacing: float = maxf(14.0, short_side * 0.08)
	return {
		BuildingPatternLibraryScript.POI_TYPE_TAVERN: {
			"count": tavern_count,
			"spawn_min": short_side * 0.08,
			"spawn_max": tavern_spawn_max,
			"min_distance_by_kind": {
				"tavern": tavern_to_tavern_spacing,
				"challenge_entrance": 12.0,
				"ruin": 8.0,
				"chest": 8.0,
				"easter_egg": 8.0,
				"shrine": 8.0,
			},
		},
		BuildingPatternLibraryScript.POI_TYPE_CHALLENGE: {
			"count": max(1, int(config.challenge_count) if config != null else 1),
			"spawn_min": short_side * 0.25,
			"spawn_max": short_side * 0.60,
			"min_distance_by_kind": {
				"tavern": 12.0,
				"ruin": 8.0,
				"chest": 8.0,
				"easter_egg": 8.0,
				"shrine": 8.0,
			},
		},
		BuildingPatternLibraryScript.POI_TYPE_RUIN: {
			"count": max(1, ruin_count),
			"spawn_min": short_side * 0.20,
			"spawn_max": short_side * 0.75,
			"min_distance_by_kind": {
				"tavern": 10.0,
				"challenge_entrance": 6.0,
			},
		},
		BuildingPatternLibraryScript.POI_TYPE_CHEST: {
			"count": max(1, chest_count),
			"spawn_min": short_side * 0.10,
			"spawn_max": short_side * 0.85,
			"min_distance_by_kind": {
				"tavern": 8.0,
				"challenge_entrance": 4.0,
				"ruin": 4.0,
			},
		},
		BuildingPatternLibraryScript.POI_TYPE_EGG: {
			"count": max(1, egg_count),
			"spawn_min": short_side * 0.20,
			"spawn_max": short_side * 0.95,
			"min_distance_by_kind": {
				"tavern": 10.0,
				"challenge_entrance": 8.0,
			},
		},
		BuildingPatternLibraryScript.POI_TYPE_SHRINE: {
			"count": 1,
			"spawn_min": short_side * 0.15,
			"spawn_max": short_side * 0.85,
			"min_distance_by_kind": {
				"tavern": 8.0,
				"challenge_entrance": 6.0,
			},
		},
	}


func _pick_tavern_count(map_data, config) -> int:
	if config != null:
		var configured_count: int = int(config.tavern_count)
		if configured_count > 0:
			return configured_count
	if map_data == null:
		return 1
	var area: int = max(1, map_data.width * map_data.height)
	if area >= 1024 * 1024:
		return 6
	if area >= 512 * 512:
		return 4
	if area >= 256 * 256:
		return 3
	if area >= 128 * 128:
		return 2
	return 1


func _count_walkable_nearby(map_data, center: Vector2i, radius: int) -> int:
	var count: int = 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if map_data.is_walkable(Vector2i(x, y)):
				count += 1
	return count


func _count_blocked_nearby(map_data, center: Vector2i, radius: int) -> int:
	var count: int = 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if map_data.is_in_bounds(cell) and not map_data.is_walkable(cell):
				count += 1
	return count


func _distance_from_edge(map_data, cell: Vector2i) -> int:
	return mini(mini(cell.x, cell.y), mini(map_data.width - 1 - cell.x, map_data.height - 1 - cell.y))


func _adjacent_terrain_count(map_data, cell: Vector2i, terrain_types: Array) -> int:
	var count: int = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = map_data.get_cell(cell + dir)
		if neighbor != null and terrain_types.has(int(neighbor.terrain_type)):
			count += 1
	return count


func _adjacent_poi_type_count(map_data, cell: Vector2i, poi_type: String, placement_context: Dictionary = {}) -> int:
	var count: int = 0
	for entry in _cached_poi_entries(map_data, placement_context):
		if String(entry.get("kind", "")) != poi_type:
			continue
		if cell.distance_to(Vector2i(entry.get("cell", Vector2i(-1, -1)))) <= 10.0:
			count += 1
	return count


func _first_or_invalid_cell(cells: Array) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(cells[0])


func _pick_shrine_anchor(map_data, placement_context: Dictionary = {}) -> Vector2i:
	if map_data == null:
		return Vector2i(-1, -1)
	var walkable: Array[Vector2i] = _vector2i_array_from_any(placement_context.get("global_candidate_cells", []))
	if walkable.is_empty():
		walkable = map_data.get_walkable_cells()
	if walkable.is_empty():
		return Vector2i(-1, -1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in walkable:
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		var score: float = float(_count_walkable_nearby(map_data, cell, 1))
		if String(map_cell.terrain_name()) in ["plain", "hill", "forest", "desert"]:
			score += 4.0
		if score > best_score:
			best = cell
			best_score = score
	return best


func _refresh_cached_poi_entries(map_data, placement_context: Dictionary) -> void:
	if placement_context == null:
		return
	placement_context["poi_entries"] = _build_cached_poi_entries(map_data)


func _cached_poi_entries(map_data, placement_context: Dictionary) -> Array[Dictionary]:
	if placement_context != null and placement_context.has("poi_entries"):
		return _vector_dictionary_array_from_any(placement_context.get("poi_entries", []))
	return _build_cached_poi_entries(map_data)


func _build_cached_poi_entries(map_data) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if map_data == null:
		return entries
	if map_data.player_spawn != Vector2i(-1, -1):
		entries.append({"kind": "player_spawn", "cell": map_data.player_spawn})
	for record in map_data.get_poi_records():
		entries.append({
			"kind": String(record.get("type", "")),
			"cell": Vector2i(record.get("interaction_cell", Vector2i(-1, -1))),
		})
	return entries


func _build_placement_context(map_data, rng: RandomNumberGenerator = null) -> Dictionary:
	var walkable: Array[Vector2i] = map_data.get_walkable_cells()
	var reachable: Dictionary = connectivity_service.flood_fill_walkable(map_data, map_data.player_spawn)
	var reachable_cells: Array[Vector2i] = []
	for cell in reachable.keys():
		reachable_cells.append(cell)
	if reachable_cells.is_empty():
		reachable_cells = walkable.duplicate()
	return {
		"walkable_cells": walkable.duplicate(),
		"reachable_cells": reachable_cells.duplicate(),
		"global_candidate_cells": _sample_cells(walkable, _placement_context_global_limit(map_data), rng),
		"local_candidate_cells": _sample_cells(reachable_cells, _placement_context_local_limit(map_data), rng),
		"poi_entries": _build_cached_poi_entries(map_data),
	}


func _build_search_stages(poi_type: String, anchor_cell: Vector2i) -> Array[Dictionary]:
	var has_anchor: bool = anchor_cell != Vector2i(-1, -1)
	var stages: Array[Dictionary] = []
	if has_anchor:
		stages.append({
			"id": DEFAULT_STAGE_LOCAL,
			"radius": 18 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 14,
			"sample_limit": 96 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 48,
			"keep_top": 16,
			"max_attempts": 12 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 8,
			"global_search": false,
		})
		stages.append({
			"id": DEFAULT_STAGE_EXPANDED,
			"radius": 36 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 24,
			"sample_limit": 128 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 72,
			"keep_top": 18,
			"max_attempts": 14 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 10,
			"global_search": false,
		})
	stages.append({
		"id": DEFAULT_STAGE_GLOBAL,
		"radius": -1,
		"sample_limit": 192 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 80,
		"keep_top": 20 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 12,
		"max_attempts": 18 if poi_type == BuildingPatternLibraryScript.POI_TYPE_CHALLENGE else 8,
		"global_search": true,
	})
	return stages


func _sample_candidate_centers(source_cells: Array[Vector2i], anchor_cell: Vector2i, radius: int, sample_limit: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	if source_cells.is_empty() or sample_limit <= 0:
		return []
	var filtered: Array[Vector2i] = []
	if radius >= 0 and anchor_cell != Vector2i(-1, -1):
		var radius_sq: int = radius * radius
		for cell in source_cells:
			if int(anchor_cell.distance_squared_to(cell)) <= radius_sq:
				filtered.append(cell)
	else:
		filtered = source_cells.duplicate()
	if filtered.is_empty():
		return []
	if filtered.size() <= sample_limit:
		return filtered

	var result: Array[Vector2i] = []
	var step: float = float(filtered.size()) / float(sample_limit)
	var offset: float = rng.randf() * step if rng != null else 0.0
	for index in range(sample_limit):
		var picked_index: int = mini(filtered.size() - 1, int(floor(offset + float(index) * step)))
		result.append(filtered[picked_index])
	return result


func _sample_cells(cells: Array[Vector2i], limit: int, rng: RandomNumberGenerator = null) -> Array[Vector2i]:
	if cells.is_empty() or limit <= 0:
		return []
	if cells.size() <= limit:
		return cells.duplicate()
	var result: Array[Vector2i] = []
	var step: float = float(cells.size()) / float(limit)
	var offset: float = rng.randf() * step if rng != null else 0.0
	for index in range(limit):
		var picked_index: int = mini(cells.size() - 1, int(floor(offset + float(index) * step)))
		result.append(cells[picked_index])
	return result


func _placement_context_global_limit(map_data) -> int:
	if map_data == null:
		return CONTEXT_SAMPLE_LIMIT_GLOBAL_SMALL
	var area: int = max(1, map_data.width * map_data.height)
	if area >= 1024 * 1024:
		return CONTEXT_SAMPLE_LIMIT_GLOBAL_LARGE
	if area >= 512 * 512:
		return CONTEXT_SAMPLE_LIMIT_GLOBAL_MEDIUM
	return CONTEXT_SAMPLE_LIMIT_GLOBAL_SMALL


func _placement_context_local_limit(map_data) -> int:
	if map_data == null:
		return CONTEXT_SAMPLE_LIMIT_LOCAL_SMALL
	var area: int = max(1, map_data.width * map_data.height)
	if area >= 1024 * 1024:
		return CONTEXT_SAMPLE_LIMIT_LOCAL_LARGE
	if area >= 512 * 512:
		return CONTEXT_SAMPLE_LIMIT_LOCAL_MEDIUM
	return CONTEXT_SAMPLE_LIMIT_LOCAL_SMALL


func _vector2i_array_from_any(source_value) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in Array(source_value):
		result.append(Vector2i(value))
	return result


func _vector_dictionary_array_from_any(source_value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in Array(source_value):
		result.append(Dictionary(value))
	return result


func _candidate_grid_stride(map_data) -> int:
	if map_data == null:
		return CANDIDATE_GRID_STRIDE_SMALL
	var short_side: int = mini(map_data.width, map_data.height)
	if short_side >= 768:
		return CANDIDATE_GRID_STRIDE_LARGE
	if short_side >= 256:
		return CANDIDATE_GRID_STRIDE_MEDIUM
	return CANDIDATE_GRID_STRIDE_SMALL


func _pick_best_center_in_window(map_data, anchor: Vector2i, radius: int, prioritize_reachable: bool) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for y in range(maxi(0, anchor.y - radius), mini(map_data.height - 1, anchor.y + radius) + 1):
		for x in range(maxi(0, anchor.x - radius), mini(map_data.width - 1, anchor.x + radius) + 1):
			var cell := Vector2i(x, y)
			var map_cell = map_data.get_cell(cell)
			if map_cell == null:
				continue
			if _has_existing_structure(map_cell) or _has_existing_poi(map_cell) or cell == map_data.player_spawn:
				continue
			if int(map_cell.terrain_type) in [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER]:
				continue
			var score: float = 0.0
			if prioritize_reachable and map_data.is_walkable(cell):
				score += 3.0
			if map_data.is_walkable(cell):
				score += 2.0
			score += float(_distance_from_edge(map_data, cell)) * 0.04
			score += float(_count_walkable_nearby(map_data, cell, 1)) * 0.2
			score -= float(_count_blocked_nearby(map_data, cell, 1)) * 0.1
			if score > best_score:
				best = cell
				best_score = score
	return best


func _area_supports_pattern(map_data, center: Vector2i, size: Vector2i, pattern_def: Dictionary) -> bool:
	if map_data == null or size == Vector2i.ZERO:
		return false
	var half_size := Vector2i(int(size.x / 2), int(size.y / 2))
	var origin := center - half_size
	if origin.x < 0 or origin.y < 0 or origin.x + size.x > map_data.width or origin.y + size.y > map_data.height:
		return false
	var forbidden_hits: int = 0
	var hard_conflicts: int = 0
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			var cell := Vector2i(x, y)
			var map_cell = map_data.get_cell(cell)
			if map_cell == null:
				return false
			if _has_existing_structure(map_cell) or _has_existing_poi(map_cell) or cell == map_data.player_spawn:
				hard_conflicts += 1
				continue
			if _is_forbidden_terrain_for_pattern(int(map_cell.terrain_type), pattern_def):
				forbidden_hits += 1
	if hard_conflicts > 0:
		return false
	return forbidden_hits <= _allowed_forbidden_terrain_hits(pattern_def)


func _score_terraform_window(map_data, center: Vector2i, size: Vector2i, pattern_def: Dictionary) -> Dictionary:
	var report := {
		"terraform_cost": 0.0,
		"walkable_nearby": _count_walkable_nearby(map_data, center, int(pattern_def.get("clearance_radius", 1)) + 1),
		"blocked_nearby": _count_blocked_nearby(map_data, center, 2),
	}
	if map_data == null or size == Vector2i.ZERO:
		return report
	var half_size := Vector2i(int(size.x / 2), int(size.y / 2))
	var origin := center - half_size
	var terraform_cost: float = 0.0
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			var cell := Vector2i(x, y)
			var map_cell = map_data.get_cell(cell)
			if map_cell == null:
				terraform_cost += 99.0
				continue
			match int(map_cell.terrain_type):
				MapCellScript.TerrainType.PLAIN:
					terraform_cost += 0.0
				MapCellScript.TerrainType.FOREST, MapCellScript.TerrainType.HILL, MapCellScript.TerrainType.DESERT, MapCellScript.TerrainType.SWAMP:
					terraform_cost += 0.35
				MapCellScript.TerrainType.TREE, MapCellScript.TerrainType.ROCK, MapCellScript.TerrainType.STATUE:
					terraform_cost += 0.85
				MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK:
					terraform_cost += 1.8
				MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER:
					terraform_cost += 99.0
				_:
					terraform_cost += 0.6
	report["terraform_cost"] = terraform_cost
	return report


func _allowed_forbidden_terrain_hits(pattern_def: Dictionary) -> int:
	if bool(pattern_def.get("major", false)):
		return 2
	return 0


func _is_forbidden_terrain_for_pattern(terrain_type: int, pattern_def: Dictionary) -> bool:
	for forbidden in pattern_def.get("forbidden_terrain", []):
		if typeof(forbidden) == TYPE_INT and int(forbidden) == terrain_type:
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


func _has_existing_poi(map_cell) -> bool:
	if map_cell == null:
		return false
	for tag in map_cell.tags:
		if String(tag).begins_with("poi:") and String(tag) != "poi:player_spawn":
			return true
	return false


func _increment_reason_count(counts: Dictionary, reason: String) -> void:
	if reason.is_empty():
		reason = "unknown"
	counts[reason] = int(counts.get(reason, 0)) + 1


func _normalize_failure_reason(reason: String) -> String:
	match reason:
		"overlaps_player_spawn":
			return "overlaps_spawn"
		"challenge_front_clearance_too_small":
			return "not_enough_front_clearance"
		"challenge_single_file_entry", "ruin_not_open_enough", "interaction_fully_blocked":
			return "not_enough_interaction_space"
		"tavern_clearance_too_tight":
			return "not_enough_front_clearance"
		_:
			return reason if not reason.is_empty() else "unknown"


func _dominant_failure_reason(counts: Dictionary, fallback_reason: String) -> String:
	var best_reason: String = fallback_reason
	var best_count: int = -1
	for reason in counts.keys():
		var count: int = int(counts.get(reason, 0))
		if count > best_count:
			best_reason = String(reason)
			best_count = count
	return best_reason


func _top_failure_reasons(counts: Dictionary, limit: int) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for reason in counts.keys():
		pairs.append({
			"reason": String(reason),
			"count": int(counts.get(reason, 0)),
		})
	pairs.sort_custom(func(a, b): return int(a.get("count", 0)) > int(b.get("count", 0)))
	return pairs.slice(0, mini(limit, pairs.size()))


func _pattern_ids_text(patterns: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for pattern_def in patterns:
		ids.append(String(pattern_def.get("id", "")))
	return ",".join(ids)
