class_name ActionResolver
extends Node

const ActionDefScript := preload("res://scripts/data/ActionDef.gd")
const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")
const EffectPipelineScript := preload("res://scripts/runtime/EffectPipeline.gd")
const AttackResultScript := preload("res://scripts/runtime/AttackResult.gd")
const MovementResultScript := preload("res://scripts/runtime/MovementResult.gd")
const TokenDropTableScript := preload("res://scripts/core/TokenDropTable.gd")

signal actor_moved(actor, from_cell: Vector2i, to_cell: Vector2i)
signal actor_damaged(actor, amount: int)
signal actor_died(actor)
signal attack_missed(actor, target_cell: Vector2i)
signal key_picked(actor, key_id: String, cell: Vector2i)
signal rule_message(message: String)
signal combat_event_emitted(event)
signal world_npc_interaction_requested(actor)

var effect_pipeline = EffectPipelineScript.new()
var _presentation_frames: Array = []

## ActionResolver remains the execution/rules layer.
## It is the place where concrete actions become movement, damage, turn, and
## guard results. Higher-level key-program editing and pattern recognition feed
## into this layer and then let it stay focused on battle resolution.
func resolve(action, state) -> void:
	if action == null or action.actor == null or action.def == null:
		return

	if action.actor.is_dead():
		return

	match action.def.kind:
		ActionDefScript.ActionKind.MOVE:
			_resolve_move(action, state)

		ActionDefScript.ActionKind.ATTACK:
			_resolve_attack(action, state)

		ActionDefScript.ActionKind.TURN:
			_resolve_turn(action, state)

		ActionDefScript.ActionKind.WAIT:
			_add_message(state, "%s 等待。" % action.actor.def.display_name)

		ActionDefScript.ActionKind.GUARD:
			_resolve_guard(action, state)

		ActionDefScript.ActionKind.INTERACT:
			_resolve_interact(action, state)

func _resolve_move(action, state) -> void:
	var actor = action.actor
	var dir = _get_action_dir(action)
	var distance = max(1, int(action.def.range))
	if action.def.id == "jump":
		_resolve_jump(action, state, actor, dir, distance)
		return

	# move_key currently uses chosen_dir and also snaps facing to that direction.
	# This is the bridge between absolute input tokens and the current combat
	# action model.
	#
	# In practice:
	# - chosen_dir is interpreted as an absolute/world-space movement direction
	# - move_key updates actor.facing to that same direction before stepping
	# - later trace code can then compare chosen_dir against the pre-action
	#   facing snapshot and derive F / B / SL / SR semantics
	if action.chosen_dir != Vector2i.ZERO:
		actor.facing = dir

	for step in range(distance):
		var target_cell = actor.grid_pos + dir
		if state.grid.is_blocked(target_cell):
			_add_message(state, "%s 撞上墙，移动停止。" % actor.def.display_name)
			return

		var blocking_actor = state.grid.get_actor(target_cell)
		if blocking_actor != null:
			if blocking_actor.team != actor.team:
				_add_message(state, "%s 被挡住，移动停止。" % actor.def.display_name)
			return

		var move_packets: Array = apply_effect_move(actor, dir, state, action, [&"action_move"])
		if not did_any_packet_move(move_packets):
			return

func _resolve_jump(action, state, actor, dir: Vector2i, distance: int) -> void:
	if dir == Vector2i.ZERO:
		return

	var landing_cell: Vector2i = actor.grid_pos + dir * distance
	if not state.grid.can_enter(landing_cell):
		_add_message(state, "%s 的跳跃落点被挡住了。" % actor.def.display_name)
		return

	var move_packets: Array = apply_effect_move_to_cell(actor, landing_cell, state, action, [&"action_move", &"jump"])
	if not did_any_packet_move(move_packets):
		_add_message(state, "%s 的跳跃失败了。" % actor.def.display_name)

