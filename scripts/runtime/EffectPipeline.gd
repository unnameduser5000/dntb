class_name EffectPipeline
extends RefCounted

const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")
const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const DEFAULT_MAX_EVENT_DEPTH := 3

## EffectPipeline runs in two broad stages:
##
## 1. packet processing
##    initial packets -> modifier.modify_packets() -> executable packets
##
## 2. packet execution + event reactions
##    execute packets -> collect events -> modifier.react_to_event()
##    -> process generated packets -> execute them -> repeat until depth limit
##
## Two recursion concepts live here:
## - packet.generation_depth:
##   follows packet copies produced through modify_packets()
## - event.depth:
##   follows reaction waves produced through react_to_event()
##
## They are related but separate and should not be merged mentally.


func process_packets(initial_packets: Array, modifiers: Array, context: Dictionary = {}) -> Array:
	var packets := _clean_packets(initial_packets)
	var sorted_modifiers := _sorted_modifiers(modifiers)

	return _process_packets_with_modifiers(packets, sorted_modifiers, context)


func process_and_execute(initial_packets: Array, modifiers: Array, context: Dictionary, state, resolver) -> Array:
	var sorted_modifiers := _sorted_modifiers(modifiers)
	var executed_packets: Array = []
	var event_queue: Array = []
	# context max_event_depth is the global ceiling for reaction waves in this
	# processing pass. Individual modifiers may impose a smaller local ceiling
	# through modifier.max_event_depth.
	var max_event_depth := int(context.get("max_event_depth", DEFAULT_MAX_EVENT_DEPTH))
	var packets := _process_packets_with_modifiers(_clean_packets(initial_packets), sorted_modifiers, context)
	_execute_packets_collect_events(packets, state, resolver, event_queue, executed_packets, 0)

	var event_index := 0
	while event_index < event_queue.size():
		var event = event_queue[event_index]
		event_index += 1
		if event == null or int(event.depth) >= max_event_depth:
			continue

		var reaction_context := context.duplicate()
		reaction_context["event"] = event
		reaction_context["event_depth"] = int(event.depth) + 1
		var reaction_packets := _collect_reaction_packets(event, sorted_modifiers, reaction_context)
		if reaction_packets.is_empty():
			continue

		var processed_reaction_packets := _process_packets_with_modifiers(reaction_packets, sorted_modifiers, reaction_context)
		_execute_packets_collect_events(processed_reaction_packets, state, resolver, event_queue, executed_packets, int(event.depth) + 1)

	return executed_packets


func execute_packets(packets: Array, state, resolver) -> Array:
	var events: Array = []
	for packet in packets:
		for event in execute_packet(packet, state, resolver, 0):
			events.append(event)
	return events


