class_name ActionTraceRecorder
extends RefCounted

const ActionDefScript := preload("res://scripts/data/ActionDef.gd")
const ActionTraceEntryScript := preload("res://scripts/runtime/ActionTraceEntry.gd")

## Records a lightweight execution trace after an action has already resolved.
## This layer turns executed actions into stable trace symbols that later
## systems can read for combo recognition, debugging, and interference work.
func record_action(trace, action, actor_before_cell: Vector2i, actor_before_facing: Vector2i) -> void:
	if trace == null or action == null or action.actor == null or action.def == null:
		return

	var symbol := resolve_symbol_from_execution(
		action,
		actor_before_cell,
		action.actor.grid_pos,
		actor_before_facing,
		action.actor.facing
	)
	if symbol == &"":
		return

	var entry = ActionTraceEntryScript.new()
	entry.actor_id = int(action.actor.id)
	entry.action_id = String(action.def.id)
	entry.input_token_id = String(action.key_id)
	entry.symbol = symbol
	entry.chain_index = int(action.chain_index)
	entry.chain_id = int(action.chain_id)
	entry.from_cell = actor_before_cell
	entry.to_cell = action.actor.grid_pos
	entry.move_delta = action.actor.grid_pos - actor_before_cell
	entry.move_dir = normalize_move_direction(entry.move_delta)
	entry.moved = entry.move_delta != Vector2i.ZERO
	entry.facing_before = actor_before_facing
	entry.facing_after = action.actor.facing
	entry.tags = _build_tags(action, actor_before_cell, actor_before_facing, entry.symbol)
	trace.append_entry(entry)


func normalize_move_direction(move_delta: Vector2i) -> Vector2i:
	if move_delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if move_delta.x != 0 and move_delta.y != 0:
		# Grid combo movement matching is axis-aligned for now.
		return Vector2i.ZERO
	if move_delta.x != 0:
		return Vector2i(signi(move_delta.x), 0)
	if move_delta.y != 0:
		return Vector2i(0, signi(move_delta.y))
	return Vector2i.ZERO


## Relative movement semantics are recorded against the actor's facing before
## the action executes, but only when the move actually changes the actor's
## position.
##
## This is important for dynamic weapon-technique recognition:
## - KeyProgram may request a forward/side move
## - terrain, collisions, or effects may stop that move from really happening
## - ActionTrace should then reflect the real outcome instead of the intended
##   input, so blocked movement does not accidentally satisfy F/F-style combos
##
## Current symbol meanings:
## - F  : chosen_dir equals facing_before
## - B  : chosen_dir equals -facing_before
## - SL : chosen_dir is the world-space left side of facing_before
## - SR : chosen_dir is the world-space right side of facing_before
## - TL / TR : explicit turn actions
##
## This means ActionTrace is a record of execution semantics, not a copy of
## raw input token ids. For example, with facing_before == RIGHT:
## - input U records as SL
## - input R records as F
## - input D records as SR
## - input L records as B
##
## Important move_key edge case:
## - move_key still rotates the actor to chosen_dir before stepping
## - when that step is fully blocked, the trace drops the move instead of
##   emitting a separate "turned but failed to move" symbol
## - explicit turn tokens (TL/TR) now cover intentional reorientation, so this
##   trace stays focused on what actually resolved as movement
func resolve_symbol_from_execution(
	action,
	actor_before_cell: Vector2i,
	actor_after_cell: Vector2i,
	actor_before_facing: Vector2i,
	_actor_after_facing: Vector2i
) -> StringName:
	if action == null or action.def == null:
		return &""

	var action_id := String(action.def.id)
	var moved := actor_before_cell != actor_after_cell
	if action.def.kind == ActionDefScript.ActionKind.MOVE and not moved:
		return &""
	match action_id:
		"move_key":
			return _relative_symbol_for_direction(action.chosen_dir, actor_before_facing)
		"move_back":
			return &"B"
		"turn_left":
			return &"TL"
		"turn_right":
			return &"TR"
		_:
			if action.def.combo_symbol != &"":
				return action.def.combo_symbol
	return StringName(action_id)


func _build_tags(action, actor_before_cell: Vector2i, actor_before_facing: Vector2i, symbol: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if action == null or action.def == null or action.actor == null:
		return result

	result.append(StringName(action.def.id))

	if actor_before_cell != action.actor.grid_pos:
		result.append(&"moved")
	if actor_before_facing != action.actor.facing:
		result.append(&"turned")
	if symbol == &"F" or symbol == &"B" or symbol == &"SL" or symbol == &"SR":
		result.append(&"relative_move")
	if symbol == &"TL" or symbol == &"TR":
		result.append(&"relative_turn")
	if action.def.kind == ActionDefScript.ActionKind.ATTACK:
		result.append(&"attack")
	return result


func _relative_symbol_for_direction(chosen_dir: Vector2i, actor_before_facing: Vector2i) -> StringName:
	# chosen_dir is an absolute/world-space direction here.
	# The returned symbol is the same move re-expressed relative to the
	# actor's facing before this action step resolved.
	if chosen_dir == Vector2i.ZERO or actor_before_facing == Vector2i.ZERO:
		return &""
	if chosen_dir == actor_before_facing:
		return &"F"
	if chosen_dir == -actor_before_facing:
		return &"B"

	var left := Vector2i(actor_before_facing.y, -actor_before_facing.x)
	var right := Vector2i(-actor_before_facing.y, actor_before_facing.x)
	if chosen_dir == left:
		return &"SL"
	if chosen_dir == right:
		return &"SR"
	return &""
