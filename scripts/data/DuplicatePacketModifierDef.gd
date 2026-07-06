class_name DuplicatePacketModifierDef
extends "res://scripts/data/EffectModifierDef.gd"

@export var packet_kind: String = "damage"
@export var required_tag: String = ""
@export var added_tag: String = "duplicated"
@export var duplicate_count: int = 1
@export var duplicate_scale: float = 1.0


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	var result: Array = []
	var state = _context.get("state", null)
	for packet in packets:
		result.append(packet)
		if not _matches(packet):
			continue
		if not _should_duplicate_packet(packet, state):
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


func _should_duplicate_packet(packet, state) -> bool:
	if packet == null or state == null:
		return true
	if String(added_tag) != "echo_move":
		return true
	if not bool(state.get("is_world_slice")):
		return true
	var source = packet.source
	if source == null or source.def == null or String(source.team) != "player":
		return true
	var source_cell: Vector2i = source.grid_pos
	var first_step_cell: Vector2i = packet.target_cell
	if bool(packet.metadata.get("relative_step", false)):
		first_step_cell = source_cell + packet.direction
	return not _would_enter_interaction_zone(state, source_cell, first_step_cell)


func _would_enter_interaction_zone(state, source_cell: Vector2i, first_step_cell: Vector2i) -> bool:
	if state == null or state.grid == null:
		return false
	for actor in state.actors:
		if actor == null or actor.def == null:
			continue
		if not bool(actor.def.get("interaction_enabled")):
			continue
		if actor.tags.has("npc") or actor.tags.has("poi_npc"):
			var from_distance := absi(source_cell.x - actor.grid_pos.x) + absi(source_cell.y - actor.grid_pos.y)
			var to_distance := absi(first_step_cell.x - actor.grid_pos.x) + absi(first_step_cell.y - actor.grid_pos.y)
			if from_distance <= 1:
				return true
			if to_distance <= 1 and to_distance < from_distance:
				return true
	return false
