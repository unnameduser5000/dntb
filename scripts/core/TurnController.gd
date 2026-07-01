class_name TurnController
extends Node

const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")
const ActionTraceScript := preload("res://scripts/runtime/ActionTrace.gd")
const ActionTraceRecorderScript := preload("res://scripts/core/ActionTraceRecorder.gd")
const WeaponComboResolverScript := preload("res://scripts/core/WeaponComboResolver.gd")
const EffectEventScript := preload("res://scripts/runtime/EffectEvent.gd")

signal planning_started
signal action_started(action)
signal action_finished(action)
signal turn_finished
signal battle_finished(victory: bool)

var state
var resolver
var enemy_planner
var player_plan: Array = []
var presentation_controller = null
var action_trace_recorder = ActionTraceRecorderScript.new()
var weapon_combo_resolver = WeaponComboResolverScript.new()
var _next_plan_chain_id: int = 0
var _active_plan_chain_id: int = -1

## Each battle starts with a fresh trace history.
## The trace is battle-scoped, not run-scoped, because upcoming combo /
## interference work should reason about recent execution context instead of
## accumulating one giant cross-room history by default.
func start_battle(new_state) -> void:
	state = new_state
	_next_plan_chain_id = 0
	_active_plan_chain_id = -1
	if state != null and state.action_trace == null:
		state.action_trace = ActionTraceScript.new()
	if state != null and state.action_trace != null:
		state.action_trace.clear()
	if state != null:
		state.clear_weapon_combo_matches()
	state.phase = "planning"
	planning_started.emit()

func submit_player_plan(plan: Array) -> void:
	if state == null or state.phase != "planning" or state.battle_finished:
		return

	player_plan = plan
	_active_plan_chain_id = _next_plan_chain_id
	_next_plan_chain_id += 1
	_prepare_action_chain(player_plan)
	if _should_wait_for_presentation():
		_execute_turn_async()
	else:
		execute_turn()

func execute_turn() -> void:
	state.phase = "executing"

	for action in player_plan:
		if action.actor.is_dead():
			continue

		action_started.emit(action)
		_present_action_started_non_blocking(action)
		# Capture pre-action state so ActionTrace records what this step meant
		# relative to the actor's state when it was issued.
		var actor_before_cell: Vector2i = action.actor.grid_pos
		var actor_before_facing: Vector2i = action.actor.facing
		resolver.resolve(action, state)
		_record_action_trace(action, actor_before_cell, actor_before_facing)
		_present_pending_frames_non_blocking()
		action_finished.emit(action)

		if _check_battle_end():
			return

	_resolve_action_chain_finished(player_plan)
	var player_followup_interrupted := _execute_combo_followups_for_plan(player_plan)
	_present_pending_frames_non_blocking()
	if player_followup_interrupted:
		return
	if _check_battle_end():
		return

	if enemy_planner != null:
		var enemy_plan = enemy_planner.make_enemy_actions(state)
		_active_plan_chain_id = _next_plan_chain_id
		_next_plan_chain_id += 1
		_prepare_action_chain(enemy_plan)
		for action in enemy_plan:
			if action.actor.is_dead():
				continue

			action_started.emit(action)
			_present_action_started_non_blocking(action)
			var actor_before_cell: Vector2i = action.actor.grid_pos
			var actor_before_facing: Vector2i = action.actor.facing
			resolver.resolve(action, state)
			_record_action_trace(action, actor_before_cell, actor_before_facing)
			_present_pending_frames_non_blocking()
			action_finished.emit(action)

			if _check_battle_end():
				return

		_resolve_action_chain_finished(enemy_plan)
		var enemy_followup_interrupted := _execute_combo_followups_for_plan(enemy_plan)
		_present_pending_frames_non_blocking()
		if enemy_followup_interrupted:
			return

	_finish_turn_cycle()

func _check_battle_end() -> bool:
	if not state.battle_finished:
		return false

	state.phase = "finished"
	battle_finished.emit(state.victory)
	return true