func _resolve_attack(action, state):
	var actor = action.actor
	var dir = _get_action_dir(action)
	if dir != Vector2i.ZERO and action.chosen_dir != Vector2i.ZERO:
		actor.facing = dir
	var attack_cells = _get_attack_cells(action)
	var result = AttackResultScript.new()
	result.setup(actor, action, dir)

	if String(action.def.id) == "bow_shot":
		return _resolve_bow_shot(action, state, actor, dir, attack_cells, result)
	if String(action.def.id) == "hook_pull":
		return _resolve_hook_pull(action, state, actor, dir, attack_cells, result)
	if String(action.def.id) == "shield_bash":
		return _resolve_shield_bash(action, state, actor, dir, attack_cells, result)

	for target_cell in attack_cells:
		result.record_attempted_cell(target_cell)
		var target = state.grid.get_actor(target_cell)
		if target == null or target.team == actor.team:
			continue

		var damage: int = int(actor.atk) * int(action.def.power)
		var damage_packets: Array = []
		damage_packets = apply_effect_damage(actor, target, damage, state, action, [&"attack"])
		result.record_hit(target, target_cell, damage_packets, false, damage)

	if result.hit_targets.is_empty():
		var miss_cell: Vector2i = actor.grid_pos + dir
		result.record_miss(miss_cell)
		attack_missed.emit(actor, miss_cell)
		_emit_attack_miss_event(actor, action, miss_cell, dir)
		_append_presentation_frame("attack_missed", {
			"actor": actor,
			"target_cell": miss_cell,
			"direction": dir,
			"speed": _get_action_momentum_speed(action),
		})
		_add_message(state, "%s 攻击落空。" % actor.def.display_name)
	return result


func _resolve_bow_shot(action, state, actor, dir: Vector2i, attack_cells: Array[Vector2i], result):
	for target_cell in attack_cells:
		result.record_attempted_cell(target_cell)
		var target = state.grid.get_actor(target_cell)
		if target == null or target.team == actor.team:
			continue

		var damage: int = int(actor.atk) * int(action.def.power)
		var damage_packets: Array = apply_effect_damage(actor, target, damage, state, action, [&"attack", &"ranged"])
		result.record_hit(target, target_cell, damage_packets, false, damage)
		return result

	var miss_cell: Vector2i = actor.grid_pos + dir
	if not attack_cells.is_empty():
		miss_cell = Vector2i(attack_cells.back())
	result.record_miss(miss_cell)
	attack_missed.emit(actor, miss_cell)
	_emit_attack_miss_event(actor, action, miss_cell, dir)
	_append_presentation_frame("attack_missed", {
		"actor": actor,
		"target_cell": miss_cell,
		"direction": dir,
		"speed": _get_action_momentum_speed(action),
	})
	_add_message(state, "%s 的箭射空了。" % actor.def.display_name)
	return result


func _resolve_hook_pull(action, state, actor, dir: Vector2i, attack_cells: Array[Vector2i], result):
	for target_cell in attack_cells:
		result.record_attempted_cell(target_cell)
		var target = state.grid.get_actor(target_cell)
		if target == null or target.team == actor.team:
			continue

		var damage: int = int(actor.atk) * int(action.def.power)
		var damage_packets: Array = apply_effect_damage(actor, target, damage, state, action, [&"attack", &"hook_pull"])
		result.record_hit(target, target_cell, damage_packets, false, damage)
		if target != null and not target.is_dead():
			apply_effect_pull(actor, target, -dir, 1, state, action, [&"hook_pull"])
		return result

	var miss_cell: Vector2i = actor.grid_pos + dir
	if not attack_cells.is_empty():
		miss_cell = Vector2i(attack_cells.back())
	result.record_miss(miss_cell)
	attack_missed.emit(actor, miss_cell)
	_emit_attack_miss_event(actor, action, miss_cell, dir)
	_append_presentation_frame("attack_missed", {
		"actor": actor,
		"target_cell": miss_cell,
		"direction": dir,
		"speed": _get_action_momentum_speed(action),
	})
	_add_message(state, "%s 的钩拽落空。" % actor.def.display_name)
	return result


