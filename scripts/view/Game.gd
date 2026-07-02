extends Node

signal pause_menu_requested

@export var show_title_on_ready := true

const GameStateScript := preload("res://scripts/core/GameState.gd")
const GridModelScript := preload("res://scripts/core/GridModel.gd")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")
const ActionProgramControllerScript := preload("res://scripts/core/ActionProgramController.gd")
const ActionPreviewServiceScript := preload("res://scripts/core/ActionPreviewService.gd")
const DirectionalTechniqueResolverScript := preload("res://scripts/core/DirectionalTechniqueResolver.gd")
const BattlePresentationControllerScript := preload("res://scripts/core/BattlePresentationController.gd")
const WorldSliceControllerScript := preload("res://scripts/core/WorldSliceController.gd")

const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const BOSS_DEF := preload("res://data/actors/boss.tres")

const ACTION_MOVE_FORWARD := preload("res://data/actions/move_forward.tres")
const ACTION_MOVE_BACK := preload("res://data/actions/move_back.tres")
const ACTION_TURN_LEFT := preload("res://data/actions/turn_left.tres")
const ACTION_TURN_RIGHT := preload("res://data/actions/turn_right.tres")
const ACTION_JUMP := preload("res://data/actions/jump.tres")
const ACTION_ATTACK := preload("res://data/actions/attack.tres")
const ACTION_WAIT := preload("res://data/actions/wait.tres")
const ACTION_GUARD := preload("res://data/actions/guard.tres")
const ACTION_CHARGE_THRUST := preload("res://data/actions/charge_thrust.tres")
const ACTION_GREAT_SWEEP := preload("res://data/actions/great_sweep.tres")
const ACTION_MOVE_KEY := preload("res://data/actions/move_key.tres")
const IMPACT_SHIELD := preload("res://data/weapons/impact_shield.tres")
const IRON_SPEAR := preload("res://data/weapons/iron_spear.tres")
const GREATBLADE := preload("res://data/weapons/greatblade.tres")

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
@onready var world_loading_overlay = $CanvasLayer/WorldLoadingOverlay
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
var _action_by_id: Dictionary = {}
var _modifier_by_id: Dictionary = {}
var _weapon_by_id: Dictionary = {}
var _run_modifier_ids: Array[String] = []
var _run_weapon_id := "impact_shield"
var _action_program
var _action_preview
var _directional_techniques
var _battle_presentation
var _world_slice_controller
var _current_rewards: Array = []
var _key_program_editable := false
var _world_slice_last_rest_area_state: bool = false
var _bag_open := false
var _shell_overlay_active := false