func _prepare_action_chain(plan: Array) -> void:
	var speed_by_actor: Dictionary = {}
	var dir_by_actor: Dictionary = {}
	for index in range(plan.size()):
		var action = plan[index]
		if action == null or action.actor == null:
			continue

		action.chain_index = index
		action.chain_id = _active_plan_chain_id
		var action_dir: Vector2i = _get_action_dir_for_chain(action)
		# Chain momentum is currently based on executable world-space direction,
		# not on later relative trace semantics. Repeated absolute directions
		# therefore build speed/momentum even before weapon-pattern systems read
		# ActionTrace.
		var actor_id: int = int(action.actor.id)
		var previous_dir: Vector2i = dir_by_actor.get(actor_id, Vector2i.ZERO)
		action.previous_dir = previous_dir
		if action_dir != Vector2i.ZERO and dir_by_actor.get(actor_id, Vector2i.ZERO) == action_dir:
			speed_by_actor[actor_id] = int(speed_by_actor.get(actor_id, 1)) + 1
		elif action_dir != Vector2i.ZERO:
			speed_by_actor[actor_id] = 1
		else:
			action.chain_speed = 1
			if action.def != null and action.def.id == "jump":
				speed_by_actor[actor_id] = 0
				dir_by_actor.erase(actor_id)

		if action_dir != Vector2i.ZERO:
			dir_by_actor[actor_id] = action_dir
			action.chain_speed = int(speed_by_actor.get(actor_id, 1))

		action.momentum_dir = dir_by_actor.get(actor_id, Vector2i.ZERO)
		action.momentum_speed = int(speed_by_actor.get(actor_id, 0))

func _get_action_dir_for_chain(action) -> Vector2i:
	# This helper mirrors the executable direction used for chain-speed /
	# momentum tracking before the action resolves.
	#
	# jump is intentionally excluded from directional momentum stacking for now:
	# it travels along facing, but it behaves as traversal rather than a shove or
	# charge step. That keeps impact-style collision scaling tied to repeated
	# grounded directional movement.
	if action.def != null and action.def.id == "jump":
		return Vector2i.ZERO
	if action.chosen_dir != Vector2i.ZERO:
		return action.chosen_dir
	if action.def != null and action.def.id == "move_back":
		return -action.actor.facing
	if action.def != null and action.def.kind == ActionDef.ActionKind.MOVE:
		return action.actor.facing
	return Vector2i.ZERO

func _resolve_action_chain_finished(plan: Array) -> void:
	if resolver == null or not resolver.has_method("resolve_action_chain_finished"):
		return

	var handled_actors: Dictionary = {}
	for action in plan:
		if action == null or action.actor == null:
			continue

		var actor = action.actor
		var actor_id: int = int(actor.id)
		if handled_actors.has(actor_id):
			continue
		handled_actors[actor_id] = true
		if actor.is_dead():
			continue

		resolver.resolve_action_chain_finished(actor, _get_actions_for_actor(plan, actor), state)

func _get_actions_for_actor(plan: Array, actor) -> Array:
	var result: Array = []
	for action in plan:
		if action != null and action.actor == actor:
			result.append(action)
	return result

func _should_wait_for_presentation() -> bool:
	return presentation_controller != null \
		and presentation_controller.has_method("should_wait_for_presentation") \
		and bool(presentation_controller.should_wait_for_presentation())

func _execute_turn_async() -> void:
	await _run_turn_with_presentation()

func _run_turn_with_presentation() -> void:
	state.phase = "executing"

	var player_interrupted: bool = await _execute_action_sequence_with_presentation(player_plan)
	if player_interrupted:
		return

	_resolve_action_chain_finished(player_plan)
	var player_followup_interrupted := await _execute_combo_followups_for_plan_async(player_plan)
	await _play_pending_presentation_frames()
	if player_followup_interrupted:
		return
	if _check_battle_end():
		return

	if enemy_planner != null:
		var enemy_plan: Array = enemy_planner.make_enemy_actions(state)
		_active_plan_chain_id = _next_plan_chain_id
		_next_plan_chain_id += 1
		_prepare_action_chain(enemy_plan)
		var enemy_interrupted: bool = await _execute_action_sequence_with_presentation(enemy_plan)
		if enemy_interrupted:
			return

		_resolve_action_chain_finished(enemy_plan)
		var enemy_followup_interrupted := await _execute_combo_followups_for_plan_async(enemy_plan)
		await _play_pending_presentation_frames()
		if enemy_followup_interrupted:
			return

	_finish_turn_cycle()

func _execute_action_sequence_with_presentation(actions: Array) -> bool:
	for action in actions:
		if action == null or action.actor == null or action.actor.is_dead():
			continue

		action_started.emit(action)
		await _play_action_started(action)
		# Async presentation path records the same trace semantics as the
		# headless path: snapshot before resolve, then record after resolve.
		var actor_before_cell: Vector2i = action.actor.grid_pos
		var actor_before_facing: Vector2i = action.actor.facing
		resolver.resolve(action, state)
		_record_action_trace(action, actor_before_cell, actor_before_facing)
		await _play_pending_presentation_frames()
		action_finished.emit(action)
		await _play_action_finished(action)

		if _check_battle_end():
			return true

	return false

