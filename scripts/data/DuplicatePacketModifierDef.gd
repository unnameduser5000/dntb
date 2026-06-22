class_name DuplicatePacketModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

@export var packet_kind: String = "damage"
@export var required_tag: String = ""
@export var added_tag: String = "duplicated"
@export var duplicate_count: int = 1
@export var duplicate_scale: float = 1.0


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	var result: Array = []
	for packet in packets:
		result.append(packet)
		if not _matches(packet):
			continue

		for index in range(maxi(0, duplicate_count)):
			var copy = packet.copy(true)
			copy.proc_coefficient *= duplicate_scale
			if not added_tag.is_empty():
				copy.add_tag(StringName(added_tag))
			result.append(copy)

	return result


func _matches(packet) -> bool:
	if packet == null:
		return false
	if String(packet.kind) != packet_kind:
		return false
	if packet.generation_depth >= max_generation_depth:
		return false
	if required_tag.is_empty():
		return true
	return packet.has_tag(StringName(required_tag))
