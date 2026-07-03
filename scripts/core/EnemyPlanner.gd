class_name EnemyPlanner
extends Node

const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

@export var enemies_are_static: bool = true
@export var move_action: Resource
@export var attack_action: Resource

const CARDINAL_DIRECTIONS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

func make_enemy_actions(state) -> Array:
	var result: Array = []
	if enemies_are_static:
		return result

	for actor in state.actors:
		if actor.team != "enemy" or actor.is_dead():
			continue
		if not _is_enemy_active_for_state(actor, state):
			continue

		var action = decide_enemy_action(actor, state)
		if action != null:
			result.append(action)

	return result

func preview_enemy_actions(state) -> Array:
	var result: Array = []
	for actor in state.actors:
		if actor.team != "enemy" or actor.is_dead():
			continue
		if not _is_enemy_active_for_state(actor, state):
			continue

		var action = decide_enemy_action(actor, state)
		if action != null:
			result.append(action)

	return result

func decide_enemy_action(enemy, state):
	if state == null or state.player == null:
		return null

	match String(enemy.def.ai_type):
		"static":
			return _decide_static_attack(enemy, state)
		"line_keeper":
			return _decide_line_keeper(enemy, state)
		"melee_chaser":
			return _decide_melee_chaser(enemy, state)
		_:
			return _decide_melee_chaser(enemy, state)


func _decide_static_attack(enemy, state):
	var attack_dir := _get_attack_dir_to_player(enemy, state)
	if attack_dir == Vector2i.ZERO:
		return null

	return _make_attack(enemy, attack_dir)


func _decide_melee_chaser(enemy, state):
	var attack_dir := _get_attack_dir_to_player(enemy, state)
	if attack_dir != Vector2i.ZERO:
		return _make_attack(enemy, attack_dir)

	if move_action == null:
		return null

	var move_dir := _get_path_step_towards(enemy.grid_pos, state.player.grid_pos, state.grid)
	if move_dir == Vector2i.ZERO:
		return null

	var move = ActionInstanceScript.new()
	move.actor = enemy
	move.def = move_action
	move.chosen_dir = move_dir
	return move


func _decide_line_keeper(enemy, state):
	var player = state.player
	if player == null:
		return null

	var attack_dir := _get_attack_dir_to_player(enemy, state)
	if attack_dir != Vector2i.ZERO:
		return _make_attack(enemy, attack_dir)

	var same_row: bool = enemy.grid_pos.y == player.grid_pos.y
	var same_col: bool = enemy.grid_pos.x == player.grid_pos.x
	if not same_row and not same_col:
		return null
	if move_action == null:
		return null

	var move_dir := _line_step_toward(enemy.grid_pos, player.grid_pos)
	if move_dir == Vector2i.ZERO:
		return null
	if not state.grid.can_enter(enemy.grid_pos + move_dir):
		return null

	var move = ActionInstanceScript.new()
	move.actor = enemy
	move.def = move_action
	move.chosen_dir = move_dir
	return move


func _get_attack_dir_to_player(enemy, state) -> Vector2i:
	if attack_action == null:
		return Vector2i.ZERO

	var player = state.player
	for raw_direction in CARDINAL_DIRECTIONS:
		var direction: Vector2i = raw_direction
		var cells := _get_attack_cells(enemy.grid_pos, direction, attack_action, state.grid)
		if cells.has(player.grid_pos):
			return direction

	return Vector2i.ZERO


func _make_attack(enemy, direction: Vector2i):
	var attack = ActionInstanceScript.new()
	attack.actor = enemy
	attack.def = attack_action
	attack.chosen_dir = direction
	return attack

func describe_action(action) -> String:
	if action == null:
		return ""

	if action.def.id == "attack":
		return "%s 准备向%s攻击" % [action.actor.def.display_name, _dir_name(action.chosen_dir)]

	var dir_name := _dir_name(action.chosen_dir)
	return "%s 准备向%s移动" % [action.actor.def.display_name, dir_name]

