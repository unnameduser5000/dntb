class_name EnemyPlanner
extends Node

const ActionDefScript := preload("res://scripts/data/ActionDef.gd")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

@export var enemies_are_static: bool = true
@export var move_action: Resource
@export var attack_action: Resource

var attack_actions_by_id: Dictionary = {}

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
		"boss_tactician":
			return _decide_boss_tactician(enemy, state)
		"line_keeper":
			return _decide_line_keeper(enemy, state)
		"slime_god":
			return _decide_slime_god(enemy, state)
		"melee_chaser":
			return _decide_melee_chaser(enemy, state)
		_:
			return _decide_melee_chaser(enemy, state)


func _decide_static_attack(enemy, state):
	if _can_use_surrounding_attack(enemy, state):
		return _make_attack(enemy, Vector2i.UP)
	var attack_dir := _get_attack_dir_to_player(enemy, state)
	if attack_dir == Vector2i.ZERO:
		return null

	return _make_attack(enemy, attack_dir)


func _decide_melee_chaser(enemy, state):
	if _can_use_surrounding_attack(enemy, state):
		return _make_attack(enemy, Vector2i.UP)
	var attack_dir := _get_attack_dir_to_player(enemy, state)
	if attack_dir != Vector2i.ZERO:
		return _make_attack(enemy, attack_dir)

	if move_action == null:
		return null

	var move_dir := _get_path_step_towards(enemy.grid_pos, state.player.grid_pos, state.grid, state)
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
	if not _can_enemy_enter_cell(state, enemy.grid_pos + move_dir):
		return null

	var move = ActionInstanceScript.new()
	move.actor = enemy
	move.def = move_action
	move.chosen_dir = move_dir
	return move


func _decide_slime_god(enemy, state):
	if enemy == null or state == null or state.player == null:
		return null
	var distance: int = _manhattan(enemy.grid_pos, state.player.grid_pos)
	var spin_action = attack_actions_by_id.get("spin_axe")
	var thrust_action = attack_actions_by_id.get("charge_thrust")
	var bind_action = attack_actions_by_id.get("slime_bind")
	if spin_action != null and _get_attack_cells(enemy.grid_pos, Vector2i.UP, spin_action, state.grid).has(state.player.grid_pos):
		return _make_specific_attack(enemy, Vector2i.UP, spin_action)
	if distance <= 2 and thrust_action != null:
		var thrust_dir := _get_attack_dir_for_action(enemy, state, thrust_action)
		if thrust_dir != Vector2i.ZERO:
			return _make_specific_attack(enemy, thrust_dir, thrust_action)
	if distance <= 3 and bind_action != null:
		var bind_dir := _get_attack_dir_for_action(enemy, state, bind_action)
		if bind_dir != Vector2i.ZERO:
			return _make_specific_attack(enemy, bind_dir, bind_action)
	if move_action == null:
		return null
	var move_dir := _get_path_step_towards(enemy.grid_pos, state.player.grid_pos, state.grid, state)
	if move_dir == Vector2i.ZERO:
		return null
	var move = ActionInstanceScript.new()
	move.actor = enemy
	move.def = move_action
	move.chosen_dir = move_dir
	return move


