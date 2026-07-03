class_name ChestState
extends "res://scripts/runtime/GridItemState.gd"

var is_opened: bool = false
var drop_pool: Array[Dictionary] = []


func setup_chest(new_id: int, start_cell: Vector2i, drops: Array = []) -> void:
	setup_grid_item(new_id, "chest", GridItemKind.PROP, start_cell, true)
	display_name = "宝箱"
	tags = ["chest", "interactable"]
	set_drop_pool(drops)


func set_drop_pool(drops: Array) -> void:
	drop_pool.clear()
	for drop in drops:
		if typeof(drop) == TYPE_DICTIONARY:
			drop_pool.append(Dictionary(drop).duplicate(true))


func open() -> bool:
	if is_opened:
		return false
	is_opened = true
	blocks_movement = false
	display_name = "打开的宝箱"
	if not tags.has("opened"):
		tags.append("opened")
	return true