func _ready() -> void:
	_action_by_id = {
		"move_forward": ACTION_MOVE_FORWARD,
		"move_back": ACTION_MOVE_BACK,
		"turn_left": ACTION_TURN_LEFT,
		"turn_right": ACTION_TURN_RIGHT,
		"jump": ACTION_JUMP,
		"attack": ACTION_ATTACK,
		"wait": ACTION_WAIT,
		"guard": ACTION_GUARD,
		"charge_thrust": ACTION_CHARGE_THRUST,
		"great_sweep": ACTION_GREAT_SWEEP,
		"move_key": ACTION_MOVE_KEY,
	}
	_modifier_by_id = {
		"echo_strike": MOD_ECHO_STRIKE,
		"echo_step": MOD_ECHO_STEP,
		"force_prism": MOD_FORCE_PRISM,
	}
	_weapon_by_id = {
		"impact_shield": IMPACT_SHIELD,
		"iron_spear": IRON_SPEAR,
		"greatblade": GREATBLADE,
	}
	_action_program = ActionProgramControllerScript.new()
	_action_program.setup()
	_action_preview = ActionPreviewServiceScript.new()
	_action_preview.setup()
	_directional_techniques = DirectionalTechniqueResolverScript.new()
	_directional_techniques.setup(_action_by_id, ACTION_MOVE_KEY)
	_battle_presentation = BattlePresentationControllerScript.new()
	_battle_presentation.setup(board_view, $ActorRoot, $EffectRoot)
	_world_slice_controller = WorldSliceControllerScript.new()
	_refresh_key_program_ui()

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
	if _shell_overlay_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and state != null and not state.battle_finished:
			_toggle_bag()
			get_viewport().set_input_as_handled()
			return

	if _bag_open:
		if event.is_action_pressed("ui_cancel"):
			_close_bag_if_open()
			get_viewport().set_input_as_handled()
		return

	if state != null and bool(state.is_world_slice):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_V:
				if _world_slice_controller != null:
					_world_slice_controller.set_reveal_all_debug(state, not bool(state.reveal_all_debug), "debug_toggle")
					_refresh_views()
					get_viewport().set_input_as_handled()
					return
			if event.keycode == KEY_F5:
				if _world_slice_controller != null:
					_world_slice_controller.regenerate_same_seed(state)
					turn_controller.start_battle(state)
					_refresh_views()
					get_viewport().set_input_as_handled()
					return
			if event.keycode == KEY_F6:
				if _world_slice_controller != null:
					_world_slice_controller.regenerate_new_seed(state)
					turn_controller.start_battle(state)
					_refresh_views()
					get_viewport().set_input_as_handled()
					return
			if event.keycode == KEY_M:
				if _world_slice_controller != null:
					_world_slice_controller.print_map_summary(state)
					_refresh_views()
					get_viewport().set_input_as_handled()
					return

	if state == null or state.phase != "planning" or state.battle_finished:
		return

	var input_service = get_node_or_null("/root/PlayerInputService")
	if input_service == null:
		return

	var action_name: String = input_service.get_pressed_program_action(event)
	if action_name.is_empty():
		return

	get_viewport().set_input_as_handled()
	var key_id: String = input_service.get_key_id_for_action(action_name)
	_submit_key_chain(key_id)

func set_game_visible(is_visible: bool) -> void:
	board_view.visible = is_visible
	$ActorRoot.visible = is_visible
	$EffectRoot.visible = is_visible
	battle_ui.visible = is_visible
	if world_loading_overlay != null and not is_visible:
		world_loading_overlay.hide_loading()


func set_shell_overlay_active(is_active: bool) -> void:
	_shell_overlay_active = is_active
	if is_active:
		_close_bag_if_open()

func _connect_signals() -> void:
	battle_ui.start_requested.connect(start_run)
	battle_ui.reward_chosen.connect(_on_reward_chosen)
	battle_ui.restart_requested.connect(start_run)
	battle_ui.key_token_move_requested.connect(_on_key_token_move_requested)
	battle_ui.key_slot_preview_requested.connect(_on_key_slot_preview_requested)
	battle_ui.key_slot_preview_cleared.connect(_on_key_slot_preview_cleared)
	battle_ui.rest_continue_requested.connect(_on_rest_continue_requested)
	battle_ui.bag_toggle_requested.connect(_toggle_bag)
	battle_ui.pause_menu_requested.connect(_on_pause_menu_requested)
	turn_controller.action_finished.connect(func(_action) -> void: _refresh_views())
	turn_controller.turn_finished.connect(_refresh_views)
	turn_controller.planning_started.connect(_refresh_views)
	turn_controller.battle_finished.connect(_on_battle_finished)
	resolver.rule_message.connect(func(_message: String) -> void: _refresh_views())
	resolver.key_picked.connect(_on_key_picked)
	resolver.actor_moved.connect(_on_actor_moved)

func start_run() -> void:
	_close_bag_if_open()
	start_world_slice_debug()


func start_run_legacy() -> void:
	_start_new_run(Time.get_datetime_string_from_system())


func start_room_chain_legacy() -> void:
	start_run_legacy()

func start_seeded_run(seed_value) -> void:
	_start_new_run(seed_value)