func _decide_boss_tactician(enemy, state):
	if enemy == null or state == null or state.player == null:
		return null
	var distance: int = _manhattan(enemy.grid_pos, state.player.grid_pos)
	var sweep_action = attack_actions_by_id.get("great_sweep")
	var dash_action = attack_actions_by_id.get("dash")
	var jump_action = attack_actions_by_id.get("jump")
	var heavy_attack = attack_actions_by_id.get("charge_thrust")
	if sweep_action != null:
		var sweep_dir := _get_attack_dir_for_action(enemy, state, sweep_action)
		if sweep_dir != Vector2i.ZERO:
			return _make_specific_attack(enemy, sweep_dir, sweep_action)
	if heavy_attack != null and distance <= 3:
		var heavy_dir := _get_attack_dir_for_action(enemy, state, heavy_attack)
		if heavy_dir != Vector2i.ZERO:
			return _make_specific_attack(enemy, heavy_dir, heavy_attack)
	if dash_action != null and distance >= 2 and distance <= 4:
		var dash_dir := _line_step_toward(enemy.grid_pos, state.player.grid_pos)
		if dash_dir != Vector2i.ZERO and _can_dash_land(enemy.grid_pos, dash_dir, state):
			return _make_specific_attack(enemy, dash_dir, dash_action)
	if jump_action != null and distance >= 2:
		var behind_cell: Vector2i = state.player.grid_pos - state.player.facing
		if _can_jump_behind_target(enemy, behind_cell, state):
			var jump_dir: Vector2i = behind_cell - enemy.grid_pos
			if absi(jump_dir.x) + absi(jump_dir.y) <= max(1, int(jump_action.range)):
				return _make_specific_attack(enemy, jump_dir.sign(), jump_action)
	if move_action == null:
		return null
	var move_dir := _get_path_step_towards(enemy.grid_pos, state.player.grid_pos, state.grid, state)
	if move_dir == Vector2i.ZERO:
		return null
	var move = ActionInstanceScript.new()
	move.actor = enemy
	move.def = move_action
	move.chosen_dir = move_dir
	return move


func _can_dash_land(origin: Vector2i, direction: Vector2i, state) -> bool:
	if state == null or state.grid == null:
		return false
	for step in range(1, 3):
		var cell := origin + direction * step
		if not state.grid.is_inside(cell):
			return false
		if step < 2 and state.grid.is_blocked(cell):
			return false
		if step == 2 and not _can_enemy_enter_cell(state, cell):
			return false
	return true


func _can_jump_behind_target(enemy, behind_cell: Vector2i, state) -> bool:
	if enemy == null or state == null or state.grid == null:
		return false
	if behind_cell == enemy.grid_pos or not state.grid.is_inside(behind_cell):
		return false
	return _can_enemy_enter_cell(state, behind_cell)


func _can_enemy_enter_cell(state, cell: Vector2i) -> bool:
	if state == null or state.grid == null:
		return false
	if bool(state.is_world_slice) and state.grid.has_method("can_enemy_enter"):
		return state.grid.can_enemy_enter(cell)
	return state.grid.can_enter(cell)


func _can_use_surrounding_attack(enemy, state) -> bool:
	if enemy == null or state == null or state.player == null:
		return false
	var enemy_attack = _attack_action_for_enemy(enemy)
	if enemy_attack == null or String(enemy_attack.id) != "spin_axe":
		return false
	return _get_attack_cells(enemy.grid_pos, Vector2i.UP, enemy_attack, state.grid).has(state.player.grid_pos)


func _get_attack_dir_to_player(enemy, state) -> Vector2i:
	var enemy_attack = _attack_action_for_enemy(enemy)
	if enemy_attack == null:
		return Vector2i.ZERO
	if String(enemy_attack.id) == "spin_axe":
		var surrounding_cells := _get_attack_cells(enemy.grid_pos, Vector2i.UP, enemy_attack, state.grid)
		if surrounding_cells.has(state.player.grid_pos):
			return Vector2i.UP
		return Vector2i.ZERO

	var player = state.player
	for raw_direction in CARDINAL_DIRECTIONS:
		var direction: Vector2i = raw_direction
		var cells := _get_attack_cells(enemy.grid_pos, direction, enemy_attack, state.grid)
		if cells.has(player.grid_pos):
			return direction

	return Vector2i.ZERO


func _make_attack(enemy, direction: Vector2i):
	var enemy_attack = _attack_action_for_enemy(enemy)
	if enemy_attack == null:
		return null
	return _make_specific_attack(enemy, direction, enemy_attack)


func _make_specific_attack(enemy, direction: Vector2i, action_def):
	if enemy == null or action_def == null:
		return null
	var attack = ActionInstanceScript.new()
	attack.actor = enemy
	attack.def = action_def
	attack.chosen_dir = direction
	return attack