func _play_action_started(action) -> void:
	if presentation_controller == null or not presentation_controller.has_method("play_action_started"):
		return
	await presentation_controller.play_action_started(action)

func _play_action_finished(action) -> void:
	if presentation_controller == null or not presentation_controller.has_method("play_action_finished"):
		return
	await presentation_controller.play_action_finished(action)

func _play_pending_presentation_frames() -> void:
	if resolver == null or not resolver.has_method("consume_presentation_frames"):
		return

	var frames: Array = resolver.consume_presentation_frames()
	if frames.is_empty():
		return
	if presentation_controller == null or not presentation_controller.has_method("play_frames"):
		return
	await presentation_controller.play_frames(frames)

func _clear_pending_presentation_frames() -> void:
	if resolver != null and resolver.has_method("clear_presentation_frames"):
		resolver.clear_presentation_frames()


func _present_pending_frames_non_blocking() -> void:
	if resolver == null or not resolver.has_method("consume_presentation_frames"):
		return
	var frames: Array = resolver.consume_presentation_frames()
	if frames.is_empty():
		return
	if presentation_controller != null and presentation_controller.has_method("present_frames_non_blocking"):
		presentation_controller.present_frames_non_blocking(frames)

func _finish_turn_cycle() -> void:
	state.clear_temporary_flags()
	state.turn_count += 1
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null and not state.is_safe_training and not bool(state.is_world_slice):
		curse_service.tick_turn()
	state.phase = "planning"
	turn_finished.emit()
	planning_started.emit()


func _record_action_trace(action, actor_before_cell: Vector2i, actor_before_facing: Vector2i) -> void:
	if state == null or state.action_trace == null or action_trace_recorder == null:
		return
	action_trace_recorder.record_action(state.action_trace, action, actor_before_cell, actor_before_facing)


func _execute_combo_followups_for_plan(plan: Array) -> bool:
	if state == null or state.action_trace == null or weapon_combo_resolver == null:
		return false

	for combo_data in _collect_combo_matches_for_plan(plan, WeaponTechniqueDef.TriggerTiming.AFTER_CHAIN):
		var actor = combo_data.get("actor")
		var source_actions: Array = combo_data.get("actions", [])
		var matches: Array = combo_data.get("matches", [])
		for match_data in matches:
			if match_data.is_empty():
				continue
			if _execute_combo_followup_action(actor, source_actions, match_data):
				return true
	return false


func _execute_combo_followups_for_plan_async(plan: Array) -> bool:
	if state == null or state.action_trace == null or weapon_combo_resolver == null:
		return false

	for combo_data in _collect_combo_matches_for_plan(plan, WeaponTechniqueDef.TriggerTiming.AFTER_CHAIN):
		var actor = combo_data.get("actor")
		var source_actions: Array = combo_data.get("actions", [])
		var matches: Array = combo_data.get("matches", [])
		for match_data in matches:
			if match_data.is_empty():
				continue
			if await _execute_combo_followup_action_async(actor, source_actions, match_data):
				return true
	return false


func _collect_combo_matches_for_plan(plan: Array, trigger_timing: int) -> Array:
	var results: Array = []
	if state == null or state.action_trace == null or weapon_combo_resolver == null:
		return results

	# Combo recognition is evaluated from the real ActionTrace after base actions
	# finish resolving. This keeps terrain/collision/effect changes in scope:
	# KeyProgram predicts intent, but weapon techniques trigger from what really
	# happened in combat.
	var handled_actors: Dictionary = {}
	for action in plan:
		if action == null or action.actor == null:
			continue

		var actor = action.actor
		var actor_id: int = int(actor.id)
		if handled_actors.has(actor_id):
			continue
		handled_actors[actor_id] = true

		var actor_actions := _get_actions_for_actor(plan, actor)
		var plan_chain_id := _plan_chain_id_for_actions(actor_actions)
		var current_entries: Array = []
		for entry in state.action_trace.get_recent_entries_for_actor(actor_id):
			if entry == null:
				continue
			if plan_chain_id >= 0 and int(entry.chain_id) == plan_chain_id:
				current_entries.append(entry)

		var matches: Array = weapon_combo_resolver.find_matches_for_entries(
			actor,
			current_entries,
			state.unlocked_weapon_technique_ids,
			trigger_timing
		)
		state.set_weapon_combo_matches_for_actor(actor_id, matches)
		results.append({
			"actor": actor,
			"actor_id": actor_id,
			"actions": actor_actions,
			"matches": matches,
		})

	return results