func _resolve_shield_bash(action, state, actor, dir: Vector2i, attack_cells: Array[Vector2i], result):
	for target_cell in attack_cells:
		result.record_attempted_cell(target_cell)
		var target = state.grid.get_actor(target_cell)
		if target == null or target.team == actor.team:
			continue

		var damage: int = int(actor.atk) * int(action.def.power)
		var damage_packets: Array = apply_effect_damage(actor, target, damage, state, action, [&"attack", &"shield_bash"])
		result.record_hit(target, target_cell, damage_packets, false, damage)
		if target != null and not target.is_dead():
			apply_effect_knockback(actor, target, dir, 1, state, action, [&"impact", &"shield_bash"])
		return result

	var miss_cell: Vector2i = actor.grid_pos + dir
	result.record_miss(miss_cell)
	attack_missed.emit(actor, miss_cell)
	_emit_attack_miss_event(actor, action, miss_cell, dir)
	_append_presentation_frame("attack_missed", {
		"actor": actor,
		"target_cell": miss_cell,
		"direction": dir,
		"speed": _get_action_momentum_speed(action),
	})
	_add_message(state, "%s 的盾击落空。" % actor.def.display_name)
	return result

func _resolve_turn(action, state) -> void:
	var actor = action.actor
	match action.def.id:
		"turn_left":
			actor.facing = Vector2i(actor.facing.y, -actor.facing.x)
			_add_message(state, "%s 左转。" % actor.def.display_name)
		"turn_right":
			actor.facing = Vector2i(-actor.facing.y, actor.facing.x)
			_add_message(state, "%s 右转。" % actor.def.display_name)
		_:
			var dir = _get_action_dir(action)
			if dir != Vector2i.ZERO:
				actor.facing = dir

func _resolve_guard(action, state) -> void:
	action.actor.guarded = true
	_add_message(state, "%s 防御，下一次受伤 -1。" % action.actor.def.display_name)


func _resolve_interact(action, state) -> void:
	if state == null or action == null or action.actor == null:
		return
	state.defer_enemy_phase_for_interaction = true
	_add_message(state, "%s 试着与附近的人交谈。" % action.actor.def.display_name)
	world_npc_interaction_requested.emit(action.actor)

func _get_action_dir(action) -> Vector2i:
	# Direction priority:
	# 1. chosen_dir when the action explicitly carries an absolute direction
	# 2. backward relative to current facing for move_back
	# 3. current facing for facing-based move / attack actions
	if action.chosen_dir != Vector2i.ZERO:
		return action.chosen_dir

	if action.def.id == "step_left":
		return Vector2i(action.actor.facing.y, -action.actor.facing.x)

	if action.def.id == "step_right":
		return Vector2i(-action.actor.facing.y, action.actor.facing.x)

	if action.def.id == "move_back":
		return -action.actor.facing

	return action.actor.facing

func _get_attack_cells(action) -> Array[Vector2i]:
	var actor = action.actor
	var dir = _get_action_dir(action)
	var left := Vector2i(dir.y, -dir.x)
	var right := Vector2i(-dir.y, dir.x)
	if action.def.id == "sweep" or action.def.id == "great_sweep":
		return [
			actor.grid_pos + left,
			actor.grid_pos + dir,
			actor.grid_pos + right,
		]

	if action.def.id == "cross_attack":
		return [
			actor.grid_pos + Vector2i.UP,
			actor.grid_pos + Vector2i.DOWN,
			actor.grid_pos + Vector2i.LEFT,
			actor.grid_pos + Vector2i.RIGHT,
		]

	if action.def.id == "hammer_smash":
		return [
			actor.grid_pos + dir + left,
			actor.grid_pos + dir,
			actor.grid_pos + dir + right,
			actor.grid_pos + dir * 2 + left,
			actor.grid_pos + dir * 2,
			actor.grid_pos + dir * 2 + right,
		]

	if action.def.id == "spin_axe":
		var cells_around: Array[Vector2i] = []
		for y in range(-1, 2):
			for x in range(-1, 2):
				if x == 0 and y == 0:
					continue
				cells_around.append(actor.grid_pos + Vector2i(x, y))
		return cells_around

	var cells: Array[Vector2i] = []
	for step in range(1, max(1, int(action.def.range)) + 1):
		cells.append(actor.grid_pos + dir * step)
	return cells

