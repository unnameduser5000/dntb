class_name DuplicateDamageModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

var duplicate_scale: float = 1.0
var copied_packets: int = 0


func _init() -> void:
	id = "duplicate_damage_test"
	display_name = "Duplicate Damage Test"
	priority = 10


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	var result: Array = []
	for packet in packets:
		result.append(packet)
		if packet == null or packet.kind != EffectPacketScript.KIND_DAMAGE:
			continue
		if packet.generation_depth >= max_generation_depth:
			continue

		var copy = packet.copy(true)
		copy.proc_coefficient *= duplicate_scale
		copy.add_tag(&"duplicated")
		result.append(copy)
		copied_packets += 1

	return result