func _get_attack_dir_for_action(enemy, state, action_def) -> Vector2i:
	if enemy == null or state == null or state.player == null or action_def == null:
		return Vector2i.ZERO
	for raw_direction in CARDINAL_DIRECTIONS:
		var direction: Vector2i = raw_direction
		var cells := _get_attack_cells(enemy.grid_pos, direction, action_def, state.grid)
		if cells.has(state.player.grid_pos):
			return direction
	return Vector2i.ZERO


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _attack_action_for_enemy(enemy):
	if enemy == null or enemy.def == null:
		return attack_action
	var action_id := String(enemy.def.attack_action_id)
	if action_id.is_empty():
		return attack_action
	return attack_actions_by_id.get(action_id, attack_action)

func describe_action(action) -> String:
	if action == null:
		return ""
	if action.actor != null and action.actor.def != null and int(action.actor.def.atk) <= 0:
		var dir_name := _dir_name(action.chosen_dir)
		return "%s 正在向%s靠近（不会主动造成伤害）" % [action.actor.def.display_name, dir_name]

	if action.def.id == "attack":
		return "%s 准备向%s攻击" % [action.actor.def.display_name, _dir_name(action.chosen_dir)]
	if action.def.id == "spin_axe":
		return "%s 准备拍打周围一圈。" % action.actor.def.display_name

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
	for cell in get_threat_labels(state).keys():
		var threat_cell: Vector2i = cell
		if not result.has(threat_cell):
			result.append(threat_cell)
	return result


func get_threat_labels(state) -> Dictionary:
	var result: Dictionary = {}
	if state == null or state.grid == null:
		return result
	for action in preview_enemy_actions(state):
		if action == null or action.actor == null or action.def == null:
			continue
		if action.actor.def != null and int(action.actor.def.atk) <= 0:
			continue
		if int(action.def.kind) == int(ActionDefScript.ActionKind.ATTACK):
			for cell in _get_attack_cells(action.actor.grid_pos, action.chosen_dir, action.def, state.grid):
				if not result.has(cell):
					result[cell] = _warning_label_for_action(action.def)
			continue
		if int(action.def.kind) != int(ActionDefScript.ActionKind.MOVE):
			continue
		var target_cell: Vector2i = action.actor.grid_pos + action.chosen_dir * max(1, int(action.def.range))
		if not state.grid.is_inside(target_cell) or state.grid.is_blocked(target_cell):
			continue
		for followup_entry in _project_followup_threat_for_enemy(action.actor, target_cell, state):
			var followup_cell: Vector2i = Vector2i(followup_entry.get("cell", Vector2i(-1, -1)))
			if followup_cell == Vector2i(-1, -1) or result.has(followup_cell):
				continue
			result[followup_cell] = String(followup_entry.get("label", "逼近预警"))

	return result


func _project_followup_threat_for_enemy(enemy, target_cell: Vector2i, state) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if enemy == null:
		return result
	match String(enemy.def.ai_type):
		"boss_tactician":
			var sweep_action = attack_actions_by_id.get("great_sweep")
			var thrust_action = attack_actions_by_id.get("charge_thrust")
			for action_def in [sweep_action, thrust_action]:
				if action_def == null:
					continue
				for cell in _project_attack_threat_from_cell(target_cell, action_def, state.grid):
					_append_threat_entry(result, cell, _warning_label_for_action(action_def))
			return result
		"slime_god":
			for action_def in [attack_actions_by_id.get("spin_axe"), attack_actions_by_id.get("charge_thrust"), attack_actions_by_id.get("slime_bind")]:
				if action_def == null:
					continue
				for cell in _project_attack_threat_from_cell(target_cell, action_def, state.grid):
					_append_threat_entry(result, cell, _warning_label_for_action(action_def))
			return result
		_:
			var followup_attack = _attack_action_for_enemy(enemy)
			if followup_attack == null:
				return result
			for cell in _project_attack_threat_from_cell(target_cell, followup_attack, state.grid):
				_append_threat_entry(result, cell, _warning_label_for_action(followup_attack))
			return result


func _append_threat_entry(entries: Array[Dictionary], cell: Vector2i, label: String) -> void:
	for entry in entries:
		if Vector2i(entry.get("cell", Vector2i(-1, -1))) == cell:
			return
	entries.append({
		"cell": cell,
		"label": label,
	})