func _execute_combo_followup_action(actor, source_actions: Array, match_data: Dictionary) -> bool:
	var followup_action = _build_combo_followup_action(actor, source_actions, match_data)
	if followup_action == null:
		return false

	action_started.emit(followup_action)
	_present_action_started_non_blocking(followup_action)
	_announce_combo_followup(actor, match_data)
	resolver.resolve(followup_action, state)
	_present_pending_frames_non_blocking()
	action_finished.emit(followup_action)
	return _check_battle_end()


func _execute_combo_followup_action_async(actor, source_actions: Array, match_data: Dictionary) -> bool:
	var followup_action = _build_combo_followup_action(actor, source_actions, match_data)
	if followup_action == null:
		return false

	action_started.emit(followup_action)
	await _play_action_started(followup_action)
	_announce_combo_followup(actor, match_data)
	resolver.resolve(followup_action, state)
	await _play_pending_presentation_frames()
	action_finished.emit(followup_action)
	await _play_action_finished(followup_action)
	return _check_battle_end()


func _build_combo_followup_action(actor, source_actions: Array, match_data: Dictionary):
	if actor == null:
		return null

	var technique = match_data.get("technique")
	if technique == null or not technique.has_method("resolved_action"):
		return null

	var action_def = technique.resolved_action()
	if action_def == null:
		return null

	var action = ActionInstanceScript.new()
	action.actor = actor
	action.def = action_def
	action.key_id = "technique:%s" % String(match_data.get("technique_id", ""))
	action.chain_index = source_actions.size()
	action.chain_id = _plan_chain_id_for_actions(source_actions)

	if not source_actions.is_empty():
		var last_action = source_actions[source_actions.size() - 1]
		if last_action != null:
			action.previous_dir = last_action.previous_dir
			action.chain_speed = max(1, int(last_action.chain_speed))
			action.momentum_dir = last_action.momentum_dir
			action.momentum_speed = int(last_action.momentum_speed)

	var matched_move_dir := Vector2i(match_data.get("matched_move_dir", Vector2i.ZERO))
	if matched_move_dir != Vector2i.ZERO:
		action.chosen_dir = matched_move_dir
		action.previous_dir = matched_move_dir
		action.momentum_dir = matched_move_dir

	return action


func _plan_chain_id_for_actions(actions: Array) -> int:
	for action in actions:
		if action != null:
			return int(action.chain_id)
	return -1


func _announce_combo_followup(actor, match_data: Dictionary) -> void:
	if actor == null or state == null or resolver == null:
		return

	var technique = match_data.get("technique")
	if technique == null:
		return

	var display_name := String(technique.display_name)
	if display_name.is_empty():
		display_name = String(match_data.get("technique_id", ""))
	if display_name.is_empty():
		return

	_append_combo_presentation(actor, display_name, match_data)
	_emit_combo_triggered_event(actor, display_name, match_data)
	resolver.add_state_message(state, "%s 触发武器技：%s" % [actor.def.display_name, display_name])


func _present_action_started_non_blocking(action) -> void:
	if presentation_controller == null or not presentation_controller.has_method("present_action_started_non_blocking"):
		return
	presentation_controller.present_action_started_non_blocking(action)


func _append_combo_presentation(actor, display_name: String, match_data: Dictionary) -> void:
	if resolver == null or not resolver.has_method("_append_presentation_frame"):
		return
	resolver._append_presentation_frame("combo_triggered", {
		"actor": actor,
		"direction": Vector2i(match_data.get("matched_move_dir", actor.facing if actor != null else Vector2i.RIGHT)),
		"technique_id": String(match_data.get("technique_id", "")),
		"display_name": display_name,
	})


func _emit_combo_triggered_event(actor, display_name: String, match_data: Dictionary) -> void:
	if resolver == null or not resolver.has_method("emit_combat_event"):
		return
	var event = EffectEventScript.new()
	event.event_type = EffectEventScript.TYPE_COMBO_TRIGGERED
	event.source = actor
	event.actor = actor
	event.target = actor
	event.from_cell = actor.grid_pos if actor != null else Vector2i.ZERO
	event.to_cell = actor.grid_pos if actor != null else Vector2i.ZERO
	event.direction = Vector2i(match_data.get("matched_move_dir", actor.facing if actor != null else Vector2i.RIGHT))
	event.metadata["technique_id"] = String(match_data.get("technique_id", ""))
	event.metadata["display_name"] = display_name
	for symbol in match_data.get("matched_symbols", []):
		event.add_tag(StringName(symbol))
	resolver.emit_combat_event(event)
