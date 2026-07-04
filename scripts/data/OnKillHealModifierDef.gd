class_name OnKillHealModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

@export var heal_amount: int = 1


func react_to_event(event, _context: Dictionary) -> Array:
	if event == null or event.event_type != EffectEventScript.TYPE_ACTOR_KILLED:
		return []
	if event.source == null or event.source.is_dead():
		return []

	var missing_hp := int(event.source.max_hp) - int(event.source.hp)
	if missing_hp <= 0:
		return []

	var healed := mini(maxi(0, heal_amount), missing_hp)
	if healed <= 0:
		return []

	event.source.hp += healed
	return [EffectPacketScript.make_message("%s 汲取余势，恢复了 %d 点生命。" % [event.source.def.display_name, healed], event.source, event.action)]
