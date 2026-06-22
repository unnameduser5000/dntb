class_name TurnController
extends Node

signal planning_started
signal action_started(action)
signal action_finished(action)
signal turn_finished
signal battle_finished(victory: bool)

var state
var resolver
var enemy_planner
var player_plan: Array = []

func start_battle(new_state) -> void:
	state = new_state
	state.phase = "planning"
	planning_started.emit()

func submit_player_plan(plan: Array) -> void:
	if state == null or state.phase != "planning" or state.battle_finished:
		return

	player_plan = plan
	_prepare_action_chain(player_plan)
	execute_turn()

func execute_turn() -> void:
	state.phase = "executing"

	for action in player_plan:
		if action.actor.is_dead():
			continue

		action_started.emit(action)
		resolver.resolve(action, state)
		action_finished.emit(action)

		if _check_battle_end():
			return

	_resolve_action_chain_finished(player_plan)
	if _check_battle_end():
		return

	if enemy_planner != null:
		var enemy_plan = enemy_planner.make_enemy_actions(state)
		for action in enemy_plan:
			if action.actor.is_dead():
				continue

			action_started.emit(action)
			resolver.resolve(action, state)
			action_finished.emit(action)

			if _check_battle_end():
				return

	state.clear_temporary_flags()
	state.turn_count += 1
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null and not state.is_safe_training:
		curse_service.tick_turn()
	state.phase = "planning"
	turn_finished.emit()
	planning_started.emit()

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
		var action_dir: Vector2i = _get_action_dir_for_chain(action)
		var actor_id: int = int(action.actor.id)
		var previous_dir: Vector2i = dir_by_actor.get(actor_id, Vector2i.ZERO)
		action.previous_dir = previous_dir
		if action_dir != Vector2i.ZERO and dir_by_actor.get(actor_id, Vector2i.ZERO) == action_dir:
			speed_by_actor[actor_id] = int(speed_by_actor.get(actor_id, 1)) + 1
		elif action_dir != Vector2i.ZERO:
			speed_by_actor[actor_id] = 1
		else:
			action.chain_speed = 1

		if action_dir != Vector2i.ZERO:
			dir_by_actor[actor_id] = action_dir
			action.chain_speed = int(speed_by_actor.get(actor_id, 1))

		action.momentum_dir = dir_by_actor.get(actor_id, Vector2i.ZERO)
		action.momentum_speed = int(speed_by_actor.get(actor_id, 0))

func _get_action_dir_for_chain(action) -> Vector2i:
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
