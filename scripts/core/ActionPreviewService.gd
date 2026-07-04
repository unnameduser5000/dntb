class_name ActionPreviewService
extends RefCounted

const ActionDefScript := preload("res://scripts/data/ActionDef.gd")
const ActionTraceRecorderScript := preload("res://scripts/core/ActionTraceRecorder.gd")

var _trace_recorder = ActionTraceRecorderScript.new()

func setup() -> void:
	pass


# Preview builder for the already-resolved action queue.
# It reads the current GameState as reference and projects move / attack cells
# without feeding results back into live combat state.
func build_preview_from_actions(actions: Array, state) -> Dictionary:
	var move_cells: Array[Vector2i] = []
	var attack_cells: Array[Vector2i] = []
	var trace_symbols: Array[StringName] = []
	var trace_entries: Array = []
	if state == null or state.player == null:
		return {
			"move_cells": move_cells,
			"attack_cells": attack_cells,
			"trace_symbols": trace_symbols,
		}

	var preview_pos: Vector2i = state.player.grid_pos
	var preview_facing: Vector2i = state.player.facing
	# Preview replays the resolved action queue using a local facing snapshot.
	# This mirrors runtime direction resolution closely enough to preview
	# movement/attack cells while keeping the real GameState unchanged.
	for action in actions:
		if action == null or action.def == null:
			continue

		var actor_before_cell: Vector2i = preview_pos
		var actor_before_facing: Vector2i = preview_facing
		var action_def = action.def
		var action_id := String(action_def.id)
		var action_dir: Vector2i = _resolve_action_direction(action, preview_facing)
		var after_pos := preview_pos

		match int(action_def.kind):
			ActionDefScript.ActionKind.MOVE:
				if action_id == "move_key" and action_dir != Vector2i.ZERO:
					preview_facing = action_dir
				if action_id == "jump":
					after_pos = _preview_jump(state, preview_pos, action_dir, move_cells, max(1, int(action_def.range)))
				else:
					after_pos = _preview_move(state, preview_pos, action_dir, move_cells, attack_cells, max(1, int(action_def.range)))
			ActionDefScript.ActionKind.ATTACK:
				if action.chosen_dir != Vector2i.ZERO and action_dir != Vector2i.ZERO:
					preview_facing = action_dir
				_add_unique_cells(attack_cells, _preview_attack_cells(state, preview_pos, action_dir, action_def))
			ActionDefScript.ActionKind.TURN:
				preview_facing = _preview_turn(preview_facing, action_id)
			ActionDefScript.ActionKind.INTERACT:
				pass
			_:
				pass

		var symbol := _trace_recorder.resolve_symbol_from_execution(
			action,
			actor_before_cell,
			after_pos,
			actor_before_facing,
			preview_facing
		)
		if symbol != &"":
			var move_delta := after_pos - actor_before_cell
			trace_symbols.append(symbol)
			trace_entries.append({
				"action_id": action_id,
				"symbol": symbol,
				"moved": move_delta != Vector2i.ZERO,
				"from_cell": actor_before_cell,
				"to_cell": after_pos,
				"move_delta": move_delta,
				"move_dir": _trace_recorder.normalize_move_direction(move_delta),
			})
		preview_pos = after_pos

	return {
		"move_cells": move_cells,
		"attack_cells": attack_cells,
		"trace_symbols": trace_symbols,
	}


func _resolve_action_direction(action, preview_facing: Vector2i) -> Vector2i:
	# Preview follows the same direction priority as runtime ActionResolver:
	# chosen_dir first, then backward-from-facing for move_back, then facing.
	if action == null or action.def == null:
		return preview_facing
	if action.chosen_dir != Vector2i.ZERO:
		return action.chosen_dir
	if String(action.def.id) == "step_left":
		return Vector2i(preview_facing.y, -preview_facing.x)
	if String(action.def.id) == "step_right":
		return Vector2i(-preview_facing.y, preview_facing.x)
	if String(action.def.id) == "move_back":
		return -preview_facing
	return preview_facing


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


func _preview_jump(state, start_pos: Vector2i, direction: Vector2i, move_cells: Array[Vector2i], distance: int = 1) -> Vector2i:
	if direction == Vector2i.ZERO:
		return start_pos

	var landing_cell: Vector2i = start_pos + direction * max(1, distance)
	if not state.grid.can_enter(landing_cell):
		return start_pos

	_add_unique_cell(move_cells, landing_cell)
	return landing_cell


func _preview_turn(facing: Vector2i, action_id: String) -> Vector2i:
	match action_id:
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
	var left := Vector2i(direction.y, -direction.x)
	var right := Vector2i(-direction.y, direction.x)

	if action_def.id == "sweep" or action_def.id == "great_sweep":
		for cell in [origin + left, origin + direction, origin + right]:
			_add_preview_attack_cell(state, cells, cell)
		return cells

	if action_def.id == "cross_attack":
		for cell in [origin + Vector2i.UP, origin + Vector2i.DOWN, origin + Vector2i.LEFT, origin + Vector2i.RIGHT]:
			_add_preview_attack_cell(state, cells, cell)
		return cells

	if action_def.id == "hammer_smash":
		for cell in [
			origin + direction + left,
			origin + direction,
			origin + direction + right,
			origin + direction * 2 + left,
			origin + direction * 2,
			origin + direction * 2 + right,
		]:
			_add_preview_attack_cell(state, cells, cell)
		return cells

	if action_def.id == "spin_axe":
		for y in range(-1, 2):
			for x in range(-1, 2):
				if x == 0 and y == 0:
					continue
				_add_preview_attack_cell(state, cells, origin + Vector2i(x, y))
		return cells

	if action_def.id == "bow_shot":
		for step in range(1, max(1, int(action_def.range)) + 1):
			var cell: Vector2i = origin + direction * step
			if not state.grid.is_inside(cell) or state.grid.is_blocked(cell):
				break
			var target = state.grid.get_actor(cell)
			if target != null and target != state.player and target.team != state.player.team:
				cells.append(cell)
				return cells
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


func _add_unique_cells(target: Array[Vector2i], cells: Array[Vector2i]) -> void:
	for cell in cells:
		_add_unique_cell(target, cell)


func _add_unique_cell(target: Array[Vector2i], cell: Vector2i) -> void:
	if not target.has(cell):
		target.append(cell)
