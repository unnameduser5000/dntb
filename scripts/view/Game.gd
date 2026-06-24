extends Node

@export var show_title_on_ready := true

const GameStateScript := preload("res://scripts/core/GameState.gd")
const GridModelScript := preload("res://scripts/core/GridModel.gd")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")
const ActionProgramControllerScript := preload("res://scripts/core/ActionProgramController.gd")
const ActionPreviewServiceScript := preload("res://scripts/core/ActionPreviewService.gd")
const BattlePresentationControllerScript := preload("res://scripts/core/BattlePresentationController.gd")

const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const BOSS_DEF := preload("res://data/actors/boss.tres")

const ACTION_MOVE_FORWARD := preload("res://data/actions/move_forward.tres")
const ACTION_MOVE_BACK := preload("res://data/actions/move_back.tres")
const ACTION_TURN_LEFT := preload("res://data/actions/turn_left.tres")
const ACTION_TURN_RIGHT := preload("res://data/actions/turn_right.tres")
const ACTION_ATTACK := preload("res://data/actions/attack.tres")
const ACTION_WAIT := preload("res://data/actions/wait.tres")
const ACTION_GUARD := preload("res://data/actions/guard.tres")
const ACTION_LUNGE := preload("res://data/actions/lunge.tres")
const ACTION_SWEEP := preload("res://data/actions/sweep.tres")
const ACTION_MOVE_KEY := preload("res://data/actions/move_key.tres")

const MOD_ECHO_STRIKE := preload("res://data/modifiers/echo_strike.tres")
const MOD_ECHO_STEP := preload("res://data/modifiers/echo_step.tres")
const MOD_FORCE_PRISM := preload("res://data/modifiers/force_prism.tres")

const ROOM_SIZE := 8
const MAP_NODE_COMBAT := "combat"
const MAP_NODE_REST := "rest"
const MAP_NODE_BOSS := "boss"
const KEY_TOKEN_POOL_SLOT_ID := "POOL"

const ROOMS := [
	{
		"name": "练习房",
		"player": Vector2i(1, 1),
		"facing": Vector2i.RIGHT,
		"walls": [Rect2i(3, 3, 2, 1)],
		"keys": [
			{"key": "R", "cell": Vector2i(1, 2)},
		],
		"enemies": [
			{"def": "slime", "cell": Vector2i(3, 1)},
			{"def": "slime", "cell": Vector2i(5, 4)},
		],
	},
	{
		"name": "夹击房",
		"player": Vector2i(1, 5),
		"facing": Vector2i.RIGHT,
		"walls": [Rect2i(3, 2, 1, 4), Rect2i(5, 1, 1, 2)],
		"keys": [
			{"key": "U", "cell": Vector2i(2, 5)},
			{"key": "L", "cell": Vector2i(4, 1)},
		],
		"enemies": [
			{"def": "slime", "cell": Vector2i(5, 5)},
			{"def": "brute", "cell": Vector2i(6, 2)},
		],
	},
	{
		"name": "锁键者",
		"player": Vector2i(1, 6),
		"facing": Vector2i.RIGHT,
		"walls": [Rect2i(2, 2, 1, 3), Rect2i(5, 4, 2, 1)],
		"keys": [
			{"key": "D", "cell": Vector2i(1, 4)},
			{"key": "R", "cell": Vector2i(4, 6)},
		],
		"enemies": [
			{"def": "boss", "cell": Vector2i(6, 1)},
			{"def": "slime", "cell": Vector2i(6, 6)},
		],
	},
]

