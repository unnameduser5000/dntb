class_name OnAttackGuardModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")


func react_to_event(event, _context: Dictionary) -> Array:
	if event == null or event.event_type != EffectEventScript.TYPE_DAMAGE_DEALT:
		return []
	if not event.has_tag(&"attack"):
		return []
	if event.source == null or event.source.is_dead():
		return []
	if bool(event.source.guarded):
		return []

	event.source.guarded = true
	return [EffectPacketScript.make_message("%s 借势架起防御。" % event.source.def.display_name, event.source, event.action)]
