class_name BuildingPatternLibrary
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")

const POI_TYPE_TAVERN := "tavern"
const POI_TYPE_CHALLENGE := "challenge_entrance"
const POI_TYPE_RUIN := "ruin"
const POI_TYPE_CHEST := "chest"
const POI_TYPE_EGG := "easter_egg"
const POI_TYPE_SHRINE := "shrine"
const POI_TYPE_BRIDGE := "bridge"

const TERRAIN_PREF_MOUNTAIN_EDGE := "mountain_edge"
const TERRAIN_PREF_RUIN_EDGE := "ruin_edge"

var _patterns_by_type: Dictionary = {}
var _patterns_by_id: Dictionary = {}


func _init() -> void:
	_register_defaults()


func get_patterns_for_type(poi_type: String) -> Array[Dictionary]:
	var raw: Array = _patterns_by_type.get(poi_type, [])
	var result: Array[Dictionary] = []
	for entry in raw:
		result.append(Dictionary(entry).duplicate(true))
	return result


func get_pattern(pattern_id: String) -> Dictionary:
	var pattern: Dictionary = _patterns_by_id.get(pattern_id, {})
	return pattern.duplicate(true)


func get_supported_poi_types() -> Array[String]:
	var result: Array[String] = []
	for key in _patterns_by_type.keys():
		result.append(String(key))
	result.sort()
	return result