const MAP_NODES := [
	{
		"id": "node_0",
		"kind": MAP_NODE_REST,
		"label": "出发营地",
		"depth": 0,
		"heal": 0,
		"next": [1],
	},
	{
		"id": "node_1",
		"kind": MAP_NODE_COMBAT,
		"label": "练习房",
		"room": 0,
		"depth": 1,
		"next": [2],
	},
	{
		"id": "node_2",
		"kind": MAP_NODE_REST,
		"label": "练习后整备",
		"depth": 2,
		"heal": 0,
		"next": [3],
	},
	{
		"id": "node_3",
		"kind": MAP_NODE_COMBAT,
		"label": "精英前哨",
		"room": 1,
		"depth": 3,
		"next": [4],
	},
	{
		"id": "node_4",
		"kind": MAP_NODE_REST,
		"label": "休息处",
		"depth": 4,
		"heal": 3,
		"next": [5],
	},
	{
		"id": "node_5",
		"kind": MAP_NODE_BOSS,
		"label": "Boss 房",
		"room": 2,
		"depth": 5,
		"next": [],
	},
]

@onready var board_view = $BoardView
@onready var battle_ui = $CanvasLayer/BattleUI
@onready var turn_controller = $TurnController
@onready var resolver = $ActionResolver
@onready var enemy_planner = $EnemyPlanner

var state
var _next_actor_id := 0
var _current_map_node_index := 0
var _current_room_index := 0
var _run_player_max_hp := 8
var _run_player_hp := 8
var _run_player_max_san := 100
var _run_player_san := 100
var _run_player_atk := 2
var _run_seed = ""
var _player_deck: Array = []
var _action_by_id: Dictionary = {}
var _modifier_by_id: Dictionary = {}
var _run_modifier_ids: Array[String] = []
var _action_program
var _action_preview
var _battle_presentation
# 兼容测试/调试观察口：真实数据由 ActionProgramController 持有。
var _key_slots: Dictionary = {}
var _loose_key_tokens: Array[String] = []
var _current_rewards: Array = []
var _key_program_editable := false

func _ready() -> void:
	_action_by_id = {
		"move_forward": ACTION_MOVE_FORWARD,
		"move_back": ACTION_MOVE_BACK,
		"turn_left": ACTION_TURN_LEFT,
		"turn_right": ACTION_TURN_RIGHT,
		"attack": ACTION_ATTACK,
		"wait": ACTION_WAIT,
		"guard": ACTION_GUARD,
		"lunge": ACTION_LUNGE,
		"sweep": ACTION_SWEEP,
		"move_key": ACTION_MOVE_KEY,
	}
	_modifier_by_id = {
		"echo_strike": MOD_ECHO_STRIKE,
		"echo_step": MOD_ECHO_STEP,
		"force_prism": MOD_FORCE_PRISM,
	}
	_action_program = ActionProgramControllerScript.new()
	_action_program.setup(_action_by_id, ACTION_MOVE_KEY)
	_action_preview = ActionPreviewServiceScript.new()
	_action_preview.setup(_action_by_id)
	_battle_presentation = BattlePresentationControllerScript.new()
	_battle_presentation.setup(board_view, $ActorRoot)
	_sync_key_program_mirror()

	turn_controller.resolver = resolver
	turn_controller.enemy_planner = enemy_planner
	turn_controller.presentation_controller = _battle_presentation
	enemy_planner.enemies_are_static = false
	enemy_planner.move_action = ACTION_MOVE_FORWARD
	enemy_planner.attack_action = ACTION_ATTACK
	var enemy_spawn_service = get_node_or_null("/root/EnemySpawnService")
	if enemy_spawn_service != null:
		enemy_spawn_service.register_enemy_defs([SLIME_DEF, BRUTE_DEF, BOSS_DEF])

	_connect_signals()
	_register_save_provider()
	if show_title_on_ready:
		battle_ui.show_title()

func _unhandled_input(event: InputEvent) -> void:
	if state == null or state.phase != "planning" or state.battle_finished:
		return

	var input_service = get_node_or_null("/root/PlayerInputService")
	if input_service == null:
		return

	var action_name: String = input_service.get_pressed_move_action(event)
	if action_name.is_empty():
		return

	get_viewport().set_input_as_handled()
	var key_id: String = input_service.get_key_id_for_action(action_name)
	_submit_key_chain(key_id)

func set_game_visible(is_visible: bool) -> void:
	board_view.visible = is_visible
	$ActorRoot.visible = is_visible
	battle_ui.visible = is_visible