func start_world_slice_debug() -> void:
	_ensure_action_helpers()
	if world_loading_overlay != null:
		world_loading_overlay.show_loading("生成地图中", "准备世界参数…", 0.0)
		await get_tree().process_frame
	state = await _world_slice_controller.create_demo_state_with_progress("", Callable(self, "_on_world_generation_progress")) if _world_slice_controller != null else null
	if state == null:
		if world_loading_overlay != null:
			world_loading_overlay.hide_loading()
		return
	_current_rewards = []
	_current_room_index = int(state.room_index)
	_current_map_node_index = int(state.map_node_index)
	_run_modifier_ids.clear()
	_action_program.reset_starter_slots("absolute")
	_refresh_key_program_ui()
	_refresh_inventory_ui()
	if _battle_presentation != null and state != null:
		_battle_presentation.reset_for_state(state)
		_battle_presentation.use_world_slice_fast_timing_profile()
		_battle_presentation.set_wait_for_presentation_completion(false)
	enemy_planner.enemies_are_static = false
	turn_controller.start_battle(state)
	if board_view != null:
		board_view.world_slice_window_size = Vector2i(29, 29)
		board_view.board_origin = Vector2(24, 84)
		board_view.position = board_view.board_origin
	battle_ui.show_battle()
	_update_world_slice_editability(true)
	_refresh_world_visibility("init")
	_refresh_views()
	if world_loading_overlay != null:
		world_loading_overlay.hide_loading()


func _on_world_generation_progress(progress_data: Dictionary) -> void:
	if world_loading_overlay == null:
		return
	var stage_label := String(progress_data.get("stage_label", "Generating world"))
	var progress_ratio := float(progress_data.get("progress", 0.0))
	world_loading_overlay.show_loading("Generating world", stage_label, progress_ratio)


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
	_run_modifier_ids.clear()
	_run_weapon_id = _default_run_weapon_id()
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
		_battle_presentation.use_legacy_timing_profile()
		_battle_presentation.set_wait_for_presentation_completion(true)
	enemy_planner.enemies_are_static = false
	turn_controller.start_battle(state)
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
		_battle_presentation.use_legacy_timing_profile()
		_battle_presentation.set_wait_for_presentation_completion(true)
	enemy_planner.enemies_are_static = true
	turn_controller.start_battle(state)
	battle_ui.set_key_program_editable(true)
	_refresh_key_program_ui()
	_refresh_inventory_ui()
	battle_ui.show_rest_site(String(node.get("label", "休息处")), "这里可以拖拽调整行动 token 与按键槽。整理好后继续前进。")
	_refresh_views()

func _submit_key_chain(key_id: String) -> void:
	_clear_key_slot_preview(false)
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null and not _is_safe_training_state() and not _is_world_slice_state():
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
	_close_bag_if_open()
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

	_close_bag_if_open()
	_apply_reward(_current_rewards[index])
	_current_rewards = []
	_advance_to_next_map_node()

func _on_rest_continue_requested() -> void:
	if not _is_current_rest_node():
		return
	_close_bag_if_open()
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


func _is_world_slice_state() -> bool:
	return state != null and bool(state.is_world_slice)

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

	if bool(state.is_world_slice):
		_update_world_slice_editability()
	_update_enemy_preview()
	board_view.render(state)
	if _battle_presentation != null:
		var snap_actor_views: bool = not _battle_presentation.should_wait_for_presentation()
		if bool(state.is_world_slice):
			# The world-slice board renders a moving window around the player, so
			# visible actor overlays need to resnap when the window origin shifts.
			# BattlePresentationController keeps this scoped to the player plus
			# currently visible actors instead of maintaining views for the whole map.
			snap_actor_views = true
		_battle_presentation.sync_views(state, snap_actor_views)
	battle_ui.update_state(state)


