class_name OnMoveZapAheadModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

var zap_damage: int = 1
var triggered_count: int = 0


func _init() -> void:
	id = "on_move_zap_ahead_test"
	display_name = "On Move Zap Ahead Test"
	priority = 10
	max_event_depth = 2


func react_to_event(event, context: Dictionary) -> Array:
	if event == null or event.event_type != EffectEventScript.TYPE_ACTOR_MOVED:
		return []
	if event.actor == null or event.direction == Vector2i.ZERO:
		return []

	var state = context.get("state")
	if state == null or state.grid == null:
		return []

	var target_cell: Vector2i = event.to_cell + event.direction
	var target = state.grid.get_actor(target_cell)
	if target == null or target.team == event.actor.team:
		return []

	var packet = EffectPacketScript.make_damage(event.actor, target, zap_damage, event.action)
	packet.add_tag(&"move_zap")
	triggered_count += 1
	return [packet]