func apply_damage(source, target, amount: int, state) -> Dictionary:
	var result := {
		"applied": false,
		"amount": 0,
		"killed": false,
	}
	if target == null:
		return result

	var damage = amount
	if target.guarded:
		damage = max(0, damage - 1)
		target.guarded = false

	if damage <= 0:
		_add_message(state, "%s 挡下了伤害。" % target.def.display_name)
		return result

	target.hp -= damage
	result["applied"] = true
	result["amount"] = damage
	actor_damaged.emit(target, damage)
	_append_presentation_frame("actor_damaged", {
		"actor": target,
		"amount": damage,
	})
	_add_message(state, "%s 受到 %d 点伤害。" % [target.def.display_name, damage])

	if target.is_dead():
		result["killed"] = true
		_kill_actor(target, state)
	return result

func apply_effect_damage(source, target, amount: int, state, action = null, extra_tags: Array = []) -> Array:
	var packet = EffectPacketScript.make_damage(source, target, amount, action)
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"source": source,
		"target": target,
		"phase": "damage",
	})

func apply_effect_move(source, direction: Vector2i, state, action = null, extra_tags: Array = []) -> Array:
	if source == null or direction == Vector2i.ZERO:
		return []

	var packet = EffectPacketScript.make_move(source, source.grid_pos + direction, action, true)
	packet.direction = direction
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"direction": direction,
		"phase": "move",
	})

func apply_effect_move_to_cell(source, target_cell: Vector2i, state, action = null, extra_tags: Array = []) -> Array:
	if source == null:
		return []

	var packet = EffectPacketScript.make_move(source, target_cell, action, false)
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"target_cell": target_cell,
		"phase": "move",
	})

func apply_effect_knockback(source, target, direction: Vector2i, distance: int, state, action = null, extra_tags: Array = []) -> Array:
	if target == null or direction == Vector2i.ZERO or distance <= 0:
		return []

	var packet = EffectPacketScript.make_knockback(source, target, direction, distance, action)
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"target": target,
		"direction": direction,
		"phase": "knockback",
	})

func apply_effect_pull(source, target, direction: Vector2i, distance: int, state, action = null, extra_tags: Array = []) -> Array:
	if target == null or direction == Vector2i.ZERO or distance <= 0:
		return []

	var packet = EffectPacketScript.make_pull(source, target, direction, distance, action)
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"target": target,
		"direction": direction,
		"phase": "pull",
	})

func apply_effect_swap(source, target, state, action = null, extra_tags: Array = []) -> Array:
	if source == null or target == null:
		return []

	var packet = EffectPacketScript.make_swap(source, target, action)
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"target": target,
		"phase": "swap",
	})

func apply_effect_teleport(source, target_cell: Vector2i, state, action = null, extra_tags: Array = []) -> Array:
	if source == null:
		return []

	var packet = EffectPacketScript.make_teleport(source, target_cell, action)
	for tag in extra_tags:
		packet.add_tag(tag)
	return apply_effect_packets(source, [packet], state, {
		"action": action,
		"target_cell": target_cell,
		"phase": "teleport",
	})

func apply_effect_packets(source, packets: Array, state, context: Dictionary = {}) -> Array:
	var modifiers := _get_effect_modifiers(source, state)
	context["state"] = state
	context["resolver"] = self
	context["source"] = source
	return effect_pipeline.process_and_execute(packets, modifiers, context, state, self)

