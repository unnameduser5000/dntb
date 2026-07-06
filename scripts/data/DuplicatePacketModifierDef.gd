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
	var first_step_cell: Vector2i = packet.target_cell
	if bool(packet.metadata.get("relative_step", false)):
		first_step_cell = source.grid_pos + packet.direction
	return not _is_interaction_staging_cell(state, first_step_cell)


func _is_interaction_staging_cell(state, cell: Vector2i) -> bool:
	if state == null or state.grid == null:
		return false
	var player = state.player
	if player == null:
		return false
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var npc_cell: Vector2i = cell + dir
		var actor = state.grid.get_actor(npc_cell)
		if actor == null or actor == player or actor.def == null:
			continue
		if not bool(actor.def.get("interaction_enabled")):
			continue
		if actor.tags.has("npc") or actor.tags.has("poi_npc"):
			return true
	return false
