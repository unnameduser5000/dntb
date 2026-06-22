class_name DuplicateMoveModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")

var copied_packets: int = 0


func _init() -> void:
	id = "duplicate_move_test"
	display_name = "Duplicate Move Test"
	priority = 10


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	var result: Array = []
	for packet in packets:
		result.append(packet)
		if packet == null or packet.kind != EffectPacketScript.KIND_MOVE:
			continue
		if not packet.has_tag(&"action_move"):
			continue
		if packet.generation_depth >= max_generation_depth:
			continue

		var copy = packet.copy(true)
		copy.add_tag(&"duplicated")
		result.append(copy)
		copied_packets += 1

	return result