func _on_actor_moved(actor, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if state == null or _world_slice_controller == null:
		return
	if not bool(state.is_world_slice):
		return
	_world_slice_controller.on_actor_moved(state, actor, from_cell, to_cell)
	_refresh_views()


func _refresh_world_visibility(reason: String) -> void:
	if state == null or _world_slice_controller == null:
		return
	if not bool(state.is_world_slice):
		return
	_world_slice_controller.recompute_visibility(state, reason)


func _update_world_slice_editability(force_refresh: bool = false) -> void:
	if state == null or not bool(state.is_world_slice):
		return
	var editable_now: bool = _is_player_in_world_slice_rest_area()
	if not force_refresh and editable_now == _key_program_editable:
		return
	_key_program_editable = editable_now
	if is_instance_valid(battle_ui):
		battle_ui.set_key_program_editable(editable_now)
	if force_refresh or editable_now != _world_slice_last_rest_area_state:
		if editable_now:
			state.add_message("进入酒馆休息区：这里可以调整行动编排。")
		else:
			state.add_message("离开酒馆休息区：行动编排已锁定。")
	_world_slice_last_rest_area_state = editable_now


func _is_player_in_world_slice_rest_area() -> bool:
	if state == null or state.player == null or state.map_data == null:
		return false
	var map_cell = state.map_data.get_cell(state.player.grid_pos)
	if map_cell == null:
		return false
	if map_cell.tags.has("building_floor") or map_cell.tags.has("building_door") or map_cell.tags.has("building_open_ground"):
		for tag in map_cell.tags:
			if String(tag) == "poi:tavern":
				return true
			if String(tag).begins_with("structure:tavern"):
				return true
			if String(tag).begins_with("building:tavern_"):
				return true
	return false

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
	player.active_weapon = _current_run_weapon()

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
	player.active_weapon = _current_run_weapon()

	var heal_amount := int(node.get("heal", 0))
	if heal_amount > 0:
		player.hp = min(player.max_hp, player.hp + heal_amount)
		_run_player_hp = player.hp

	if heal_amount > 0:
		new_state.add_message("抵达%s。恢复 %d 点生命。行动编码可调整。" % [new_state.room_name, heal_amount])
	else:
		new_state.add_message("抵达%s。行动编码可调整。" % new_state.room_name)
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
			{"name": "获得遗物：回响刃", "kind": "add_modifier", "modifier": MOD_ECHO_STRIKE},
			{"name": "获得遗物：回响步", "kind": "add_modifier", "modifier": MOD_ECHO_STEP},
			{"name": "最大生命 +2", "kind": "max_hp", "value": 2},
		]

	return [
		{"name": "更换武器：铁枪", "kind": "equip_weapon", "weapon_id": "iron_spear"},
		{"name": "更换武器：巨剑", "kind": "equip_weapon", "weapon_id": "greatblade"},
		{"name": "攻击 +1", "kind": "attack", "value": 1},
	]

func _apply_reward(reward: Dictionary) -> void:
	match String(reward["kind"]):
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
		"equip_weapon":
			_equip_run_weapon_by_id(String(reward.get("weapon_id", "")))
	_refresh_inventory_ui()

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
	state.player.active_weapon = _current_run_weapon()
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


func _build_permanent_buffs() -> Array[Dictionary]:
	var buffs: Array[Dictionary] = []
	for modifier_id in _run_modifier_ids:
		var modifier = _modifier_for_id(modifier_id)
		if modifier != null:
			buffs.append({
				"name": String(modifier.display_name),
				"description": String(modifier.description),
			})
		else:
			buffs.append({
				"name": modifier_id,
				"description": "",
			})
	return buffs

func _modifier_inventory_labels() -> Array[String]:
	var labels: Array[String] = []
	for modifier_id in _run_modifier_ids:
		var modifier = _modifier_for_id(modifier_id)
		if modifier != null:
			labels.append(modifier.display_name)
		else:
			labels.append(modifier_id)
	return labels

func _weapon_inventory_labels() -> Array[String]:
	var labels: Array[String] = []
	if state == null or state.player == null or state.player.active_weapon == null:
		return labels

	var weapon = state.player.active_weapon
	labels.append("当前武器：%s" % String(weapon.display_name))
	var attack_action = weapon.get("attack_action")
	if attack_action != null:
		labels.append("攻击动作：%s" % String(attack_action.display_name))
	return labels