func did_any_packet_move(packets: Array) -> bool:
	for packet in packets:
		if packet != null and packet.kind == EffectPacketScript.KIND_MOVE and bool(packet.metadata.get("moved", false)):
			return true
	return false

func consume_presentation_frames() -> Array:
	var result: Array = _presentation_frames.duplicate(true)
	_presentation_frames.clear()
	return result

func clear_presentation_frames() -> void:
	_presentation_frames.clear()

func _append_presentation_frame(kind: String, payload: Dictionary = {}) -> void:
	if kind.is_empty():
		return

	var frame: Dictionary = payload.duplicate(true)
	frame["kind"] = kind
	_presentation_frames.append(frame)

func get_total_knockback_moved(packets: Array) -> int:
	var moved := 0
	for packet in packets:
		if packet != null and packet.kind == EffectPacketScript.KIND_KNOCKBACK:
			moved += int(packet.metadata.get("moved_steps", 0))
	return moved

func _damage_actor(target, amount: int, state) -> void:
	apply_damage(null, target, amount, state)

func try_move_actor(actor, target_cell: Vector2i, state) -> bool:
	return resolve_move_actor_to_cell(actor, target_cell, state).moved

func try_knockback(actor, direction: Vector2i, distance: int, state) -> int:
	return resolve_forced_directional_move(actor, direction, distance, state, MovementResultScript.KIND_KNOCKBACK).moved_steps

func try_pull_actor(actor, direction: Vector2i, distance: int, state) -> int:
	return resolve_forced_directional_move(actor, direction, distance, state, MovementResultScript.KIND_PULL).moved_steps

func try_swap_actors(first_actor, second_actor, state) -> bool:
	return resolve_swap_actors(first_actor, second_actor, state).moved

func try_teleport_actor(actor, target_cell: Vector2i, state) -> bool:
	return resolve_teleport_actor(actor, target_cell, state).moved

func resolve_move_actor_to_cell(actor, target_cell: Vector2i, state):
	var result = MovementResultScript.new()
	result.setup_single(MovementResultScript.KIND_MOVE, actor, actor.grid_pos if actor != null else Vector2i.ZERO, actor.grid_pos if actor != null else Vector2i.ZERO)
	result.target_cell = target_cell
	if actor == null or state == null or state.grid == null:
		result.mark_blocked(&"invalid_state", target_cell)
		return result
	if not state.grid.can_enter(target_cell):
		result.mark_blocked(&"blocked", target_cell)
		return result

	var from_cell: Vector2i = actor.grid_pos
	if not state.grid.move_actor(actor, target_cell):
		result.mark_blocked(&"move_failed", target_cell)
		return result

	result.setup_single(MovementResultScript.KIND_MOVE, actor, from_cell, target_cell, target_cell - from_cell, 1, 1)
	_emit_movement_result(result)
	return result

func resolve_forced_directional_move(actor, direction: Vector2i, distance: int, state, movement_kind: StringName):
	var origin: Vector2i = actor.grid_pos if actor != null else Vector2i.ZERO
	var result = MovementResultScript.new()
	result.setup_single(movement_kind, actor, origin, origin, direction, distance, 0)
	if actor == null or state == null or state.grid == null or direction == Vector2i.ZERO or distance <= 0:
		result.mark_blocked(&"invalid_request", origin)
		return result

	var final_cell: Vector2i = origin
	for _step in range(distance):
		var next_cell: Vector2i = actor.grid_pos + direction
		if not state.grid.can_enter(next_cell):
			result.blocked = true
			result.blocked_reason = &"blocked"
			result.target_cell = next_cell
			break
		var step_result = resolve_move_actor_to_cell(actor, next_cell, state)
		if not step_result.moved:
			result.blocked = true
			result.blocked_reason = step_result.blocked_reason
			result.target_cell = next_cell
			break
		result.moved_steps += 1
		final_cell = actor.grid_pos

	result.to_cell = final_cell
	result.moved = result.moved_steps > 0
	if not result.moved and not result.blocked:
		result.mark_blocked(&"no_progress", origin)
	return result

