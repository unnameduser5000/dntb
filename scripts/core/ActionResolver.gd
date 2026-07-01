class_name ActionResolver
extends Node

const CombatContextScript := preload("res://scripts/runtime/CombatContext.gd")
const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")
const EffectPacketScript := preload("res://scripts/runtime/EffectPacket.gd")
const EffectPipelineScript := preload("res://scripts/runtime/EffectPipeline.gd")

signal actor_moved(actor, from_cell: Vector2i, to_cell: Vector2i)
signal actor_damaged(actor, amount: int)
signal actor_died(actor)
signal attack_missed(actor, target_cell: Vector2i)
signal key_picked(actor, key_id: String, cell: Vector2i)
signal rule_message(message: String)
signal combat_event_emitted(event)

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
		ActionDef.ActionKind.MOVE:
			_resolve_move(action, state)

		ActionDef.ActionKind.ATTACK:
			if action.def.id == "lunge":
				_resolve_lunge(action, state)
			else:
				_resolve_attack(action, state)

		ActionDef.ActionKind.TURN:
			_resolve_turn(action, state)

		ActionDef.ActionKind.WAIT:
			_add_message(state, "%s 等待。" % action.actor.def.display_name)

		ActionDef.ActionKind.GUARD:
			_resolve_guard(action, state)

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
			if not _resolve_move_collision(action, blocking_actor, dir, state):
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

func _resolve_attack(action, state) -> void:
	var actor = action.actor
	var dir = _get_action_dir(action)
	var attack_cells = _get_attack_cells(action)
	var hit_any := false

	for target_cell in attack_cells:
		var target = state.grid.get_actor(target_cell)
		if target == null or target.team == actor.team:
			continue

		hit_any = true
		var damage: int = int(actor.atk) * int(action.def.power)
		var hit_context = _make_attack_hit_context(action, target, target_cell, dir, damage, state)
		var handled_by_weapon := _resolve_weapon_attack_hit(hit_context)
		hit_context.hit_handled_by_weapon = handled_by_weapon
		if not handled_by_weapon:
			apply_effect_damage(actor, target, damage, state, action, [&"attack"])
		_run_weapon_after_attack_hit(hit_context)

	if not hit_any:
		var miss_cell: Vector2i = actor.grid_pos + dir
		if not _resolve_weapon_attack_miss(action, miss_cell, dir, state):
			attack_missed.emit(actor, miss_cell)
			_emit_attack_miss_event(actor, action, miss_cell, dir)
			_append_presentation_frame("attack_missed", {
				"actor": actor,
				"target_cell": miss_cell,
				"direction": dir,
				"speed": _get_action_momentum_speed(action),
			})
			_add_message(state, "%s 攻击落空。" % actor.def.display_name)

func _resolve_lunge(action, state) -> void:
	var actor = action.actor
	# Transitional note:
	# lunge is still implemented as a concrete action resource and currently
	# resolves from actor.facing at runtime. If future combo/technique work
	# wants "chosen technique direction" to be authoritative, this is one of
	# the places that will need to be revisited.
	#
	# Current consequence:
	# - preview / derived-technique build may decide lunge from token pattern
	# - runtime strike direction still comes from actor.facing at resolve time
	var dir := _get_action_dir(action)
	if dir == Vector2i.ZERO:
		dir = actor.facing
	else:
		actor.facing = dir

	var target_cell = actor.grid_pos + dir
	var target = state.grid.get_actor(target_cell)

	if target != null and target.team != actor.team:
		_add_message(state, "%s 突刺命中。" % actor.def.display_name)
		var damage: int = int(actor.atk) * int(action.def.power)
		var hit_context = _make_attack_hit_context(action, target, target_cell, dir, damage, state)
		var handled_by_weapon := _resolve_weapon_attack_hit(hit_context)
		hit_context.hit_handled_by_weapon = handled_by_weapon
		if not handled_by_weapon:
			apply_effect_damage(actor, target, damage, state, action, [&"attack", &"lunge"])
		_run_weapon_after_attack_hit(hit_context)
		return

	_resolve_move(action, state)

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

func _get_action_dir(action) -> Vector2i:
	# Direction priority:
	# 1. chosen_dir when the action explicitly carries an absolute direction
	# 2. backward relative to current facing for move_back
	# 3. current facing for facing-based move / attack actions
	if action.chosen_dir != Vector2i.ZERO:
		return action.chosen_dir

	if action.def.id == "move_back":
		return -action.actor.facing

	return action.actor.facing

func _get_attack_cells(action) -> Array[Vector2i]:
	var actor = action.actor
	var dir = _get_action_dir(action)
	if action.def.id == "sweep" or action.def.id == "great_sweep":
		var left := Vector2i(dir.y, -dir.x)
		var right := Vector2i(-dir.y, dir.x)
		return [
			actor.grid_pos + left,
			actor.grid_pos + dir,
			actor.grid_pos + right,
		]

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
	var from_cell = actor.grid_pos
	if state.grid.move_actor(actor, target_cell):
		actor_moved.emit(actor, from_cell, target_cell)
		_append_presentation_frame("actor_moved", {
			"actor": actor,
			"from_cell": from_cell,
			"to_cell": target_cell,
		})
		return true
	return false

func try_knockback(actor, direction: Vector2i, distance: int, state) -> int:
	if actor == null or direction == Vector2i.ZERO or distance <= 0:
		return 0

	var moved := 0
	for step in range(distance):
		var target_cell: Vector2i = actor.grid_pos + direction
		if not state.grid.can_enter(target_cell):
			break
		if try_move_actor(actor, target_cell, state):
			moved += 1

	return moved