func _register_defaults() -> void:
	_patterns_by_type.clear()
	_patterns_by_id.clear()

	_register_pattern({
		"id": "tavern_roadside_13",
		"poi_type": POI_TYPE_TAVERN,
		"interaction_marker": "T",
		"entrance_marker": "d",
		"ascii": [
			".....ppp.....",
			"...pp___pp...",
			"..p__r_r__p..",
			"..p__###__p..",
			".pp__#T#s_pp.",
			".pp_r#_#r_pp.",
			".pp__#d#__pp.",
			"..p__s_s__p..",
			"..p_______p..",
			"...pp___pp...",
			".....ppp.....",
			"......p......",
			".............",
		],
		"preferred_terrain": ["plain", "hill"],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK],
		"clearance_radius": 3,
		"can_rotate": false,
		"can_mirror": false,
		"requires_reachable": true,
		"major": true,
		"fixed_player_spawn_local": Vector2i(6, 8),
		"npc_spawn_slots": [
			{
				"slot_id": "spawn_host",
				"npc_id": "tavern_keeper",
				"fixed_cell_local": Vector2i(5, 8),
				"preferred_tags": ["building_floor", "building_open_ground"],
				"avoid_tags": ["building_door", "interactable"],
				"near": "player_spawn",
				"track_by_default": true,
				"spawn_count": 1,
			},
		],
	})

	_register_pattern({
		"id": "challenge_cave_11",
		"poi_type": POI_TYPE_CHALLENGE,
		"interaction_marker": "C",
		"entrance_marker": "d",
		"ascii": [
			"..rr###rr..",
			".r#######r.",
			".r###C###r.",
			"..r##d##r..",
			"...ppppp...",
			"..pp___pp..",
			"..p_____p..",
			"..p_____p..",
			"...pp_pp...",
			".....p.....",
			"...........",
		],
		"preferred_terrain": ["hill", "forest", TERRAIN_PREF_MOUNTAIN_EDGE],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER],
		"front_clearance_size": Vector2i(5, 5),
		"clearance_radius": 2,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": true,
	})

	_register_pattern({
		"id": "ruin_temple_15",
		"poi_type": POI_TYPE_RUIN,
		"interaction_marker": "U",
		"entrance_marker": "d",
		"ascii": [
			"....r.....r....",
			"..rr_______rr..",
			".r___s___s___r.",
			".r___________r.",
			"..r___###___r..",
			"..r___#U#___r..",
			"..r___#_#___r..",
			".r____d_d____r.",
			".r___________r.",
			"..r___s_s___r..",
			"...r_______r...",
			".....ppppp.....",
			"......ppp......",
			"...............",
			"...............",
		],
		"preferred_terrain": ["hill", "forest", "desert", TERRAIN_PREF_MOUNTAIN_EDGE],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER],
		"clearance_radius": 1,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": true,
	})

	_register_pattern({
		"id": "chest_clearing_5",
		"poi_type": POI_TYPE_CHEST,
		"interaction_marker": "$",
		"entrance_marker": "",
		"ascii": [
			".t.t.",
			"..p..",
			".p$p.",
			"..p..",
			".t.t.",
		],
		"preferred_terrain": ["forest", "hill", "plain"],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK],
		"clearance_radius": 1,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": false,
	})

	_register_pattern({
		"id": "chest_ruin_cache_7",
		"poi_type": POI_TYPE_CHEST,
		"interaction_marker": "$",
		"entrance_marker": "",
		"ascii": [
			"..r.r..",
			".r___r.",
			".._$__.",
			".r___r.",
			"..r....",
			".......",
			".......",
		],
		"preferred_terrain": ["hill", "forest", TERRAIN_PREF_RUIN_EDGE],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK],
		"clearance_radius": 1,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": false,
	})

	_register_pattern({
		"id": "egg_obelisk_5",
		"poi_type": POI_TYPE_EGG,
		"interaction_marker": "E",
		"entrance_marker": "",
		"ascii": [
			"..s..",
			".pEp.",
			"..s..",
			".....",
			".....",
		],
		"preferred_terrain": ["forest", "hill", "plain", "desert"],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK],
		"clearance_radius": 1,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": false,
	})

	_register_pattern({
		"id": "egg_smile_stones_9",
		"poi_type": POI_TYPE_EGG,
		"interaction_marker": "E",
		"entrance_marker": "",
		"ascii": [
			"r.......r",
			"..p...p..",
			".........",
			"....E....",
			"..p...p..",
			"r.......r",
			".........",
			".........",
			".........",
		],
		"preferred_terrain": ["plain", "hill", "desert"],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK],
		"clearance_radius": 1,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": false,
	})

	_register_pattern({
		"id": "shrine_small_7",
		"poi_type": POI_TYPE_SHRINE,
		"interaction_marker": "H",
		"entrance_marker": "",
		"ascii": [
			"..s.s..",
			"...p...",
			".p_H_p.",
			"...p...",
			"..s.s..",
			".......",
			".......",
		],
		"preferred_terrain": ["plain", "hill", "forest", "desert"],
		"forbidden_terrain": [MapCellScript.TerrainType.WATER, MapCellScript.TerrainType.RIVER, MapCellScript.TerrainType.MOUNTAIN, MapCellScript.TerrainType.PEAK],
		"clearance_radius": 1,
		"can_rotate": true,
		"can_mirror": true,
		"requires_reachable": true,
		"major": false,
	})

	_register_pattern({
		"id": "bridge_vertical_5x9",
		"poi_type": POI_TYPE_BRIDGE,
		"interaction_marker": "",
		"entrance_marker": "",
		"ascii": [
			"~~=~~",
			"~~=~~",
			"~~=~~",
			"~~=~~",
			"~~=~~",
			"~~=~~",
			"~~=~~",
			"~~=~~",
			"~~=~~",
		],
		"preferred_terrain": [],
		"forbidden_terrain": [],
		"requires_water_context": true,
		"clearance_radius": 0,
		"can_rotate": false,
		"can_mirror": false,
		"requires_reachable": false,
		"major": false,
		"passive_only": true,
	})

	_register_pattern({
		"id": "bridge_horizontal_9x5",
		"poi_type": POI_TYPE_BRIDGE,
		"interaction_marker": "",
		"entrance_marker": "",
		"ascii": [
			"~~~~~~~~~",
			"=========",
			"=========",
			"=========",
			"~~~~~~~~~",
		],
		"preferred_terrain": [],
		"forbidden_terrain": [],
		"requires_water_context": true,
		"clearance_radius": 0,
		"can_rotate": false,
		"can_mirror": false,
		"requires_reachable": false,
		"major": false,
		"passive_only": true,
	})


func _register_pattern(pattern: Dictionary) -> void:
	var copy: Dictionary = pattern.duplicate(true)
	copy["size"] = _compute_size(Array(copy.get("ascii", [])))
	var poi_type: String = String(copy.get("poi_type", ""))
	var pattern_id: String = String(copy.get("id", ""))
	if poi_type.is_empty() or pattern_id.is_empty():
		return
	if not _patterns_by_type.has(poi_type):
		_patterns_by_type[poi_type] = []
	_patterns_by_type[poi_type].append(copy)
	_patterns_by_id[pattern_id] = copy


func _compute_size(lines: Array) -> Vector2i:
	if lines.is_empty():
		return Vector2i.ZERO
	return Vector2i(String(lines[0]).length(), lines.size())