func _inventory_labels() -> Array[String]:
	var labels: Array[String] = []
	labels.append_array(_weapon_inventory_labels())
	labels.append_array(_modifier_inventory_labels())
	return labels

func _refresh_inventory_ui() -> void:
	if is_instance_valid(battle_ui):
		battle_ui.set_inventory_items(_inventory_labels())

# 按键编程模型：
# - 十二个物理键槽保存的是“基础行动 token”，不是只存方向。
# - 基础行动既包括绝对方向移动（U/D/L/R），也包括前进、后退、转向、
#   攻击、防御、等待、跳跃这类显式动作。
# - 玩家按下某个实体按键时，会先取出该槽中的 token 链，再解析为实际行动。
# - 武器不再通过独立武器技系统派生招式；每把武器直接声明一个攻击动作。
# - 因此按键编程层管理“基础输入与基础动作”；攻击 token 会在计划构建时
#   解析成当前武器声明的具体攻击动作。
# - 只有在休息点可以调整 token 与键槽，战斗中行动编码锁定。
# Key-program layer notes:
# - slots store editable base-action tokens
# - slot execution expands those tokens into runtime base actions
# - equipped weapon chooses the concrete attack action used by the generic
#   attack token
func _ensure_action_helpers() -> void:
	if _action_program == null:
		_action_program = ActionProgramControllerScript.new()
		_action_program.setup()
	if _action_preview == null:
		_action_preview = ActionPreviewServiceScript.new()
		_action_preview.setup()
	if _directional_techniques == null:
		_directional_techniques = DirectionalTechniqueResolverScript.new()
	_directional_techniques.setup(_action_by_id, ACTION_MOVE_KEY)


func _setup_default_key_slots() -> void:
	_ensure_action_helpers()
	var random_service = get_node_or_null("/root/RandomService")
	var preset_id := "absolute"
	if random_service != null and random_service.has_method("randi_range_value"):
		preset_id = "relative" if int(random_service.randi_range_value(0, 1)) == 1 else "absolute"
	_action_program.reset_starter_slots(preset_id)
	_refresh_key_program_ui()


func _build_key_slot_plan(chain_keys: Array) -> Array:
	if state == null or state.player == null:
		return []
	_ensure_action_helpers()
	return _directional_techniques.build_plan(chain_keys, state.player)


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
	var preview_actions: Array = _directional_techniques.build_plan(token_ids, state.player)
	return _action_preview.build_preview_from_actions(preview_actions, state)


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
	_refresh_key_program_ui()

	if state != null:
		var target_name := "备用行动池" if target_slot_id == KEY_TOKEN_POOL_SLOT_ID else "%s键槽" % state.key_name(target_slot_id)
		state.add_message("将%s移动到%s。" % [_token_display_name(token_id), target_name])
		_refresh_views()


func _on_key_picked(_actor, key_id: String, _cell: Vector2i) -> void:
	_ensure_action_helpers()
	_action_program.add_token_to_pool(key_id, true)
	_record_achievement_event("key_picked", {
		"key_id": key_id,
		"room_index": state.room_index if state != null else -1,
		"cell_x": _cell.x,
		"cell_y": _cell.y,
	})
	_refresh_key_program_ui()


func _token_display_name(token_id: String) -> String:
	_ensure_action_helpers()
	return _action_program.token_display_name(token_id, state)

func get_player_action_trace_symbols(count: int = -1) -> Array[StringName]:
	if state == null or state.player == null or state.action_trace == null:
		return []
	return state.action_trace.get_recent_symbols_for_actor(int(state.player.id), count)


func get_player_action_trace_debug_string(count: int = -1) -> String:
	if state == null or state.player == null or state.action_trace == null:
		return ""
	return state.action_trace.debug_string_for_actor(int(state.player.id), count)