func _connect_signals() -> void:
	battle_ui.start_requested.connect(start_run)
	battle_ui.plan_submitted.connect(_on_plan_submitted)
	battle_ui.reward_chosen.connect(_on_reward_chosen)
	battle_ui.restart_requested.connect(start_run)
	battle_ui.key_token_move_requested.connect(_on_key_token_move_requested)
	battle_ui.key_slot_preview_requested.connect(_on_key_slot_preview_requested)
	battle_ui.key_slot_preview_cleared.connect(_on_key_slot_preview_cleared)
	battle_ui.rest_continue_requested.connect(_on_rest_continue_requested)
	turn_controller.action_finished.connect(func(_action) -> void: _refresh_views())
	turn_controller.turn_finished.connect(_refresh_views)
	turn_controller.planning_started.connect(_refresh_views)
	turn_controller.battle_finished.connect(_on_battle_finished)
	resolver.rule_message.connect(func(_message: String) -> void: _refresh_views())
	resolver.key_picked.connect(_on_key_picked)

func start_run() -> void:
	_start_new_run(Time.get_datetime_string_from_system())

func start_seeded_run(seed_value) -> void:
	_start_new_run(seed_value)

func _start_new_run(seed_value) -> void:
	_current_room_index = 0
	_current_map_node_index = 0
	_run_player_max_hp = PLAYER_DEF.max_hp
	_run_player_hp = _run_player_max_hp
	_run_player_max_san = PLAYER_DEF.max_san
	_run_player_san = _run_player_max_san
	_run_player_atk = PLAYER_DEF.atk
	_run_seed = str(seed_value)
	var random_service = get_node_or_null("/root/RandomService")
	if random_service != null:
		random_service.set_seed(_run_seed)
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null:
		curse_service.reset_run()
	_player_deck = [
		ACTION_MOVE_FORWARD,
		ACTION_TURN_LEFT,
		ACTION_TURN_RIGHT,
		ACTION_ATTACK,
		ACTION_WAIT,
	]
	_run_modifier_ids.clear()
	_setup_default_key_slots()
	_refresh_inventory_ui()
	_start_map_node(_current_map_node_index)

func _start_map_node(node_index: int) -> void:
	_current_map_node_index = clampi(node_index, 0, MAP_NODES.size() - 1)
	var node := _current_map_node()
	match String(node.get("kind", MAP_NODE_COMBAT)):
		MAP_NODE_REST:
			_start_rest_node(node)
		MAP_NODE_BOSS, MAP_NODE_COMBAT:
			_current_room_index = int(node.get("room", 0))
			_start_room(_current_room_index)
		_:
			_current_room_index = int(node.get("room", 0))
			_start_room(_current_room_index)

func _start_room(room_index: int) -> void:
	_next_actor_id = 0
	_key_program_editable = false
	state = _create_room_state(room_index)
	_clear_key_slot_preview(false)
	_apply_run_modifiers_to_player()
	if _battle_presentation != null:
		_battle_presentation.reset_for_state(state)
	enemy_planner.enemies_are_static = false
	turn_controller.start_battle(state)
	battle_ui.set_available_actions(_player_deck)
	battle_ui.set_key_program_editable(false)
	_refresh_key_program_ui()
	_refresh_inventory_ui()
	battle_ui.show_battle()
	_refresh_views()

func _start_rest_node(node: Dictionary) -> void:
	_next_actor_id = 0
	_key_program_editable = true
	state = _create_rest_state(node)
	_clear_key_slot_preview(false)
	_apply_run_modifiers_to_player()
	if _battle_presentation != null:
		_battle_presentation.reset_for_state(state)
	enemy_planner.enemies_are_static = true
	turn_controller.start_battle(state)
	battle_ui.set_available_actions(_player_deck)
	battle_ui.set_key_program_editable(true)
	_refresh_key_program_ui()
	_refresh_inventory_ui()
	battle_ui.show_rest_site(String(node.get("label", "休息处")), "这里可以拖拽调整行动 token 与按键槽，也可以直接按 WASD 在安全沙盘里试招。整理好后继续前进。")
	_refresh_views()