func resolve_swap_actors(first_actor, second_actor, state):
	var result = MovementResultScript.new()
	var first_from: Vector2i = first_actor.grid_pos if first_actor != null else Vector2i.ZERO
	var second_from: Vector2i = second_actor.grid_pos if second_actor != null else Vector2i.ZERO
	result.setup_swap(first_actor, second_actor, first_from, first_from, second_from, second_from)
	if first_actor == null or second_actor == null or state == null or state.grid == null:
		result.mark_blocked(&"invalid_state", first_from)
		return result
	if first_actor == second_actor:
		result.mark_blocked(&"same_actor", first_from)
		return result
	if first_from == second_from:
		result.mark_blocked(&"same_cell", first_from)
		return result
	if not state.grid.is_inside(first_from) or not state.grid.is_inside(second_from):
		result.mark_blocked(&"outside_grid", first_from)
		return result
	if state.grid.is_blocked(first_from) or state.grid.is_blocked(second_from):
		result.mark_blocked(&"blocked", first_from)
		return result

	state.grid.remove_actor(first_actor)
	state.grid.remove_actor(second_actor)
	var first_ok: bool = state.grid.place_actor(first_actor, second_from)
	var second_ok: bool = state.grid.place_actor(second_actor, first_from)
	if not first_ok or not second_ok:
		state.grid.remove_actor(first_actor)
		state.grid.remove_actor(second_actor)
		state.grid.place_actor(first_actor, first_from)
		state.grid.place_actor(second_actor, second_from)
		result.mark_blocked(&"place_failed", first_from)
		return result

	result.setup_swap(first_actor, second_actor, first_from, second_from, second_from, first_from)
	_emit_swap_result(result)
	return result

func resolve_teleport_actor(actor, target_cell: Vector2i, state):
	var from_cell: Vector2i = actor.grid_pos if actor != null else Vector2i.ZERO
	var result = MovementResultScript.new()
	result.setup_single(MovementResultScript.KIND_TELEPORT, actor, from_cell, from_cell, target_cell - from_cell, 1, 0)
	result.target_cell = target_cell
	if actor == null or state == null or state.grid == null:
		result.mark_blocked(&"invalid_state", target_cell)
		return result
	if not state.grid.can_enter(target_cell):
		result.mark_blocked(&"blocked", target_cell)
		return result

	if not state.grid.move_actor(actor, target_cell):
		result.mark_blocked(&"move_failed", target_cell)
		return result

	result.setup_single(MovementResultScript.KIND_TELEPORT, actor, from_cell, target_cell, target_cell - from_cell, 1, 1)
	_emit_teleport_result(result)
	return result

func add_rule_message(message: String) -> void:
	if message.is_empty():
		return
	rule_message.emit(message)

func add_state_message(state, message: String) -> void:
	_add_message(state, message)

func emit_combat_event(event) -> void:
	if event == null:
		return
	combat_event_emitted.emit(event)

func _kill_actor(actor, state) -> void:
	var death_cell: Vector2i = actor.grid_pos
	var dropped_key := _resolve_drop_key_for_actor(actor)
	state.grid.remove_actor(actor)
	if not dropped_key.is_empty():
		state.drop_key_at(death_cell, dropped_key)
	actor_died.emit(actor)
	_append_presentation_frame("actor_died", {
		"actor": actor,
	})
	if not dropped_key.is_empty():
		_add_message(state, "%s 掉落了%s按键。" % [actor.def.display_name, state.key_name(dropped_key)])
	_add_message(state, "%s 倒下。" % actor.def.display_name)
	_check_battle_end(state)


