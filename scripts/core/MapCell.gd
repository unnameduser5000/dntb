class_name MapCell
extends RefCounted

enum TerrainType {
	PLAIN,
	FOREST,
	TREE,
	ROCK,
	STATUE,
	STRUCTURE_WALL,
	HILL,
	MOUNTAIN,
	PEAK,
	WATER,
	RIVER,
	BRIDGE,
	SWAMP,
	DESERT,
}

var cell: Vector2i = Vector2i.ZERO
var terrain_type: int = TerrainType.PLAIN
var height_score: float = 0.0
var moisture_score: float = 0.0
var dryness_score: float = 0.0
var walkable: bool = true
var blocks_vision: bool = false
var move_cost: int = 1
var tags: Array[String] = []
var display_symbol_override: String = ""


func duplicate_cell():
	var copy = get_script().new()
	copy.cell = cell
	copy.terrain_type = terrain_type
	copy.height_score = height_score
	copy.moisture_score = moisture_score
	copy.dryness_score = dryness_score
	copy.walkable = walkable
	copy.blocks_vision = blocks_vision
	copy.move_cost = move_cost
	copy.tags = tags.duplicate()
	copy.display_symbol_override = display_symbol_override
	return copy


func terrain_name() -> String:
	match terrain_type:
		TerrainType.PLAIN:
			return "plain"
		TerrainType.FOREST:
			return "forest"
		TerrainType.TREE:
			return "tree"
		TerrainType.ROCK:
			return "rock"
		TerrainType.STATUE:
			return "statue"
		TerrainType.STRUCTURE_WALL:
			return "structure_wall"
		TerrainType.HILL:
			return "hill"
		TerrainType.MOUNTAIN:
			return "mountain"
		TerrainType.PEAK:
			return "peak"
		TerrainType.WATER:
			return "water"
		TerrainType.RIVER:
			return "river"
		TerrainType.BRIDGE:
			return "bridge"
		TerrainType.SWAMP:
			return "swamp"
		TerrainType.DESERT:
			return "desert"
	return "unknown"


func terrain_symbol() -> String:
	if not display_symbol_override.is_empty():
		return display_symbol_override
	match terrain_type:
		TerrainType.PLAIN:
			return "."
		TerrainType.FOREST:
			return "F"
		TerrainType.TREE:
			return "t"
		TerrainType.ROCK:
			return "r"
		TerrainType.STATUE:
			return "s"
		TerrainType.STRUCTURE_WALL:
			return "#"
		TerrainType.HILL:
			return "^"
		TerrainType.MOUNTAIN:
			return "M"
		TerrainType.PEAK:
			return "P"
		TerrainType.WATER:
			return "~"
		TerrainType.RIVER:
			return "R"
		TerrainType.BRIDGE:
			return "="
		TerrainType.SWAMP:
			return "S"
		TerrainType.DESERT:
			return "D"
	return "?"