func _on_plan_submitted(action_ids: Array) -> void:
	if state == null or state.phase != "planning":
		return

	var plan: Array = []
	for action_id in action_ids:
		var action_def = _action_by_id.get(String(action_id))
		if action_def == null:
			continue

		var action = ActionInstanceScript.new()
		action.actor = state.player
		action.def = action_def
		plan.append(action)

	if not plan.is_empty():
		turn_controller.submit_player_plan(plan)

func _submit_key_chain(key_id: String) -> void:
	_clear_key_slot_preview(false)
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null and not _is_safe_training_state():
		var allowed: bool = curse_service.register_key_pressed(key_id, {
			"room_index": state.room_index,
			"turn_count": state.turn_count,
		})
		if not allowed:
			state.player.san = max(0, state.player.san - 5)
			state.add_message("诅咒触发：别按%s键。SAN -5。" % state.key_name(key_id))
			_refresh_views()
			return

	_ensure_action_helpers()
	var chain_keys: Array = _action_program.get_slot(key_id)
	if chain_keys.is_empty():
		state.add_message("%s键槽为空，什么也没有发生。" % state.key_name(key_id))
		_refresh_views()
		return

	var plan := _build_key_slot_plan(chain_keys)
	if not plan.is_empty():
		turn_controller.submit_player_plan(plan)

func _on_battle_finished(victory: bool) -> void:
	if state != null and state.player != null:
		_run_player_hp = max(0, state.player.hp)
		_run_player_san = max(0, state.player.san)

	if not victory:
		battle_ui.show_result(false)
		return

	_record_achievement_event("room_cleared", {
		"room_index": _current_room_index,
		"room_name": state.room_name if state != null else "",
		"seed": _run_seed,
	})

	if _is_current_boss_node() or _current_map_next_nodes().is_empty():
		_record_achievement_event("run_cleared", {
			"seed": _run_seed,
			"room_index": _current_room_index,
			"map_node_index": _current_map_node_index,
		})
		battle_ui.show_result(true)
		return

	_current_rewards = _build_rewards()
	battle_ui.show_reward(_current_rewards)

func _on_reward_chosen(index: int) -> void:
	if index < 0 or index >= _current_rewards.size():
		return

	_apply_reward(_current_rewards[index])
	_advance_to_next_map_node()

func _on_rest_continue_requested() -> void:
	if not _is_current_rest_node():
		return
	_clear_key_slot_preview(false)
	_key_program_editable = false
	_advance_to_next_map_node()

func _current_map_node() -> Dictionary:
	if MAP_NODES.is_empty():
		return {}
	var safe_index := clampi(_current_map_node_index, 0, MAP_NODES.size() - 1)
	return MAP_NODES[safe_index]

func _current_map_next_nodes() -> Array:
	var node := _current_map_node()
	return node.get("next", [])

func _is_current_rest_node() -> bool:
	return String(_current_map_node().get("kind", "")) == MAP_NODE_REST

func _is_current_boss_node() -> bool:
	return String(_current_map_node().get("kind", "")) == MAP_NODE_BOSS

func _is_safe_training_state() -> bool:
	return state != null and state.is_safe_training

func _advance_to_next_map_node(choice_index: int = 0) -> void:
	var next_nodes := _current_map_next_nodes()
	if next_nodes.is_empty():
		battle_ui.show_result(true)
		return

	var safe_choice := clampi(choice_index, 0, next_nodes.size() - 1)
	_start_map_node(int(next_nodes[safe_choice]))

func _map_summary() -> String:
	var labels: Array[String] = []
	for index in range(MAP_NODES.size()):
		var node: Dictionary = MAP_NODES[index]
		var label := String(node.get("label", node.get("kind", "?")))
		if index == _current_map_node_index:
			label = "[%s]" % label
		labels.append(label)
	return " -> ".join(labels)

func _refresh_views() -> void:
	if state == null:
		return

	_update_enemy_preview()
	if _battle_presentation != null:
		_battle_presentation.sync_views(state, not _battle_presentation.should_wait_for_presentation())
	board_view.render(state)
	battle_ui.update_state(state)