func execute_packet(packet, state, resolver, event_depth: int = 0) -> Array:
	var events: Array = []
	if packet == null or packet.cancelled or resolver == null:
		return events

	match packet.kind:
		EffectPacketScript.KIND_DAMAGE:
			if packet.target == null or packet.target.is_dead():
				return events
			if _is_attack_packet(packet):
				var hit_event = _make_event(EffectEventScript.TYPE_ATTACK_HIT_CONFIRMED, packet, event_depth)
				hit_event.target = packet.target
				hit_event.actor = packet.target
				hit_event.from_cell = packet.source_cell
				hit_event.to_cell = packet.target.grid_pos
				hit_event.direction = packet.direction
				hit_event.metadata["predicted_damage"] = packet.scaled_amount()
				events.append(hit_event)
			var damage_result: Dictionary = resolver.apply_damage(packet.source, packet.target, packet.scaled_amount(), state)
			var dealt := int(damage_result.get("amount", 0))
			if dealt > 0:
				var damage_event = _make_event(EffectEventScript.TYPE_DAMAGE_DEALT, packet, event_depth)
				damage_event.target = packet.target
				damage_event.actor = packet.target
				damage_event.amount = dealt
				damage_event.from_cell = packet.target_cell
				damage_event.to_cell = packet.target.grid_pos
				damage_event.direction = packet.direction
				damage_event.metadata = damage_result.duplicate(true)
				events.append(damage_event)
				if bool(damage_result.get("killed", false)):
					var kill_event = _make_event(EffectEventScript.TYPE_ACTOR_KILLED, packet, event_depth)
					kill_event.target = packet.target
					kill_event.actor = packet.target
					kill_event.amount = dealt
					kill_event.from_cell = packet.target_cell
					kill_event.to_cell = packet.target_cell
					kill_event.direction = packet.direction
					kill_event.metadata = damage_result.duplicate(true)
					events.append(kill_event)
		EffectPacketScript.KIND_MOVE:
			if packet.source != null:
				var from_cell: Vector2i = packet.source.grid_pos
				var move_target: Vector2i = packet.target_cell
				if bool(packet.metadata.get("relative_step", false)):
					move_target = packet.source.grid_pos + packet.direction
				var moved: bool = resolver.try_move_actor(packet.source, move_target, state)
				packet.metadata["moved"] = moved
				packet.metadata["from_cell"] = from_cell
				packet.metadata["to_cell"] = move_target
				if moved and resolver.has_method("on_actor_entered_cell"):
					resolver.on_actor_entered_cell(packet.source, state)
				var move_event_type := EffectEventScript.TYPE_ACTOR_MOVED if moved else EffectEventScript.TYPE_MOVE_BLOCKED
				var move_event = _make_event(move_event_type, packet, event_depth)
				move_event.actor = packet.source
				move_event.target = packet.source
				move_event.from_cell = from_cell
				move_event.to_cell = packet.source.grid_pos if moved else move_target
				move_event.direction = packet.direction
				move_event.amount = 1 if moved else 0
				move_event.metadata["moved"] = moved
				events.append(move_event)
		EffectPacketScript.KIND_KNOCKBACK:
			var knockback_from_cell := Vector2i.ZERO
			if packet.target != null:
				knockback_from_cell = packet.target.grid_pos
			var moved_steps: int = resolver.try_knockback(packet.target, packet.direction, packet.scaled_amount(), state)
			packet.metadata["moved_steps"] = moved_steps
			if moved_steps > 0:
				var knockback_event = _make_event(EffectEventScript.TYPE_KNOCKBACK_APPLIED, packet, event_depth)
				knockback_event.actor = packet.target
				knockback_event.target = packet.target
				knockback_event.from_cell = knockback_from_cell
				knockback_event.to_cell = packet.target.grid_pos
				knockback_event.direction = packet.direction
				knockback_event.amount = moved_steps
				knockback_event.metadata["moved_steps"] = moved_steps
				events.append(knockback_event)
		EffectPacketScript.KIND_PULL:
			var pull_from_cell := Vector2i.ZERO
			if packet.target != null:
				pull_from_cell = packet.target.grid_pos
			var pulled_steps: int = resolver.try_pull_actor(packet.target, packet.direction, packet.scaled_amount(), state)
			packet.metadata["moved_steps"] = pulled_steps
			if pulled_steps > 0:
				var pull_event = _make_event(EffectEventScript.TYPE_PULL_APPLIED, packet, event_depth)
				pull_event.actor = packet.target
				pull_event.target = packet.target
				pull_event.from_cell = pull_from_cell
				pull_event.to_cell = packet.target.grid_pos
				pull_event.direction = packet.direction
				pull_event.amount = pulled_steps
				pull_event.metadata["moved_steps"] = pulled_steps
				events.append(pull_event)
		EffectPacketScript.KIND_SWAP:
			if packet.source != null and packet.target != null:
				var source_from: Vector2i = packet.source.grid_pos
				var target_from: Vector2i = packet.target.grid_pos
				var swapped: bool = resolver.try_swap_actors(packet.source, packet.target, state)
				packet.metadata["swapped"] = swapped
				if swapped:
					var swap_event = _make_event(EffectEventScript.TYPE_SWAP_APPLIED, packet, event_depth)
					swap_event.actor = packet.source
					swap_event.target = packet.target
					swap_event.from_cell = source_from
					swap_event.to_cell = packet.source.grid_pos
					swap_event.direction = packet.source.grid_pos - source_from
					swap_event.amount = 1
					swap_event.metadata["source_from_cell"] = source_from
					swap_event.metadata["source_to_cell"] = packet.source.grid_pos
					swap_event.metadata["target_from_cell"] = target_from
					swap_event.metadata["target_to_cell"] = packet.target.grid_pos
					events.append(swap_event)
		EffectPacketScript.KIND_TELEPORT:
			if packet.source != null:
				var teleport_from: Vector2i = packet.source.grid_pos
				var teleported: bool = resolver.try_teleport_actor(packet.source, packet.target_cell, state)
				packet.metadata["moved"] = teleported
				packet.metadata["from_cell"] = teleport_from
				packet.metadata["to_cell"] = packet.source.grid_pos if teleported else packet.target_cell
				if teleported:
					if resolver.has_method("on_actor_entered_cell"):
						resolver.on_actor_entered_cell(packet.source, state)
					var teleport_event = _make_event(EffectEventScript.TYPE_TELEPORT_APPLIED, packet, event_depth)
					teleport_event.actor = packet.source
					teleport_event.target = packet.source
					teleport_event.from_cell = teleport_from
					teleport_event.to_cell = packet.source.grid_pos
					teleport_event.direction = packet.source.grid_pos - teleport_from
					teleport_event.amount = 1
					events.append(teleport_event)
		EffectPacketScript.KIND_MESSAGE:
			var message := String(packet.metadata.get("message", ""))
			if not message.is_empty():
				resolver.add_state_message(state, message)
	return events


