class_name WorldSliceController
extends RefCounted

## Minimal persistent world-slice scaffold.
## The slice is intentionally fixed and small in scope:
## - one large shared grid
## - one player
## - a few obstacles
## - a few test enemies
## - no room chain / reward flow

const GameStateScript := preload("res://scripts/core/GameState.gd")
const GridModelScript := preload("res://scripts/core/GridModel.gd")
const GridMapDataScript := preload("res://scripts/core/GridMapData.gd")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")
const GridItemStateScript := preload("res://scripts/runtime/GridItemState.gd")
const FOVServiceScript := preload("res://scripts/core/FOVService.gd")
const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const IMPACT_SHIELD := preload("res://data/weapons/impact_shield.tres")

const WORLD_GRID_SIZE := Vector2i(30, 30)
const PLAYER_START := Vector2i(4, 4)
const ENEMY_SPAWNS := [Vector2i(8, 4), Vector2i(4, 8), Vector2i(11, 6), Vector2i(6, 11)]
const BLOCKED_RECTANGLES := [
	Rect2i(9, 2, 1, 4),
	Rect2i(13, 7, 4, 1),
	Rect2i(2, 12, 5, 1),
	Rect2i(18, 3, 2, 3),
]
const PLACEHOLDER_CELL := Vector2i(10, 10)

var _next_actor_id := 0
var _next_item_id := 1000
var _fov_service := FOVServiceScript.new()


func create_demo_state() -> GameState:
	_next_actor_id = 0
	_next_item_id = 1000
	var state = GameStateScript.new()
	state.grid = GridModelScript.new()
	state.grid.setup(WORLD_GRID_SIZE.x, WORLD_GRID_SIZE.y)
	state.map_data = GridMapDataScript.new()
	state.map_data.setup(WORLD_GRID_SIZE.x, WORLD_GRID_SIZE.y)
	state.room_index = 0
	state.room_name = "World Slice"
	state.map_node_index = 0
	state.map_node_kind = "world_slice"
	state.map_node_label = "World Slice"
	state.exit_cell = Vector2i(-99, -99)
	state.is_safe_training = false
	state.is_world_slice = true
	state.visible_cells.clear()
	state.explored_cells.clear()
	state.reveal_all_debug = false
	state.fov_radius = 6
	var empty_weapon_techniques: Array[String] = []
	state.set_unlocked_weapon_technique_ids(empty_weapon_techniques)
	_add_world_bounds(state.grid)
	_add_world_bounds_to_map_data(state.map_data)
	_add_world_obstacles(state.grid)
	_add_world_obstacles_to_map_data(state.map_data)
	_add_placeholder_prop(state)

	var player = _add_actor(state, PLAYER_DEF, PLAYER_START, Vector2i.RIGHT)
	player.active_weapon = IMPACT_SHIELD

	for index in range(ENEMY_SPAWNS.size()):
		var enemy_def = SLIME_DEF if index < 3 else BRUTE_DEF
		_add_actor(state, enemy_def, ENEMY_SPAWNS[index], Vector2i.LEFT)

	state.add_message("World slice ready.")
	recompute_visibility(state, "init")
	return state


func get_visible_cells(state) -> Array[Vector2i]:
	if state == null:
		return []
	return state.visible_cells.duplicate()


func get_explored_cells(state) -> Array[Vector2i]:
	if state == null:
		return []
	return state.explored_cells.duplicate()


func recompute_visibility(state, reason: String = "manual") -> void:
	if state == null or state.player == null:
		return

	if state.reveal_all_debug:
		_reveal_all(state, reason)
		return

	if state.map_data == null:
		return

	var visible := _fov_service.compute_fov(state.player.grid_pos, int(state.fov_radius), state.map_data)
	state.visible_cells = visible.duplicate()
	for cell in visible:
		if not state.explored_cells.has(cell):
			state.explored_cells.append(cell)
	state.last_visibility_recompute_reason = reason
	_update_actor_visibility(state)


func set_reveal_all_debug(state, enabled: bool, reason: String = "debug_toggle") -> void:
	if state == null:
		return
	state.reveal_all_debug = enabled
	recompute_visibility(state, reason)