func _resolve_drop_key_for_actor(actor) -> String:
	if actor == null or String(actor.team) != "enemy":
		return ""
	if not String(actor.drop_key).is_empty():
		return String(actor.drop_key)
	var random_service = get_node_or_null("/root/RandomService")
	return String(TokenDropTableScript.pick_drop_key(int(actor.drop_tier), random_service))

func _check_battle_end(state) -> void:
	if state.is_safe_training:
		return
	if bool(state.is_world_slice):
		if state.player == null or state.player.is_dead():
			state.battle_finished = true
			state.victory = false
			_add_message(state, "鐜╁鍊掍笅浜嗐€?")
		return

	if state.player == null or state.player.is_dead():
		state.battle_finished = true
		state.victory = false
		_add_message(state, "玩家倒下了。")
		return

	if state.get_alive_enemies().is_empty():
		state.battle_finished = true
		state.victory = true
		_add_message(state, "房间清空。")

func _add_message(state, message: String) -> void:
	state.add_message(message)
	rule_message.emit(message)

func resolve_action_chain_finished(actor, actions: Array, state) -> void:
	pass

func _emit_attack_miss_event(actor, action, target_cell: Vector2i, direction: Vector2i) -> void:
	var event = EffectEventScript.new()
	event.event_type = EffectEventScript.TYPE_ATTACK_MISSED_CONFIRMED
	event.source = actor
	event.actor = actor
	event.action = action
	event.from_cell = actor.grid_pos if actor != null else Vector2i.ZERO
	event.to_cell = target_cell
	event.direction = direction
	if action != null and action.def != null:
		event.add_tag(StringName(action.def.id))
		if int(action.def.kind) == int(ActionDefScript.ActionKind.ATTACK):
			event.add_tag(&"attack")
	emit_combat_event(event)

func _get_action_momentum_speed(action) -> int:
	return maxi(1, int(action.momentum_speed))

func _emit_movement_result(result) -> void:
	if result == null or not result.moved:
		return
	actor_moved.emit(result.actor, result.from_cell, result.to_cell)
	_append_presentation_frame("actor_moved", {
		"actor": result.actor,
		"from_cell": result.from_cell,
		"to_cell": result.to_cell,
	})

func _emit_swap_result(result) -> void:
	if result == null or not result.moved:
		return
	actor_moved.emit(result.actor, result.from_cell, result.to_cell)
	actor_moved.emit(result.secondary_actor, result.secondary_from_cell, result.secondary_to_cell)
	_append_presentation_frame("swap", {
		"actor": result.actor,
		"target": result.secondary_actor,
		"from_cell": result.from_cell,
		"to_cell": result.to_cell,
		"target_from_cell": result.secondary_from_cell,
		"target_to_cell": result.secondary_to_cell,
	})

func _emit_teleport_result(result) -> void:
	if result == null or not result.moved:
		return
	actor_moved.emit(result.actor, result.from_cell, result.to_cell)
	_append_presentation_frame("teleport", {
		"actor": result.actor,
		"from_cell": result.from_cell,
		"to_cell": result.to_cell,
		"direction": result.direction,
	})

func _get_effect_modifiers(source, state) -> Array:
	var modifiers: Array = []
	if state != null:
		for modifier in state.effect_modifiers:
			if modifier != null:
				modifiers.append(modifier)
	if source != null:
		for modifier in source.effect_modifiers:
			if modifier != null:
				modifiers.append(modifier)
	return modifiers

func on_actor_entered_cell(actor, state) -> void:
	_try_pickup_key(actor, state)

func _try_pickup_key(actor, state) -> void:
	if actor.team != "player":
		return

	var key_id: String = state.pickup_key_at(actor.grid_pos)
	if key_id.is_empty():
		return

	key_picked.emit(actor, key_id, actor.grid_pos)
	_add_message(state, "拾取了%s按键。" % state.key_name(key_id))
