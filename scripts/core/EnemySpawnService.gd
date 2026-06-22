extends Node

## Enemy roster/spawn entry point.
## Existing EnemyPlanner decides actions; this service decides what appears.

signal enemy_registered(enemy_id: String)
signal spawn_plan_created(floor_index: int, plan: Array)

var _enemy_defs: Dictionary = {}


func register_enemy_def(enemy_def: Resource) -> void:
	if enemy_def == null or not _has_property(enemy_def, "id"):
		return
	if String(enemy_def.get("id")).is_empty():
		return
	var enemy_id := String(enemy_def.get("id"))
	_enemy_defs[enemy_id] = enemy_def
	enemy_registered.emit(enemy_id)


func register_enemy_defs(enemy_defs: Array) -> void:
	for enemy_def in enemy_defs:
		register_enemy_def(enemy_def)


func get_enemy_def(enemy_id: String):
	return _enemy_defs.get(enemy_id)


func get_candidates_for_floor(floor_index: int) -> Array:
	var result: Array = []
	for enemy_def in _enemy_defs.values():
		var spawn_floor := int(_get_property(enemy_def, "spawn_floor", 1))
		if floor_index >= spawn_floor:
			result.append(enemy_def)
	return result


func pick_enemy_for_floor(floor_index: int):
	var candidates := get_candidates_for_floor(floor_index)
	if candidates.is_empty():
		return null

	var total_weight := 0
	for enemy_def in candidates:
		total_weight += maxi(1, int(_get_property(enemy_def, "weight", 1)))

	var random_service = get_node_or_null("/root/RandomService")
	var roll := 0
	if random_service != null:
		roll = random_service.randi_range_value(1, total_weight)
	else:
		roll = randi_range(1, total_weight)

	var cursor := 0
	for enemy_def in candidates:
		cursor += maxi(1, int(_get_property(enemy_def, "weight", 1)))
		if roll <= cursor:
			return enemy_def

	return candidates.back()


func build_spawn_plan(floor_index: int, cells: Array[Vector2i], count: int) -> Array:
	var plan: Array = []
	var available_cells: Array = cells.duplicate()
	var random_service = get_node_or_null("/root/RandomService")
	if random_service != null:
		available_cells = random_service.shuffle_copy(available_cells)

	for index in range(mini(count, available_cells.size())):
		var enemy_def = pick_enemy_for_floor(floor_index)
		if enemy_def == null:
			break
		plan.append({
			"def": enemy_def,
			"cell": available_cells[index],
		})

	spawn_plan_created.emit(floor_index, plan)
	return plan


func _get_property(object, property_name: String, fallback):
	if object != null and _has_property(object, property_name):
		return object.get(property_name)
	return fallback


func _has_property(object, property_name: String) -> bool:
	if object == null or not object.has_method("get_property_list"):
		return false

	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
