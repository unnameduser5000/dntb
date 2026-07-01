class_name MovementResult
extends RefCounted

const KIND_MOVE := &"move"
const KIND_KNOCKBACK := &"knockback"
const KIND_PULL := &"pull"
const KIND_SWAP := &"swap"
const KIND_TELEPORT := &"teleport"

var kind: StringName = &""
var actor
var secondary_actor
var from_cell: Vector2i = Vector2i.ZERO
var to_cell: Vector2i = Vector2i.ZERO
var secondary_from_cell: Vector2i = Vector2i.ZERO
var secondary_to_cell: Vector2i = Vector2i.ZERO
var direction: Vector2i = Vector2i.ZERO
var requested_steps: int = 0
var moved_steps: int = 0
var moved: bool = false
var blocked: bool = false
var blocked_reason: StringName = &""
var target_cell: Vector2i = Vector2i.ZERO


func setup_single(
	new_kind: StringName,
	new_actor,
	new_from_cell: Vector2i,
	new_to_cell: Vector2i,
	new_direction: Vector2i = Vector2i.ZERO,
	new_requested_steps: int = 1,
	new_moved_steps: int = 0
) -> void:
	kind = new_kind
	actor = new_actor
	secondary_actor = null
	from_cell = new_from_cell
	to_cell = new_to_cell
	secondary_from_cell = Vector2i.ZERO
	secondary_to_cell = Vector2i.ZERO
	direction = new_direction
	requested_steps = maxi(0, new_requested_steps)
	moved_steps = maxi(0, new_moved_steps)
	moved = moved_steps > 0 or from_cell != to_cell
	blocked = false
	blocked_reason = &""
	target_cell = new_to_cell


func setup_swap(
	new_first_actor,
	new_second_actor,
	new_first_from: Vector2i,
	new_first_to: Vector2i,
	new_second_from: Vector2i,
	new_second_to: Vector2i
) -> void:
	kind = KIND_SWAP
	actor = new_first_actor
	secondary_actor = new_second_actor
	from_cell = new_first_from
	to_cell = new_first_to
	secondary_from_cell = new_second_from
	secondary_to_cell = new_second_to
	direction = new_first_to - new_first_from
	requested_steps = 1
	moved_steps = 1 if new_first_from != new_first_to else 0
	moved = moved_steps > 0
	blocked = false
	blocked_reason = &""
	target_cell = new_first_to


func mark_blocked(reason: StringName, new_target_cell: Vector2i = Vector2i.ZERO) -> void:
	blocked = true
	blocked_reason = reason
	target_cell = new_target_cell
	if not moved:
		to_cell = from_cell
