class_name WorldGenerator
extends RefCounted

const MapDataScript := preload("res://scripts/core/MapData.gd")
const MapCellScript := preload("res://scripts/core/MapCell.gd")
const MapGenConfigScript := preload("res://scripts/core/MapGenConfig.gd")
const MountainGeneratorScript := preload("res://scripts/core/MountainGenerator.gd")
const TerrainGeneratorScript := preload("res://scripts/core/TerrainGenerator.gd")
const RiverGeneratorScript := preload("res://scripts/core/RiverGenerator.gd")
const POIPlacementServiceScript := preload("res://scripts/core/POIPlacementService.gd")
const ObstacleGeneratorScript := preload("res://scripts/core/ObstacleGenerator.gd")
const ConnectivityServiceScript := preload("res://scripts/core/ConnectivityService.gd")

var config = MapGenConfigScript.new()
var mountain_generator = MountainGeneratorScript.new()
var terrain_generator = TerrainGeneratorScript.new()
var river_generator = RiverGeneratorScript.new()
var poi_placement_service = POIPlacementServiceScript.new()
var obstacle_generator = ObstacleGeneratorScript.new()
var connectivity_service = ConnectivityServiceScript.new()

const STAGE_DEFS := [
	{"id": "fill_plain", "label": "铺设平原底图", "breakdown_key": "fill_plain_ms"},
	{"id": "mountain_generation", "label": "塑造山体与高地", "breakdown_key": "mountain_generation_ms"},
	{"id": "terrain_generation", "label": "分配地表生物群系", "breakdown_key": "terrain_generation_ms"},
	{"id": "river_generation", "label": "刻画河流与水域", "breakdown_key": "river_generation_ms"},
	{"id": "poi_placement", "label": "放置出生点与兴趣点", "breakdown_key": "poi_placement_ms"},
	{"id": "obstacle_generation", "label": "散布树木与战术障碍", "breakdown_key": "obstacle_generation_ms"},
	{"id": "connectivity", "label": "打通路径并验证连通性", "breakdown_key": "connectivity_ms"},
]


func generate_world(seed_value, config_override = null):
	var session := create_generation_session(seed_value, config_override)
	for stage in get_stage_defs():
		run_generation_stage(session, String(stage.get("id", "")))
	return finish_generation_session(session)


func get_stage_defs() -> Array[Dictionary]:
	return STAGE_DEFS.duplicate(true)


func create_generation_session(seed_value, config_override = null) -> Dictionary:
	var cfg = config_override if config_override != null else config
	var map_data = MapDataScript.new()
	map_data.setup(int(cfg.map_size.x), int(cfg.map_size.y))
	map_data.seed = str(seed_value)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = abs(int(hash(str(seed_value))))
	return {
		"seed": str(seed_value),
		"config": cfg,
		"map_data": map_data,
		"rng": rng,
		"breakdown": {},
		"total_started_at": Time.get_ticks_msec(),
	}


func run_generation_stage(session: Dictionary, stage_id: String) -> void:
	if session == null or stage_id.is_empty():
		return
	var map_data = session.get("map_data")
	var cfg = session.get("config")
	var rng: RandomNumberGenerator = session.get("rng")
	if map_data == null:
		return

	var stage_started_at: int = Time.get_ticks_msec()
	match stage_id:
		"fill_plain":
			_fill_plain(map_data)
		"mountain_generation":
			mountain_generator.generate(map_data, cfg, rng)
		"terrain_generation":
			terrain_generator.generate(map_data, cfg, rng)
		"river_generation":
			river_generator.generate(map_data, cfg, rng)
		"poi_placement":
			poi_placement_service.place_pois(map_data, rng, cfg)
		"obstacle_generation":
			obstacle_generator.generate(map_data, cfg, rng)
		"connectivity":
			connectivity_service.ensure_core_pois_reachable(map_data, cfg, rng)
			connectivity_service.summarize(map_data)
		_:
			return

	_record_stage_time(session, stage_id, float(Time.get_ticks_msec() - stage_started_at))


func finish_generation_session(session: Dictionary):
	if session == null:
		return null
	var map_data = session.get("map_data")
	if map_data == null:
		return null
	var total_started_at: int = int(session.get("total_started_at", Time.get_ticks_msec()))
	var breakdown: Dictionary = session.get("breakdown", {})
	map_data.generation_total_ms = float(Time.get_ticks_msec() - total_started_at)
	map_data.generation_breakdown_ms = breakdown.duplicate(true)
	return map_data


func _record_stage_time(session: Dictionary, stage_id: String, elapsed_ms: float) -> void:
	if session == null:
		return
	var breakdown: Dictionary = session.get("breakdown", {})
	for stage in STAGE_DEFS:
		if String(stage.get("id", "")) != stage_id:
			continue
		var breakdown_key := String(stage.get("breakdown_key", ""))
		if not breakdown_key.is_empty():
			breakdown[breakdown_key] = elapsed_ms
		break
	session["breakdown"] = breakdown


func _fill_plain(map_data) -> void:
	for cell in map_data.get_all_cells():
		var map_cell = MapCellScript.new()
		map_cell.cell = cell
		map_data.set_cell(cell, map_cell)
		map_data.set_terrain(cell, MapCellScript.TerrainType.PLAIN)
