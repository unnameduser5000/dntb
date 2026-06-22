class_name ScalePacketModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

@export var packet_kind: String = "damage"
@export var required_tag: String = ""
@export var multiplier: float = 1.0
@export var added_tag: String = "scaled"


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	for packet in packets:
		if not _matches(packet):
			continue
		packet.proc_coefficient *= multiplier
		if not added_tag.is_empty():
			packet.add_tag(StringName(added_tag))

	return packets


func _matches(packet) -> bool:
	if packet == null:
		return false
	if String(packet.kind) != packet_kind:
		return false
	if required_tag.is_empty():
		return true
	return packet.has_tag(StringName(required_tag))