func get_danger_cells(actions: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for action in actions:
		if action == null or action.def == null:
			continue

		if int(action.def.kind) == 1:
			for cell in _get_attack_cells(action.actor.grid_pos, action.chosen_dir, action.def, null):
				if not result.has(cell):
					result.append(cell)

	return result

func get_threat_cells(state) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if state == null or state.grid == null:
		return result

	for actor in state.actors:
		if actor.team != "enemy" or actor.is_dead():
			continue
		if not _is_enemy_active_for_state(actor, state):
			continue
		for cell in get_enemy_threat_cells(actor, state):
			if not result.has(cell):
				result.append(cell)

	return result


func _is_enemy_active_for_state(enemy, state) -> bool:
	if enemy == null or state == null:
		return false
	if not bool(state.is_world_slice):
		return true
	if bool(state.reveal_all_debug):
		return true
	return state.visible_cells.has(enemy.grid_pos)

func get_enemy_threat_cells(enemy, state) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if enemy == null or attack_action == null:
		return result

	for raw_direction in CARDINAL_DIRECTIONS:
		var direction: Vector2i = raw_direction
		for cell in _get_attack_cells(enemy.grid_pos, direction, attack_action, state.grid):
			if not result.has(cell):
				result.append(cell)

	return result

func _get_attack_cells(origin: Vector2i, direction: Vector2i, action_def, grid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if direction == Vector2i.ZERO or action_def == null:
		return result

	if action_def.id == "sweep":
		var left := Vector2i(direction.y, -direction.x)
		var right := Vector2i(-direction.y, direction.x)
		for cell in [origin + left, origin + direction, origin + right]:
			_add_attack_cell(result, cell, grid)
		return result

	for step in range(1, max(1, int(action_def.range)) + 1):
		var cell := origin + direction * step
		if grid != null and (not grid.is_inside(cell) or grid.is_blocked(cell)):
			break
		result.append(cell)

	return result

func _add_attack_cell(cells: Array[Vector2i], cell: Vector2i, grid) -> void:
	if grid != null and (not grid.is_inside(cell) or grid.is_blocked(cell)):
		return
	if not cells.has(cell):
		cells.append(cell)

func _get_path_step_towards(from_cell: Vector2i, to_cell: Vector2i, grid) -> Vector2i:
	if from_cell == to_cell:
		return Vector2i.ZERO

	var frontier: Array[Vector2i] = [from_cell]
	var visited := {from_cell: true}
	var first_step := {from_cell: Vector2i.ZERO}

	var frontier_index: int = 0
	while frontier_index < frontier.size():
		var current: Vector2i = frontier[frontier_index]
		frontier_index += 1
		for raw_direction in CARDINAL_DIRECTIONS:
			var direction: Vector2i = raw_direction
			var next_cell: Vector2i = current + direction
			if visited.has(next_cell):
				continue
			if not grid.is_inside(next_cell) or grid.is_blocked(next_cell):
				continue
			if next_cell != to_cell and grid.get_actor(next_cell) != null:
				continue

			visited[next_cell] = true
			first_step[next_cell] = direction if current == from_cell else first_step[current]
			if next_cell == to_cell:
				var step_to_target: Vector2i = first_step[next_cell]
				return step_to_target

			frontier.append(next_cell)

	return _get_greedy_step_towards(from_cell, to_cell, grid)

func _get_greedy_step_towards(from_cell: Vector2i, to_cell: Vector2i, grid) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for raw_direction in CARDINAL_DIRECTIONS:
		candidates.append(raw_direction)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _manhattan(from_cell + a, to_cell) < _manhattan(from_cell + b, to_cell)
	)

	for direction in candidates:
		if grid.can_enter(from_cell + direction):
			return direction

	return Vector2i.ZERO


func _line_step_toward(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = to_cell - from_cell
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if delta.x != 0 and delta.y == 0:
		return Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT
	if delta.y != 0 and delta.x == 0:
		return Vector2i.DOWN if delta.y > 0 else Vector2i.UP
	return Vector2i.ZERO

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _dir_name(dir: Vector2i) -> String:
	if dir == Vector2i.UP:
		return "上"
	if dir == Vector2i.DOWN:
		return "下"
	if dir == Vector2i.LEFT:
		return "左"
	if dir == Vector2i.RIGHT:
		return "右"
	return "原地"