func _update_enemy_preview() -> void:
	if state.phase != "planning" or state.battle_finished:
		state.enemy_intents = []
		state.danger_cells = []
		state.preview_move_cells = []
		state.preview_attack_cells = []
		return

	var enemy_actions = enemy_planner.preview_enemy_actions(state)
	var intents: Array[String] = []
	for action in enemy_actions:
		intents.append(enemy_planner.describe_action(action))

	state.enemy_intents = intents
	state.danger_cells = enemy_planner.get_threat_cells(state)

func _create_room_state(room_index: int):
	var room: Dictionary = ROOMS[room_index]
	var new_state = GameStateScript.new()
	new_state.grid = GridModelScript.new()
	new_state.grid.setup(ROOM_SIZE, ROOM_SIZE)
	new_state.room_index = room_index
	new_state.room_name = String(room["name"])
	new_state.map_node_index = _current_map_node_index
	new_state.map_node_kind = String(_current_map_node().get("kind", MAP_NODE_COMBAT))
	new_state.map_node_label = String(_current_map_node().get("label", new_state.room_name))
	new_state.exit_cell = Vector2i(-99, -99)

	_add_room_walls(new_state.grid, room)
	_add_room_keys(new_state, room)
	var player = _add_actor(new_state, PLAYER_DEF, room["player"])
	player.facing = room["facing"]
	player.max_hp = _run_player_max_hp
	player.hp = min(_run_player_hp, _run_player_max_hp)
	player.max_san = _run_player_max_san
	player.san = min(_run_player_san, _run_player_max_san)
	player.atk = _run_player_atk

	for enemy_data in room["enemies"]:
		_add_actor(new_state, _enemy_def(String(enemy_data["def"])), enemy_data["cell"])

	new_state.add_message("路线：%s。进入%s，行动编码已锁定。" % [_map_summary(), new_state.room_name])
	return new_state

func _create_rest_state(node: Dictionary):
	var new_state = GameStateScript.new()
	new_state.grid = GridModelScript.new()
	new_state.grid.setup(ROOM_SIZE, ROOM_SIZE)
	new_state.room_index = _current_map_node_index
	new_state.room_name = String(node.get("label", "休息处"))
	new_state.map_node_index = _current_map_node_index
	new_state.map_node_kind = MAP_NODE_REST
	new_state.map_node_label = new_state.room_name
	new_state.is_safe_training = true
	new_state.exit_cell = Vector2i(-99, -99)
	_add_room_walls(new_state.grid, {"walls": []})

	var player = _add_actor(new_state, PLAYER_DEF, Vector2i(3, 3))
	player.facing = Vector2i.RIGHT
	player.max_hp = _run_player_max_hp
	player.hp = min(_run_player_hp, _run_player_max_hp)
	player.max_san = _run_player_max_san
	player.san = min(_run_player_san, _run_player_max_san)
	player.atk = _run_player_atk

	var heal_amount := int(node.get("heal", 0))
	if heal_amount > 0:
		player.hp = min(player.max_hp, player.hp + heal_amount)
		_run_player_hp = player.hp

	if heal_amount > 0:
		new_state.add_message("抵达%s。恢复 %d 点生命。行动编码可调整，按 WASD 可试招。" % [new_state.room_name, heal_amount])
	else:
		new_state.add_message("抵达%s。行动编码可调整，按 WASD 可在安全沙盘中试招。" % new_state.room_name)
	return new_state

func _add_room_walls(grid, room: Dictionary) -> void:
	for x in range(ROOM_SIZE):
		grid.add_blocked(Vector2i(x, 0))
		grid.add_blocked(Vector2i(x, ROOM_SIZE - 1))

	for y in range(ROOM_SIZE):
		grid.add_blocked(Vector2i(0, y))
		grid.add_blocked(Vector2i(ROOM_SIZE - 1, y))

	for rect in room["walls"]:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				grid.add_blocked(Vector2i(x, y))

