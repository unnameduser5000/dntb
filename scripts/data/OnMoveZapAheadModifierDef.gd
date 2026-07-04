class_name StormstepModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

@export var zap_damage: int = 1
@export var required_tag: StringName = &"action_move"
@export var added_tag: StringName = &"stormstep"


func react_to_event(event, context: Dictionary) -> Array:
	if event == null or event.event_type != EffectEventScript.TYPE_ACTOR_MOVED:
		return []
	if event.actor == null or event.direction == Vector2i.ZERO:
		return []
	if required_tag != &"" and not event.has_tag(required_tag):
		return []

	var state = context.get("state")
	if state == null or state.grid == null:
		return []

	var target_cell: Vector2i = event.to_cell + event.direction
	var target = state.grid.get_actor(target_cell)
	if target == null or target.team == event.actor.team:
		return []

	var packet = EffectPacketScript.make_damage(event.actor, target, zap_damage, event.action)
	if added_tag != &"":
		packet.add_tag(added_tag)
	return [packet]
