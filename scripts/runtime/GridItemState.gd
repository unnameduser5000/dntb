class_name GridItemState
extends RefCounted

enum GridItemKind {
	ACTOR,
	PLAYER,
	ENEMY,
	PROP,
	PICKUP,
	TRAP,
}

var id: int = -1
var grid_item_id: String = ""
var grid_item_kind: int = GridItemKind.PROP
var grid_pos: Vector2i = Vector2i.ZERO
var blocks_movement: bool = true
var display_name: String = ""
var tags: Array[String] = []


func setup_grid_item(new_id: int, item_id: String, kind: int, start_cell: Vector2i, blocking: bool = true) -> void:
	id = new_id
	grid_item_id = item_id
	grid_item_kind = kind
	grid_pos = start_cell
	blocks_movement = blocking


func is_grid_blocking() -> bool:
	return blocks_movement


func has_grid_tag(tag: String) -> bool:
	return tags.has(tag)


func get_grid_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not grid_item_id.is_empty():
		return grid_item_id
	return "GridItem#%d" % id


func get_grid_snapshot() -> Dictionary:
	return {
		"id": id,
		"grid_item_id": grid_item_id,
		"grid_item_kind": int(grid_item_kind),
		"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
		"blocks_movement": blocks_movement,
		"display_name": display_name,
		"tags": tags,
	}


func load_grid_snapshot(data: Dictionary) -> void:
	id = int(data.get("id", -1))
	grid_item_id = String(data.get("grid_item_id", ""))
	grid_item_kind = int(data.get("grid_item_kind", GridItemKind.PROP))
	var cell: Dictionary = {}
	var raw_cell = data.get("grid_pos", {})
	if typeof(raw_cell) == TYPE_DICTIONARY:
		cell = raw_cell
	grid_pos = Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))
	blocks_movement = bool(data.get("blocks_movement", true))
	display_name = String(data.get("display_name", ""))
	tags.clear()
	for tag in data.get("tags", []):
		tags.append(String(tag))