func _add_room_keys(new_state, room: Dictionary) -> void:
	for key_data in room.get("keys", []):
		new_state.drop_key_at(key_data["cell"], String(key_data["key"]))

func _add_actor(new_state, actor_def, cell: Vector2i):
	var actor = ActorStateScript.new()
	actor.setup(_next_actor_id, actor_def, cell)
	_next_actor_id += 1

	if not new_state.grid.place_actor(actor, cell):
		push_error("Cannot place actor %s at %s" % [actor_def.display_name, cell])

	new_state.add_actor(actor)
	return actor

func _enemy_def(id: String):
	var enemy_spawn_service = get_node_or_null("/root/EnemySpawnService")
	if enemy_spawn_service != null:
		var registered_def = enemy_spawn_service.get_enemy_def(id)
		if registered_def != null:
			return registered_def

	match id:
		"brute":
			return BRUTE_DEF
		"boss":
			return BOSS_DEF
		_:
			return SLIME_DEF

func _build_rewards() -> Array:
	if _current_room_index == 0:
		return [
			{"name": "获得行动：突刺", "kind": "add_action", "action": ACTION_LUNGE},
			{"name": "获得遗物：回响刃", "kind": "add_modifier", "modifier": MOD_ECHO_STRIKE},
			{"name": "最大生命 +2", "kind": "max_hp", "value": 2},
		]

	return [
		{"name": "获得行动：横扫", "kind": "add_action", "action": ACTION_SWEEP},
		{"name": "获得遗物：回响步", "kind": "add_modifier", "modifier": MOD_ECHO_STEP},
		{"name": "获得遗物：力场棱镜", "kind": "add_modifier", "modifier": MOD_FORCE_PRISM},
	]

func _apply_reward(reward: Dictionary) -> void:
	match String(reward["kind"]):
		"add_action":
			var action = reward["action"]
			if not _player_has_action(action.id):
				_player_deck.append(action)
				_add_action_token_to_pool(String(action.id))
				_record_achievement_event("action_reward_gained", {
					"action_id": action.id,
					"action_name": action.display_name,
				})
		"add_modifier":
			var modifier = reward.get("modifier")
			if _add_run_modifier(modifier):
				_record_achievement_event("modifier_gained", {
					"modifier_id": String(modifier.id),
					"modifier_name": String(modifier.display_name),
				})
		"max_hp":
			_run_player_max_hp += int(reward["value"])
			_run_player_hp = min(_run_player_max_hp, _run_player_hp + int(reward["value"]))
		"attack":
			_run_player_atk += int(reward["value"])
		"heal":
			_run_player_hp = min(_run_player_max_hp, _run_player_hp + int(reward["value"]))
	_refresh_inventory_ui()

func _player_has_action(action_id: String) -> bool:
	for action in _player_deck:
		if action.id == action_id:
			return true
	return false

func _add_run_modifier(modifier) -> bool:
	if modifier == null:
		return false
	var modifier_id := String(modifier.id)
	if modifier_id.is_empty() or _run_modifier_ids.has(modifier_id):
		return false

	_run_modifier_ids.append(modifier_id)
	if state != null and state.player != null:
		_apply_modifier_to_actor(state.player, modifier)
	return true

func _apply_run_modifiers_to_player() -> void:
	if state == null or state.player == null:
		return
	for modifier_id in _run_modifier_ids:
		var modifier = _modifier_for_id(modifier_id)
		if modifier != null:
			_apply_modifier_to_actor(state.player, modifier)

func _apply_modifier_to_actor(actor, modifier) -> void:
	if actor == null or modifier == null:
		return
	for existing_modifier in actor.effect_modifiers:
		if existing_modifier != null and String(existing_modifier.id) == String(modifier.id):
			return
	actor.effect_modifiers.append(modifier)

func _modifier_for_id(modifier_id: String):
	return _modifier_by_id.get(modifier_id)

func _modifier_inventory_labels() -> Array[String]:
	var labels: Array[String] = []
	for modifier_id in _run_modifier_ids:
		var modifier = _modifier_for_id(modifier_id)
		if modifier != null:
			labels.append(modifier.display_name)
		else:
			labels.append(modifier_id)
	return labels

