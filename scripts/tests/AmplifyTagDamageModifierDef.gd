class_name AmplifyTagDamageModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

var target_tag: StringName = &"duplicated"
var multiplier: float = 2.0
var amplified_packets: int = 0


func _init() -> void:
	id = "amplify_tag_damage_test"
	display_name = "Amplify Tag Damage Test"
	priority = 20


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	for packet in packets:
		if packet == null or packet.kind != EffectPacketScript.KIND_DAMAGE:
			continue
		if packet.has_tag(target_tag):
			packet.proc_coefficient *= multiplier
			amplified_packets += 1

	return packets
