class_name EffectPacket
extends RefCounted

## EffectPacket is the executable unit that flows through EffectPipeline.
##
## Two fields are especially important for later modifier work:
## - generation_depth:
##   counts packet-copy generations produced through modify_packets()
## - metadata["relative_step"]:
##   for move packets, means target_cell should be interpreted as one step in
##   packet.direction from the source's current position at execution time

const SELF_PATH := "res://scripts/runtime/EffectPacket.gd"
const KIND_DAMAGE := &"damage"
const KIND_MOVE := &"move"
const KIND_KNOCKBACK := &"knockback"
const KIND_MESSAGE := &"message"

var kind: StringName = &""
var source
var target
var action
var source_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var direction: Vector2i = Vector2i.ZERO
var amount: int = 0
var tags: Array[StringName] = []
var metadata: Dictionary = {}
var generation_depth: int = 0
var proc_coefficient: float = 1.0
var can_trigger: bool = true
var cancelled: bool = false


static func make_damage(new_source, new_target, new_amount: int, new_action = null):
	var packet = load(SELF_PATH).new()
	packet.kind = KIND_DAMAGE
	packet.source = new_source
	packet.target = new_target
	packet.action = new_action
	packet.amount = maxi(0, new_amount)
	if new_source != null:
		packet.source_cell = new_source.grid_pos
	if new_target != null:
		packet.target_cell = new_target.grid_pos
		if new_source != null:
			packet.direction = new_target.grid_pos - new_source.grid_pos
	packet.add_tag(&"damage")
	return packet


static func make_move(new_source, new_target_cell: Vector2i, new_action = null, relative_step: bool = false):
	var packet = load(SELF_PATH).new()
	packet.kind = KIND_MOVE
	packet.source = new_source
	packet.action = new_action
	packet.target_cell = new_target_cell
	if new_source != null:
		packet.source_cell = new_source.grid_pos
		packet.direction = new_target_cell - new_source.grid_pos
	packet.metadata["relative_step"] = relative_step
	packet.add_tag(&"move")
	return packet


static func make_knockback(new_source, new_target, new_direction: Vector2i, new_distance: int, new_action = null):
	var packet = load(SELF_PATH).new()
	packet.kind = KIND_KNOCKBACK
	packet.source = new_source
	packet.target = new_target
	packet.action = new_action
	packet.direction = new_direction
	packet.amount = maxi(0, new_distance)
	if new_source != null:
		packet.source_cell = new_source.grid_pos
	if new_target != null:
		packet.target_cell = new_target.grid_pos
	packet.add_tag(&"knockback")
	return packet


static func make_message(message: String, new_source = null, new_action = null):
	var packet = load(SELF_PATH).new()
	packet.kind = KIND_MESSAGE
	packet.source = new_source
	packet.action = new_action
	packet.metadata["message"] = message
	if new_source != null:
		packet.source_cell = new_source.grid_pos
		packet.target_cell = new_source.grid_pos
	packet.add_tag(&"message")
	return packet


func copy(increment_depth: bool = false):
	# increment_depth is used when a modifier creates a derived packet from an
	# existing packet. This feeds max_generation_depth checks later.
	var packet = get_script().new()
	packet.kind = kind
	packet.source = source
	packet.target = target
	packet.action = action
	packet.source_cell = source_cell
	packet.target_cell = target_cell
	packet.direction = direction
	packet.amount = amount
	packet.tags = tags.duplicate()
	packet.metadata = metadata.duplicate(true)
	packet.generation_depth = generation_depth + (1 if increment_depth else 0)
	packet.proc_coefficient = proc_coefficient
	packet.can_trigger = can_trigger
	packet.cancelled = cancelled
	return packet


func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func scaled_amount() -> int:
	return maxi(0, int(round(float(amount) * proc_coefficient)))