func _refresh_inventory_ui() -> void:
	if is_instance_valid(battle_ui):
		battle_ui.set_inventory_items(_modifier_inventory_labels())

# 按键编程模型：
# - 每个实体按键槽（U/D/L/R）保存一串行动 token。
# - U/D/L/R token 是最基础的方向移动行动。
# - 突刺、横扫等奖励行动也会作为 token 进入备用池。
# - 玩家按下某个实体按键时，会依次执行该槽里的 token。
# - 只有在休息点可以调整 token 与键槽，战斗中行动编码锁定。
func _ensure_action_helpers() -> void:
	if _action_program == null:
		_action_program = ActionProgramControllerScript.new()
		_action_program.setup(_action_by_id, ACTION_MOVE_KEY)
	if _action_preview == null:
		_action_preview = ActionPreviewServiceScript.new()
		_action_preview.setup(_action_by_id)


func _sync_key_program_mirror() -> void:
	if _action_program == null:
		return
	_key_slots = _action_program.key_slots
	_loose_key_tokens = _action_program.loose_key_tokens


func _setup_default_key_slots() -> void:
	_ensure_action_helpers()
	_action_program.reset_default_slots()
	_sync_key_program_mirror()
	_refresh_key_program_ui()


func _build_key_slot_plan(chain_keys: Array) -> Array:
	if state == null or state.player == null:
		return []
	_ensure_action_helpers()
	return _action_program.build_plan(chain_keys, state.player)


func _make_action_from_token(token_id: String):
	if state == null or state.player == null:
		return null
	_ensure_action_helpers()
	return _action_program.make_action_from_token(token_id, state.player)


func _on_key_slot_preview_requested(slot_id: String) -> void:
	if state == null or state.player == null:
		return
	_ensure_action_helpers()
	if not _action_program.has_slot(slot_id):
		return
	if state.phase != "planning" or state.battle_finished:
		return
	_apply_key_slot_preview(_action_program.get_slot(slot_id))


func _on_key_slot_preview_cleared(_slot_id: String) -> void:
	_clear_key_slot_preview()


func _apply_key_slot_preview(token_ids: Array) -> void:
	if state == null or state.player == null:
		return

	var preview := _build_key_slot_preview(token_ids)
	state.preview_move_cells = preview["move_cells"]
	state.preview_attack_cells = preview["attack_cells"]
	_refresh_views()


func _clear_key_slot_preview(refresh: bool = true) -> void:
	if state == null:
		return
	state.preview_move_cells = []
	state.preview_attack_cells = []
	if refresh:
		_refresh_views()


func _build_key_slot_preview(token_ids: Array) -> Dictionary:
	_ensure_action_helpers()
	return _action_preview.build_preview(token_ids, state)


func _on_key_token_move_requested(source_slot_id: String, source_index: int, target_slot_id: String) -> void:
	if not _key_program_editable:
		if state != null:
			state.add_message("行动编码已锁定：只能在休息处调整。")
			_refresh_views()
		return

	_ensure_action_helpers()
	var result: Dictionary = _action_program.move_token(source_slot_id, source_index, target_slot_id)
	if not bool(result.get("moved", false)):
		return

	var token_id := String(result.get("token_id", ""))
	_sync_key_program_mirror()
	_refresh_key_program_ui()

	if state != null:
		var target_name := "备用行动池" if target_slot_id == KEY_TOKEN_POOL_SLOT_ID else "%s键槽" % state.key_name(target_slot_id)
		state.add_message("将%s移动到%s。" % [_token_display_name(token_id), target_name])
		_refresh_views()


func _get_key_token_container(slot_id: String):
	_ensure_action_helpers()
	if slot_id == KEY_TOKEN_POOL_SLOT_ID:
		return _action_program.loose_key_tokens
	if not _action_program.key_slots.has(slot_id):
		return null
	return _action_program.key_slots[slot_id]