func try_pull_actor(actor, direction: Vector2i, distance: int, state) -> int:
	if actor == null or direction == Vector2i.ZERO or distance <= 0:
		return 0

	var moved := 0
	for _step in range(distance):
		var target_cell: Vector2i = actor.grid_pos + direction
		if not state.grid.can_enter(target_cell):
			break
		if try_move_actor(actor, target_cell, state):
			moved += 1

	return moved

func try_swap_actors(first_actor, second_actor, state) -> bool:
	if first_actor == null or second_actor == null or state == null or state.grid == null:
		return false
	if first_actor == second_actor:
		return false

	var first_from: Vector2i = first_actor.grid_pos
	var second_from: Vector2i = second_actor.grid_pos
	if first_from == second_from:
		return false
	if not state.grid.is_inside(first_from) or not state.grid.is_inside(second_from):
		return false
	if state.grid.is_blocked(first_from) or state.grid.is_blocked(second_from):
		return false

	state.grid.remove_actor(first_actor)
	state.grid.remove_actor(second_actor)
	var first_ok: bool = state.grid.place_actor(first_actor, second_from)
	var second_ok: bool = state.grid.place_actor(second_actor, first_from)
	if not first_ok or not second_ok:
		state.grid.remove_actor(first_actor)
		state.grid.remove_actor(second_actor)
		state.grid.place_actor(first_actor, first_from)
		state.grid.place_actor(second_actor, second_from)
		return false

	actor_moved.emit(first_actor, first_from, second_from)
	actor_moved.emit(second_actor, second_from, first_from)
	_append_presentation_frame("swap", {
		"actor": first_actor,
		"target": second_actor,
		"from_cell": first_from,
		"to_cell": second_from,
		"target_from_cell": second_from,
		"target_to_cell": first_from,
	})
	return true

func try_teleport_actor(actor, target_cell: Vector2i, state) -> bool:
	if actor == null or state == null or state.grid == null:
		return false
	if not state.grid.can_enter(target_cell):
		return false

	var from_cell: Vector2i = actor.grid_pos
	if not state.grid.move_actor(actor, target_cell):
		return false
	actor_moved.emit(actor, from_cell, target_cell)
	_append_presentation_frame("teleport", {
		"actor": actor,
		"from_cell": from_cell,
		"to_cell": target_cell,
		"direction": target_cell - from_cell,
	})
	return true

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
	state.grid.remove_actor(actor)
	actor_died.emit(actor)
	_append_presentation_frame("actor_died", {
		"actor": actor,
	})
	_add_message(state, "%s 倒下。" % actor.def.display_name)
	_check_battle_end(state)

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

func _resolve_move_collision(action, target, direction: Vector2i, state) -> bool:
	var actor = action.actor
	if target == null or target.team == actor.team:
		return false

	_append_presentation_frame("move_collision", {
		"source": actor,
		"target": target,
		"target_cell": target.grid_pos,
		"direction": direction,
		"speed": maxi(_get_action_momentum_speed(action), maxi(1, int(action.chain_speed))),
	})

	var weapon = actor.active_weapon
	if weapon == null or not weapon.has_method("resolve_move_collision"):
		return false

	var context = CombatContextScript.new()
	context.setup_move_collision(state, action, actor, target, direction, max(1, int(action.chain_speed)))
	return bool(weapon.resolve_move_collision(context, self))

func _resolve_weapon_attack_hit(context) -> bool:
	if context == null:
		return false
	var actor = context.source
	var weapon = actor.active_weapon
	if weapon == null or not weapon.has_method("resolve_attack_hit"):
		return false
	return bool(weapon.resolve_attack_hit(context, self))

func _run_weapon_after_attack_hit(context) -> void:
	if context == null or context.source == null:
		return
	var weapon = context.source.active_weapon
	if weapon == null or not weapon.has_method("after_attack_hit"):
		return
	weapon.after_attack_hit(context, self)

func _resolve_weapon_attack_miss(action, target_cell: Vector2i, direction: Vector2i, state) -> bool:
	var actor = action.actor
	var weapon = actor.active_weapon
	if weapon == null or not weapon.has_method("resolve_attack_miss"):
		return false

	var context = CombatContextScript.new()
	context.setup_attack_miss(state, action, actor, target_cell, direction, _get_action_momentum_speed(action))
	return bool(weapon.resolve_attack_miss(context, self))

func resolve_action_chain_finished(actor, actions: Array, state) -> void:
	if actor == null:
		return

	var weapon = actor.active_weapon
	if weapon == null or not weapon.has_method("resolve_action_chain_finished"):
		return

	var context = CombatContextScript.new()
	context.setup_action_chain_finished(state, actor, actions)
	weapon.resolve_action_chain_finished(context, self)

func _make_attack_hit_context(action, target, target_cell: Vector2i, direction: Vector2i, damage: int, state):
	var context = CombatContextScript.new()
	context.setup_attack_hit(state, action, action.actor, target, target_cell, direction, damage, _get_action_momentum_speed(action))
	return context

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
		if int(action.def.kind) == int(ActionDef.ActionKind.ATTACK):
			event.add_tag(&"attack")
	emit_combat_event(event)

func _get_action_momentum_speed(action) -> int:
	return maxi(1, int(action.momentum_speed))

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

	#state.add_key(key_id, 1)
	key_picked.emit(actor, key_id, actor.grid_pos)
	_add_message(state, "拾取了%s按键。" % state.key_name(key_id))