func _execute_packets_collect_events(packets: Array, state, resolver, event_queue: Array, executed_packets: Array, event_depth: int) -> void:
	for packet in packets:
		executed_packets.append(packet)
		for event in execute_packet(packet, state, resolver, event_depth):
			event_queue.append(event)
			if resolver != null and resolver.has_method("emit_combat_event"):
				resolver.emit_combat_event(event)


func _process_packets_with_modifiers(packets: Array, sorted_modifiers: Array, context: Dictionary) -> Array:
	var result := _clean_packets(packets)
	for modifier in sorted_modifiers:
		if modifier == null or not modifier.has_method("modify_packets"):
			continue
		# Each modifier sees the packet list produced by earlier modifiers in
		# ascending priority order.
		result = _clean_packets(modifier.modify_packets(result, context))
		if result.is_empty():
			break
	return result


func _collect_reaction_packets(event, sorted_modifiers: Array, context: Dictionary) -> Array:
	var result: Array = []
	for modifier in sorted_modifiers:
		if modifier == null or not modifier.has_method("react_to_event"):
			continue
		# event.depth counts how many reaction waves deep this event already is.
		# max_event_depth therefore limits follow-up chains from event listeners,
		# not packet duplication done in modify_packets().
		if int(event.depth) >= int(modifier.max_event_depth):
			continue
		var generated = modifier.react_to_event(event, context)
		for packet in _clean_packets(generated):
			packet.generation_depth = maxi(int(packet.generation_depth), int(event.depth) + 1)
			result.append(packet)
	return result


func _make_event(event_type: StringName, packet, event_depth: int):
	var event = EffectEventScript.new()
	event.event_type = event_type
	event.source = packet.source
	event.packet = packet
	event.action = packet.action
	event.from_cell = packet.source_cell
	event.to_cell = packet.target_cell
	event.direction = packet.direction
	event.amount = packet.scaled_amount()
	event.depth = event_depth
	event.inherit_packet_tags(packet)
	return event


func _clean_packets(packets: Array) -> Array:
	var result: Array = []
	for packet in packets:
		if packet != null:
			result.append(packet)
	return result


func _sorted_modifiers(modifiers: Array) -> Array:
	var sorted_modifiers := modifiers.duplicate()
	sorted_modifiers.sort_custom(func(a, b) -> bool:
		return _modifier_priority(a) < _modifier_priority(b)
	)
	return sorted_modifiers


func _modifier_priority(modifier) -> int:
	if modifier == null:
		return 0
	return int(modifier.priority)


func _is_attack_packet(packet) -> bool:
	if packet == null:
		return false
	if packet.action != null and packet.action.def != null and int(packet.action.def.kind) == int(ActionDef.ActionKind.ATTACK):
		return true
	return packet.has_tag(&"attack")