func _on_key_picked(_actor, key_id: String, _cell: Vector2i) -> void:
	_ensure_action_helpers()
	_action_program.add_token_to_pool(key_id, true)
	_sync_key_program_mirror()
	_record_achievement_event("key_picked", {
		"key_id": key_id,
		"room_index": state.room_index if state != null else -1,
		"cell_x": _cell.x,
		"cell_y": _cell.y,
	})
	_refresh_key_program_ui()


func _add_action_token_to_pool(action_id: String) -> void:
	_ensure_action_helpers()
	if _action_program.add_token_to_pool(action_id):
		_sync_key_program_mirror()
		_refresh_key_program_ui()


func _has_token_in_program(token_id: String) -> bool:
	_ensure_action_helpers()
	return _action_program.has_token(token_id)


func _token_display_name(token_id: String) -> String:
	_ensure_action_helpers()
	return _action_program.token_display_name(token_id, state)

func _record_achievement_event(event_id: String, meta: Dictionary = {}) -> void:
	var achievement_service = get_node_or_null("/root/AchievementService")
	if achievement_service != null and achievement_service.has_method("record_event"):
		achievement_service.record_event(event_id, meta)

func _refresh_key_program_ui() -> void:
	if is_instance_valid(battle_ui):
		battle_ui.set_available_actions(_player_deck)
		battle_ui.set_key_program(_key_slots, _loose_key_tokens)

func _register_save_provider() -> void:
	var save_service = get_node_or_null("/root/SaveService")
	if save_service != null:
		save_service.register_provider("run", self)

func get_save_data() -> Dictionary:
	_ensure_action_helpers()
	var key_program_save: Dictionary = _action_program.get_save_data()
	return {
		"current_map_node_index": _current_map_node_index,
		"current_room_index": _current_room_index,
		"run_player_max_hp": _run_player_max_hp,
		"run_player_hp": _run_player_hp,
		"run_player_max_san": _run_player_max_san,
		"run_player_san": _run_player_san,
		"run_player_atk": _run_player_atk,
		"run_seed": _run_seed,
		"player_deck": _player_deck.map(func(action): return action.id),
		"run_modifier_ids": _run_modifier_ids,
		"key_slots": key_program_save["key_slots"],
		"loose_key_tokens": key_program_save["loose_key_tokens"],
	}

func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	_current_room_index = clampi(int(data.get("current_room_index", 0)), 0, ROOMS.size() - 1)
	_current_map_node_index = clampi(int(data.get("current_map_node_index", _current_room_index)), 0, MAP_NODES.size() - 1)
	_run_player_max_hp = int(data.get("run_player_max_hp", PLAYER_DEF.max_hp))
	_run_player_hp = int(data.get("run_player_hp", _run_player_max_hp))
	_run_player_max_san = int(data.get("run_player_max_san", PLAYER_DEF.max_san))
	_run_player_san = int(data.get("run_player_san", _run_player_max_san))
	_run_player_atk = int(data.get("run_player_atk", PLAYER_DEF.atk))
	_run_seed = data.get("run_seed", "")
	_player_deck.clear()
	for action_id in data.get("player_deck", []):
		var action = _action_by_id.get(String(action_id))
		if action != null:
			_player_deck.append(action)
	if _player_deck.is_empty():
		_player_deck = [ACTION_MOVE_FORWARD, ACTION_TURN_LEFT, ACTION_TURN_RIGHT, ACTION_ATTACK, ACTION_WAIT]

	_run_modifier_ids.clear()
	for modifier_id in data.get("run_modifier_ids", []):
		var safe_modifier_id := String(modifier_id)
		if _modifier_for_id(safe_modifier_id) != null and not _run_modifier_ids.has(safe_modifier_id):
			_run_modifier_ids.append(safe_modifier_id)

	_load_key_program(data)
	_refresh_inventory_ui()
	_start_map_node(_current_map_node_index)

func _load_key_program(data: Dictionary) -> void:
	_ensure_action_helpers()
	_action_program.load_save_data(data)
	_sync_key_program_mirror()