func _warning_label_for_action(action_def) -> String:
	if action_def == null:
		return "危险预警"
	match String(action_def.id):
		"attack":
			return "攻击预警"
		"spin_axe":
			return "环扫预警"
		"great_sweep":
			return "横扫预警"
		"charge_thrust":
			return "冲刺预警"
		"slime_bind":
			return "黏缚预警"
		"dash":
			return "冲锋预警"
		"jump":
			return "跳袭预警"
		_:
			return "%s预警" % String(action_def.display_name if action_def.get("display_name") != null else action_def.id)


func _project_attack_threat_from_cell(origin: Vector2i, action_def, grid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if action_def == null:
		return result
	if String(action_def.id) == "spin_axe":
		return _get_attack_cells(origin, Vector2i.UP, action_def, grid)
	for raw_direction in CARDINAL_DIRECTIONS:
		for cell in _get_attack_cells(origin, raw_direction, action_def, grid):
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
	var enemy_attack = _attack_action_for_enemy(enemy)
	if enemy == null or enemy_attack == null:
		return result

	for raw_direction in CARDINAL_DIRECTIONS:
		var direction: Vector2i = raw_direction
		for cell in _get_attack_cells(enemy.grid_pos, direction, enemy_attack, state.grid):
			if not result.has(cell):
				result.append(cell)

	return result

func _get_attack_cells(origin: Vector2i, direction: Vector2i, action_def, grid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if direction == Vector2i.ZERO or action_def == null:
		return result
	var left := Vector2i(direction.y, -direction.x)
	var right := Vector2i(-direction.y, direction.x)

	if action_def.id == "sweep":
		for cell in [origin + left, origin + direction, origin + right]:
			_add_attack_cell(result, cell, grid)
		return result

	if action_def.id == "great_sweep":
		for cell in [origin + left, origin + direction, origin + right]:
			_add_attack_cell(result, cell, grid)
		return result

	if action_def.id == "cross_attack":
		for cell in [origin + Vector2i.UP, origin + Vector2i.DOWN, origin + Vector2i.LEFT, origin + Vector2i.RIGHT]:
			_add_attack_cell(result, cell, grid)
		return result

	if action_def.id == "hammer_smash":
		for cell in [
			origin + direction + left,
			origin + direction,
			origin + direction + right,
			origin + direction * 2 + left,
			origin + direction * 2,
			origin + direction * 2 + right,
		]:
			_add_attack_cell(result, cell, grid)
		return result

	if action_def.id == "spin_axe":
		for y in range(-1, 2):
			for x in range(-1, 2):
				if x == 0 and y == 0:
					continue
				_add_attack_cell(result, origin + Vector2i(x, y), grid)
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

const MAX_ENEMY_BFS_DISTANCE := 20

func _get_path_step_towards(from_cell: Vector2i, to_cell: Vector2i, grid, state = null) -> Vector2i:
	if from_cell == to_cell:
		return Vector2i.ZERO

	if _manhattan(from_cell, to_cell) > MAX_ENEMY_BFS_DISTANCE:
		return _get_greedy_step_towards(from_cell, to_cell, grid, state)

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
			if state != null and next_cell != to_cell and not _can_enemy_enter_cell(state, next_cell):
				continue

			visited[next_cell] = true
			first_step[next_cell] = direction if current == from_cell else first_step[current]
			if next_cell == to_cell:
				var step_to_target: Vector2i = first_step[next_cell]
				return step_to_target

			frontier.append(next_cell)

	return _get_greedy_step_towards(from_cell, to_cell, grid, state)

func _get_greedy_step_towards(from_cell: Vector2i, to_cell: Vector2i, grid, state = null) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for raw_direction in CARDINAL_DIRECTIONS:
		candidates.append(raw_direction)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _manhattan(from_cell + a, to_cell) < _manhattan(from_cell + b, to_cell)
	)

	for direction in candidates:
		var cell: Vector2i = from_cell + direction
		if not grid.can_enter(cell):
			continue
		if state != null and not _can_enemy_enter_cell(state, cell):
			continue
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
