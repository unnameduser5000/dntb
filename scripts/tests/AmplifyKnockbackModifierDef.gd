class_name AmplifyKnockbackModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

var multiplier: float = 2.0
var amplified_packets: int = 0


func _init() -> void:
	id = "amplify_knockback_test"
	display_name = "Amplify Knockback Test"
	priority = 10


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	for packet in packets:
		if packet == null or packet.kind != EffectPacketScript.KIND_KNOCKBACK:
			continue
		packet.proc_coefficient *= multiplier
		packet.add_tag(&"amplified")
		amplified_packets += 1

	return packets
