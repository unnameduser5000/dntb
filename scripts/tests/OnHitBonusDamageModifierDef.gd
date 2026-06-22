class_name OnHitBonusDamageModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

var bonus_damage: int = 1
var triggered_count: int = 0


func _init() -> void:
	id = "on_hit_bonus_damage_test"
	display_name = "On Hit Bonus Damage Test"
	priority = 10
	max_event_depth = 2


func react_to_event(event, _context: Dictionary) -> Array:
	if event == null or event.event_type != EffectEventScript.TYPE_DAMAGE_DEALT:
		return []
	if not event.has_tag(&"attack"):
		return []
	if event.target == null or event.target.is_dead():
		return []

	var packet = EffectPacketScript.make_damage(event.source, event.target, bonus_damage, event.action)
	packet.add_tag(&"on_hit_bonus")
	triggered_count += 1
	return [packet]