func reset_world_slice(state) -> void:
	if state == null:
		return
	_next_actor_id = 0
	_next_item_id = 1000
	state.actors.clear()
	state.player = null
	state.turn_count = 0
	state.phase = "planning"
	state.battle_finished = false
	state.victory = false
	if state.grid != null:
		state.grid.setup(WORLD_GRID_SIZE.x, WORLD_GRID_SIZE.y)
	if state.map_data != null:
		state.map_data.setup(WORLD_GRID_SIZE.x, WORLD_GRID_SIZE.y)
	state.items_at.clear()
	state.visible_cells.clear()
	state.explored_cells.clear()
	state.preview_move_cells.clear()
	state.preview_attack_cells.clear()
	state.danger_cells.clear()
	state.enemy_intents.clear()
	state.messages.clear()
	state.last_visibility_recompute_reason = "reset"
	if state.action_trace != null:
		state.action_trace.clear()
	state.clear_weapon_combo_matches()
	var reset_weapon_techniques: Array[String] = []
	state.set_unlocked_weapon_technique_ids(reset_weapon_techniques)
	_add_world_bounds(state.grid)
	_add_world_bounds_to_map_data(state.map_data)
	_add_world_obstacles(state.grid)
	_add_world_obstacles_to_map_data(state.map_data)
	_add_placeholder_prop(state)
	var player = _add_actor(state, PLAYER_DEF, PLAYER_START, Vector2i.RIGHT)
	player.active_weapon = IMPACT_SHIELD
	for index in range(ENEMY_SPAWNS.size()):
		var enemy_def = SLIME_DEF if index < 3 else BRUTE_DEF
		_add_actor(state, enemy_def, ENEMY_SPAWNS[index], Vector2i.LEFT)
	state.add_message("World slice ready.")
	recompute_visibility(state, "reset")


func on_player_moved(state, _from_cell: Vector2i = Vector2i.ZERO, _to_cell: Vector2i = Vector2i.ZERO) -> void:
	recompute_visibility(state, "player_moved")


func on_actor_moved(state, _actor, _from_cell: Vector2i = Vector2i.ZERO, _to_cell: Vector2i = Vector2i.ZERO) -> void:
	if state == null:
		return
	if bool(state.is_world_slice) and _actor == state.player:
		recompute_visibility(state, "player_moved")


func _add_world_bounds(grid) -> void:
	for x in range(WORLD_GRID_SIZE.x):
		grid.add_blocked(Vector2i(x, 0))
		grid.add_blocked(Vector2i(x, WORLD_GRID_SIZE.y - 1))
	for y in range(WORLD_GRID_SIZE.y):
		grid.add_blocked(Vector2i(0, y))
		grid.add_blocked(Vector2i(WORLD_GRID_SIZE.x - 1, y))


func _add_world_bounds_to_map_data(map_data) -> void:
	for x in range(WORLD_GRID_SIZE.x):
		map_data.add_blocked(Vector2i(x, 0), true)
		map_data.add_blocked(Vector2i(x, WORLD_GRID_SIZE.y - 1), true)
	for y in range(WORLD_GRID_SIZE.y):
		map_data.add_blocked(Vector2i(0, y), true)
		map_data.add_blocked(Vector2i(WORLD_GRID_SIZE.x - 1, y), true)


func _add_world_obstacles(grid) -> void:
	for rect in BLOCKED_RECTANGLES:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				grid.add_blocked(Vector2i(x, y))


func _add_world_obstacles_to_map_data(map_data) -> void:
	for rect in BLOCKED_RECTANGLES:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				map_data.add_blocked(Vector2i(x, y), true)


func _add_placeholder_prop(state) -> void:
	var prop = GridItemStateScript.new()
	prop.setup_grid_item(_next_item_id, "world_terminal", GridItemStateScript.GridItemKind.PROP, PLACEHOLDER_CELL, false)
	_next_item_id += 1
	prop.display_name = "World Terminal Placeholder"
	prop.tags.append("world_slice_placeholder")
	state.grid.place_item(prop, PLACEHOLDER_CELL)


func _add_actor(state, actor_def, cell: Vector2i, facing: Vector2i):
	var actor = ActorStateScript.new()
	actor.setup(_next_actor_id, actor_def, cell)
	_next_actor_id += 1
	actor.facing = facing
	actor.active_weapon = IMPACT_SHIELD if actor_def == PLAYER_DEF else null
	state.grid.place_actor(actor, cell)
	state.add_actor(actor)
	return actor


func _reveal_all(state, reason: String) -> void:
	if state == null or state.map_data == null:
		return
	var visible: Array[Vector2i] = []
	var size: Vector2i = state.map_data.get_size()
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			visible.append(cell)
			if not state.explored_cells.has(cell):
				state.explored_cells.append(cell)
	state.visible_cells = visible
	state.last_visibility_recompute_reason = reason
	_update_actor_visibility(state)


func _update_actor_visibility(state) -> void:
	if state == null or state.grid == null:
		return
	var visible_set: Dictionary = {}
	if state.reveal_all_debug:
		for cell in state.visible_cells:
			visible_set[cell] = true
	else:
		for cell in state.visible_cells:
			visible_set[cell] = true
	for actor in state.actors:
		if actor == null:
			continue
		var is_visible := visible_set.has(actor.grid_pos)
		if actor.has_method("set"):
			actor.set("revealed", is_visible)
