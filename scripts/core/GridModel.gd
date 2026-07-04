class_name GridModel
extends RefCounted

var width: int = 0
var height: int = 0
var blocked_cells: Dictionary = {}
var enemy_blocked_cells: Dictionary = {}
var actor_at: Dictionary = {}
var grid_items_at: Dictionary = {}
var grid_items_by_id: Dictionary = {}

func setup(new_width: int, new_height: int) -> void:
	width = new_width
	height = new_height
	blocked_cells.clear()
	enemy_blocked_cells.clear()
	actor_at.clear()
	grid_items_at.clear()
	grid_items_by_id.clear()

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func is_blocked(cell: Vector2i) -> bool:
	return not is_inside(cell) or blocked_cells.has(cell)

func add_blocked(cell: Vector2i) -> void:
	if is_inside(cell):
		blocked_cells[cell] = true

func add_enemy_blocked(cell: Vector2i) -> void:
	if is_inside(cell):
		enemy_blocked_cells[cell] = true

func remove_enemy_blocked(cell: Vector2i) -> void:
	enemy_blocked_cells.erase(cell)

func is_enemy_blocked(cell: Vector2i) -> bool:
	return is_blocked(cell) or enemy_blocked_cells.has(cell)

func get_actor(cell: Vector2i):
	return actor_at.get(cell)

func get_grid_items(cell: Vector2i) -> Array:
	return grid_items_at.get(cell, [])

func get_blocking_item(cell: Vector2i):
	for item in get_grid_items(cell):
		if item != null and item.has_method("is_grid_blocking") and item.is_grid_blocking():
			return item
	return null

func can_enter(cell: Vector2i) -> bool:
	return is_inside(cell) and not is_blocked(cell) and get_blocking_item(cell) == null

func can_enemy_enter(cell: Vector2i) -> bool:
	return is_inside(cell) and not is_enemy_blocked(cell) and get_blocking_item(cell) == null

func place_item(item, cell: Vector2i) -> bool:
	if item == null:
		return false
	if item.has_method("is_grid_blocking") and item.is_grid_blocking() and not can_enter(cell):
		return false
	if not is_inside(cell) or is_blocked(cell):
		return false

	item.grid_pos = cell
	_add_item_to_cell(item, cell)
	if _has_property(item, "id"):
		grid_items_by_id[item.id] = item
	return true

func move_item(item, target: Vector2i) -> bool:
	if item == null:
		return false
	if item.has_method("is_grid_blocking") and item.is_grid_blocking() and not can_enter(target):
		return false
	if not is_inside(target) or is_blocked(target):
		return false

	_remove_item_from_cell(item, item.grid_pos)
	item.grid_pos = target
	_add_item_to_cell(item, target)
	return true

func remove_item(item) -> void:
	if item == null:
		return
	_remove_item_from_cell(item, item.grid_pos)
	if _has_property(item, "id"):
		grid_items_by_id.erase(item.id)

func place_actor(actor, cell: Vector2i) -> bool:
	if not place_item(actor, cell):
		return false

	actor_at[cell] = actor
	return true

func move_actor(actor, target: Vector2i) -> bool:
	if not move_item(actor, target):
		return false

	for cell in actor_at.keys():
		if actor_at[cell] == actor:
			actor_at.erase(cell)
			break
	actor_at[target] = actor
	return true

func remove_actor(actor) -> void:
	actor_at.erase(actor.grid_pos)
	remove_item(actor)

func _add_item_to_cell(item, cell: Vector2i) -> void:
	var items: Array = grid_items_at.get(cell, [])
	if not items.has(item):
		items.append(item)
	grid_items_at[cell] = items

func _remove_item_from_cell(item, cell: Vector2i) -> void:
	if not grid_items_at.has(cell):
		return

	var items: Array = grid_items_at[cell]
	items.erase(item)
	if items.is_empty():
		grid_items_at.erase(cell)
	else:
		grid_items_at[cell] = items

func _has_property(object, property_name: String) -> bool:
	if object == null or not object.has_method("get_property_list"):
		return false

	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