func get_player_action_trace_move_dirs_debug_string(count: int = -1) -> String:
	if state == null or state.player == null or state.action_trace == null:
		return ""
	var parts: Array[String] = []
	for entry in state.action_trace.get_recent_entries_for_actor(int(state.player.id), count):
		if entry == null:
			continue
		parts.append(_trace_move_dir_label(Vector2i(entry.move_dir)))
	return " -> ".join(parts)


func get_player_combo_debug_string(count: int = -1, _trigger_timing: int = -1) -> String:
	var trace_line := get_player_action_trace_debug_string(count)
	var move_line := get_player_action_trace_move_dirs_debug_string(count)
	return "Trace: %s\nMoveDirs: %s" % [trace_line, move_line]


func _record_achievement_event(event_id: String, meta: Dictionary = {}) -> void:
	var achievement_service = get_node_or_null("/root/AchievementService")
	if achievement_service != null and achievement_service.has_method("record_event"):
		achievement_service.record_event(event_id, meta)

func _refresh_key_program_ui() -> void:
	if not is_instance_valid(battle_ui):
		return
	battle_ui.set_permanent_buffs(_build_permanent_buffs())
	battle_ui.set_key_program(_action_program.get_key_slots(), _action_program.get_pool_tokens())


func _toggle_bag() -> void:
	if _shell_overlay_active:
		return
	if state == null or state.battle_finished:
		return
	if is_instance_valid(battle_ui):
		battle_ui.toggle_bag()
		_bag_open = battle_ui.is_bag_open()
		if _bag_open:
			battle_ui.set_key_program_editable(_key_program_editable)
			_refresh_key_program_ui()
		get_tree().paused = _bag_open


func _close_bag_if_open() -> void:
	if _bag_open and is_instance_valid(battle_ui):
		battle_ui.toggle_bag()
		_bag_open = false
		get_tree().paused = false


func _on_pause_menu_requested() -> void:
	_close_bag_if_open()
	pause_menu_requested.emit()


func _refresh_permanent_buffs_ui() -> void:
	if not is_instance_valid(battle_ui):
		return
	var buffs: Array[Dictionary] = _build_permanent_buffs()
	battle_ui.set_permanent_buffs(buffs)


func get_key_program_slots() -> Dictionary:
	_ensure_action_helpers()
	return _action_program.get_key_slots()


func get_key_program_pool_tokens() -> Array[String]:
	_ensure_action_helpers()
	return _action_program.get_pool_tokens()


func get_token_drop_pool() -> Array[String]:
	_ensure_action_helpers()
	return _action_program.get_token_drop_pool()


func _trace_move_dir_label(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "U"
	if direction == Vector2i.DOWN:
		return "D"
	if direction == Vector2i.LEFT:
		return "L"
	if direction == Vector2i.RIGHT:
		return "R"
	return "·"

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
		"run_modifier_ids": _run_modifier_ids,
		"run_weapon_id": _run_weapon_id,
		"key_slots": key_program_save["key_slots"],
		"pool_tokens": key_program_save["pool_tokens"],
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
	_run_weapon_id = String(data.get("run_weapon_id", _default_run_weapon_id()))
	if _weapon_for_id(_run_weapon_id) == null:
		_run_weapon_id = _default_run_weapon_id()

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
	_refresh_key_program_ui()


func _default_run_weapon_id() -> String:
	if PLAYER_DEF.default_weapon != null and not String(PLAYER_DEF.default_weapon.id).is_empty():
		return String(PLAYER_DEF.default_weapon.id)
	return "impact_shield"


func _weapon_for_id(weapon_id: String):
	return _weapon_by_id.get(weapon_id)


func _current_run_weapon():
	var weapon = _weapon_for_id(_run_weapon_id)
	if weapon != null:
		return weapon
	return PLAYER_DEF.default_weapon


func _equip_run_weapon_by_id(weapon_id: String) -> bool:
	var weapon = _weapon_for_id(weapon_id)
	if weapon == null:
		return false
	_run_weapon_id = weapon_id
	if state != null and state.player != null:
		state.player.active_weapon = weapon
	return true
