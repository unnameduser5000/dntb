class_name ActionPreviewService
extends RefCounted

const KEY_DIRECTIONS := {
	"U": Vector2i.UP,
	"D": Vector2i.DOWN,
	"L": Vector2i.LEFT,
	"R": Vector2i.RIGHT,
}

var action_by_id: Dictionary = {}


func setup(actions: Dictionary) -> void:
	action_by_id = actions


# 只做“预测显示”，不改变真实 GameState。
# 注意：这里应尽量与 ActionResolver 的移动/攻击规则保持一致；
# 后续如果行动规则复杂化，可以进一步抽成共享的 ActionQuery/Rules。
func build_preview(token_ids: Array, state) -> Dictionary:
	var move_cells: Array[Vector2i] = []
	var attack_cells: Array[Vector2i] = []
	if state == null or state.player == null:
		return {
			"move_cells": move_cells,
			"attack_cells": attack_cells,
		}

	var preview_pos: Vector2i = state.player.grid_pos
	var preview_facing: Vector2i = state.player.facing
	for raw_token_id in token_ids:
		var token_id := String(raw_token_id)
		if KEY_DIRECTIONS.has(token_id):
			var move_dir: Vector2i = KEY_DIRECTIONS.get(token_id, Vector2i.ZERO)
			preview_facing = move_dir
			preview_pos = _preview_move(state, preview_pos, move_dir, move_cells, attack_cells)
			continue

		var action_def = action_by_id.get(token_id)
		if action_def == null:
			continue

		match int(action_def.kind):
			ActionDef.ActionKind.MOVE:
				var move_dir: Vector2i = preview_facing
				if token_id == "move_back":
					move_dir = -preview_facing
				preview_pos = _preview_move(state, preview_pos, move_dir, move_cells, attack_cells, max(1, int(action_def.range)))
			ActionDef.ActionKind.ATTACK:
				if token_id == "lunge":
					var lunge_cells := _preview_attack_cells(state, preview_pos, preview_facing, action_def)
					_add_unique_cells(attack_cells, lunge_cells)
					if not _preview_hits_enemy(state, lunge_cells):
						preview_pos = _preview_move(state, preview_pos, preview_facing, move_cells, attack_cells, max(1, int(action_def.range)))
				else:
					_add_unique_cells(attack_cells, _preview_attack_cells(state, preview_pos, preview_facing, action_def))
			ActionDef.ActionKind.TURN:
				preview_facing = _preview_turn(preview_facing, token_id)
			_:
				pass

	return {
		"move_cells": move_cells,
		"attack_cells": attack_cells,
	}


func _preview_move(state, start_pos: Vector2i, direction: Vector2i, move_cells: Array[Vector2i], attack_cells: Array[Vector2i], distance: int = 1) -> Vector2i:
	if direction == Vector2i.ZERO:
		return start_pos

	var current_pos := start_pos
	for _step in range(distance):
		var target_cell: Vector2i = current_pos + direction
		if state.grid.is_blocked(target_cell):
			return current_pos

		var blocking_actor = state.grid.get_actor(target_cell)
		if blocking_actor != null and blocking_actor != state.player:
			if blocking_actor.team != state.player.team:
				_add_unique_cell(attack_cells, target_cell)
				_add_unique_cell(move_cells, target_cell)
				current_pos = target_cell
			return current_pos

		_add_unique_cell(move_cells, target_cell)
		current_pos = target_cell

	return current_pos


func _preview_turn(facing: Vector2i, token_id: String) -> Vector2i:
	match token_id:
		"turn_left":
			return Vector2i(facing.y, -facing.x)
		"turn_right":
			return Vector2i(-facing.y, facing.x)
		_:
			return facing


func _preview_attack_cells(state, origin: Vector2i, direction: Vector2i, action_def) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if direction == Vector2i.ZERO or action_def == null:
		return cells

	if action_def.id == "sweep":
		var left := Vector2i(direction.y, -direction.x)
		var right := Vector2i(-direction.y, direction.x)
		for cell in [origin + left, origin + direction, origin + right]:
			_add_preview_attack_cell(state, cells, cell)
		return cells

	for step in range(1, max(1, int(action_def.range)) + 1):
		var cell: Vector2i = origin + direction * step
		if not state.grid.is_inside(cell) or state.grid.is_blocked(cell):
			break
		cells.append(cell)

	return cells


func _add_preview_attack_cell(state, cells: Array[Vector2i], cell: Vector2i) -> void:
	if not state.grid.is_inside(cell) or state.grid.is_blocked(cell):
		return
	if not cells.has(cell):
		cells.append(cell)


func _preview_hits_enemy(state, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var actor = state.grid.get_actor(cell)
		if actor != null and actor.team != state.player.team:
			return true
	return false


func _add_unique_cells(target: Array[Vector2i], cells: Array[Vector2i]) -> void:
	for cell in cells:
		_add_unique_cell(target, cell)


func _add_unique_cell(target: Array[Vector2i], cell: Vector2i) -> void:
	if not target.has(cell):
		target.append(cell)
