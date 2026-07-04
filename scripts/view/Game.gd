extends Node

signal pause_menu_requested

@export var show_title_on_ready := true

const GameStateScript := preload("res://scripts/core/GameState.gd")
const GridModelScript := preload("res://scripts/core/GridModel.gd")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")
const ActionProgramControllerScript := preload("res://scripts/core/ActionProgramController.gd")
const ActionPreviewServiceScript := preload("res://scripts/core/ActionPreviewService.gd")
const DirectionalTechniqueResolverScript := preload("res://scripts/core/DirectionalTechniqueResolver.gd")
const BattlePresentationControllerScript := preload("res://scripts/core/BattlePresentationController.gd")
const WorldSliceControllerScript := preload("res://scripts/core/WorldSliceController.gd")
const ActorInteractionServiceScript := preload("res://scripts/core/ActorInteractionService.gd")

const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const WISP_DEF := preload("res://data/actors/wisp.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const BOSS_DEF := preload("res://data/actors/boss.tres")
const LINE_WARDEN_DEF := preload("res://data/actors/line_warden.tres")

const ACTION_MOVE_FORWARD := preload("res://data/actions/move_forward.tres")
const ACTION_MOVE_BACK := preload("res://data/actions/move_back.tres")
const ACTION_STEP_LEFT := preload("res://data/actions/step_left.tres")
const ACTION_STEP_RIGHT := preload("res://data/actions/step_right.tres")
const ACTION_DASH := preload("res://data/actions/dash.tres")
const ACTION_HOOK_PULL := preload("res://data/actions/hook_pull.tres")
const ACTION_SHIELD_BASH := preload("res://data/actions/shield_bash.tres")
const ACTION_HAMMER_SMASH := preload("res://data/actions/hammer_smash.tres")
const ACTION_SPIN_AXE := preload("res://data/actions/spin_axe.tres")
const ACTION_PIERCE_LINE := preload("res://data/actions/pierce_line.tres")
const ACTION_TURN_LEFT := preload("res://data/actions/turn_left.tres")
const ACTION_TURN_RIGHT := preload("res://data/actions/turn_right.tres")
const ACTION_JUMP := preload("res://data/actions/jump.tres")
const ACTION_ATTACK := preload("res://data/actions/attack.tres")
const ACTION_BOW_SHOT := preload("res://data/actions/bow_shot.tres")
const ACTION_WAIT := preload("res://data/actions/wait.tres")
const ACTION_GUARD := preload("res://data/actions/guard.tres")
const ACTION_INTERACT := preload("res://data/actions/interact.tres")
const ACTION_CHARGE_THRUST := preload("res://data/actions/charge_thrust.tres")
const ACTION_GREAT_SWEEP := preload("res://data/actions/great_sweep.tres")
const ACTION_MOVE_KEY := preload("res://data/actions/move_key.tres")

const MOD_ECHO_STRIKE := preload("res://data/modifiers/echo_strike.tres")
const MOD_ECHO_STEP := preload("res://data/modifiers/echo_step.tres")
const MOD_FORCE_PRISM := preload("res://data/modifiers/force_prism.tres")
const MOD_LONG_DRAW := preload("res://data/modifiers/long_draw.tres")
const MOD_BLOOD_DRAIN := preload("res://data/modifiers/blood_drain.tres")
const MOD_STORMSTEP := preload("res://data/modifiers/stormstep.tres")
const MOD_KEEN_EDGE := preload("res://data/modifiers/keen_edge.tres")
const MOD_PHALANX_RUSH := preload("res://data/modifiers/phalanx_rush.tres")
const MOD_LANCER_FOCUS := preload("res://data/modifiers/lancer_focus.tres")
const MOD_CYCLONE_FURY := preload("res://data/modifiers/cyclone_fury.tres")
const MOD_BATTLE_TRANCE := preload("res://data/modifiers/battle_trance.tres")

const ROOM_SIZE := 8
const MAP_NODE_COMBAT := "combat"
const MAP_NODE_REST := "rest"
const MAP_NODE_BOSS := "boss"
const KEY_TOKEN_POOL_SLOT_ID := "POOL"
const AUTO_PLAY_DELAY := 2.0
const AUTO_FAST_DELAY := 1.0

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
			{"def": "wisp", "cell": Vector2i(3, 1)},
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
@onready var camera = $Camera2D
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
var _run_regen_progress := 0.0
var _run_seed = ""
var _action_by_id: Dictionary = {}
var _modifier_by_id: Dictionary = {}
var _run_modifier_ids: Array[String] = []
var _action_program
var _action_preview
var _directional_techniques
var _battle_presentation
var _world_slice_controller
var _actor_interaction_service
var _current_rewards: Array = []
var _key_program_editable := false
var _world_slice_last_rest_area_state: bool = false
var _world_npc_interaction_counts: Dictionary = {}
var _world_npc_dialogue_active := false
var _world_npc_dialogue_npc_id := ""
var _world_ruin_claims: Dictionary = {}
var _world_autopath_target: Vector2i = Vector2i(-1, -1)
var _world_autopath_active := false
var _world_autopath_steps: Array[Vector2i] = []
var _world_autopath_last_step_msec := 0
var _world_autopath_step_scheduled := false
var _pending_level_reward := false
var _player_input_locked := false
var _bag_open := false
var _shell_overlay_active := false
var _auto_submitting_plan := false

func _ready() -> void:
	_action_by_id = {
		"move_forward": ACTION_MOVE_FORWARD,
		"move_back": ACTION_MOVE_BACK,
		"step_left": ACTION_STEP_LEFT,
		"step_right": ACTION_STEP_RIGHT,
		"dash": ACTION_DASH,
		"hook_pull": ACTION_HOOK_PULL,
		"shield_bash": ACTION_SHIELD_BASH,
		"hammer_smash": ACTION_HAMMER_SMASH,
		"spin_axe": ACTION_SPIN_AXE,
		"pierce_line": ACTION_PIERCE_LINE,
		"turn_left": ACTION_TURN_LEFT,
		"turn_right": ACTION_TURN_RIGHT,
		"jump": ACTION_JUMP,
		"attack": ACTION_ATTACK,
		"bow_shot": ACTION_BOW_SHOT,
		"wait": ACTION_WAIT,
		"guard": ACTION_GUARD,
		"interact": ACTION_INTERACT,
		"charge_thrust": ACTION_CHARGE_THRUST,
		"great_sweep": ACTION_GREAT_SWEEP,
		"cross_attack": preload("res://data/actions/cross_attack.tres"),
		"move_key": ACTION_MOVE_KEY,
	}
	_modifier_by_id = {
		"echo_strike": MOD_ECHO_STRIKE,
		"echo_step": MOD_ECHO_STEP,
		"force_prism": MOD_FORCE_PRISM,
		"long_draw": MOD_LONG_DRAW,
		"blood_drain": MOD_BLOOD_DRAIN,
		"stormstep": MOD_STORMSTEP,
		"keen_edge": MOD_KEEN_EDGE,
		"phalanx_rush": MOD_PHALANX_RUSH,
		"lancer_focus": MOD_LANCER_FOCUS,
		"cyclone_fury": MOD_CYCLONE_FURY,
		"battle_trance": MOD_BATTLE_TRANCE,
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
	_actor_interaction_service = ActorInteractionServiceScript.new()
	_refresh_key_program_ui()

	turn_controller.resolver = resolver
	turn_controller.enemy_planner = enemy_planner
	turn_controller.presentation_controller = _battle_presentation
	enemy_planner.enemies_are_static = false
	enemy_planner.move_action = ACTION_MOVE_FORWARD
	enemy_planner.attack_action = ACTION_ATTACK
	var enemy_spawn_service = get_node_or_null("/root/EnemySpawnService")
	if enemy_spawn_service != null:
		enemy_spawn_service.register_enemy_defs([SLIME_DEF, WISP_DEF, BRUTE_DEF, BOSS_DEF, LINE_WARDEN_DEF])

	_connect_signals()
	_register_save_provider()
	if show_title_on_ready:
		battle_ui.show_title()

func _unhandled_input(event: InputEvent) -> void:
	if _shell_overlay_active:
		return

	if _world_npc_dialogue_active:
		if event is InputEventKey and event.pressed and not event.echo:
			_close_world_npc_dialogue()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_close_world_npc_dialogue()
			get_viewport().set_input_as_handled()
			return
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
		if event.is_action_pressed("ui_accept"):
			if _submit_world_interact_action():
				get_viewport().set_input_as_handled()
				return
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
					_world_npc_interaction_counts.clear()
					turn_controller.start_battle(state)
					_refresh_views()
					get_viewport().set_input_as_handled()
					return
			if event.keycode == KEY_F6:
				if _world_slice_controller != null:
					_world_slice_controller.regenerate_new_seed(state)
					_world_npc_interaction_counts.clear()
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
			if event.keycode == KEY_HOME:
				if board_view != null:
					board_view.reset_camera()
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


func _is_world_interaction_event(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return int(event.keycode) == KEY_F
	return false


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
	battle_ui.auto_advance_mode_changed.connect(_on_auto_advance_mode_changed)
	battle_ui.get_node("RunSidebar").boss_poi_requested.connect(_on_boss_poi_requested)
	battle_ui.get_node("RunSidebar").safe_zone_poi_requested.connect(_on_safe_zone_poi_requested)
	battle_ui.get_node("RunSidebar").ruin_poi_requested.connect(_on_ruin_poi_requested)
	turn_controller.action_finished.connect(func(_action) -> void: _refresh_views())
	turn_controller.turn_finished.connect(_on_turn_finished)
	turn_controller.planning_started.connect(_on_planning_started)
	turn_controller.battle_finished.connect(_on_battle_finished)
	resolver.rule_message.connect(func(_message: String) -> void: _refresh_views())
	resolver.key_picked.connect(_on_key_picked)
	resolver.actor_moved.connect(_on_actor_moved)
	resolver.actor_damaged.connect(_on_actor_damaged)
	resolver.actor_died.connect(_on_actor_died)
	resolver.world_npc_interaction_requested.connect(_on_world_npc_interaction_requested)

func start_run() -> void:
	_close_bag_if_open()
	_close_world_npc_dialogue(false)
	set_game_visible(false)
	if world_loading_overlay != null:
		world_loading_overlay.show_loading("生成地图中", "准备世界参数…", 0.0)
		await get_tree().process_frame
	start_world_slice_debug()


func start_run_legacy() -> void:
	_start_new_run(Time.get_datetime_string_from_system())


func start_room_chain_legacy() -> void:
	start_run_legacy()

func start_seeded_run(seed_value) -> void:
	_start_new_run(seed_value)


func start_world_slice_debug() -> void:
	_ensure_action_helpers()
	_world_npc_interaction_counts.clear()
	_world_ruin_claims.clear()
	if state != null:
		state.player_xp = 0
		state.player_level = 1
	_run_regen_progress = 0.0
	_pending_level_reward = false
	_player_input_locked = false
	_world_autopath_active = false
	_world_autopath_target = Vector2i(-1, -1)
	_world_autopath_steps.clear()
	_world_autopath_last_step_msec = 0
	_world_autopath_step_scheduled = false
	_close_world_npc_dialogue(false)
	state = await _world_slice_controller.create_demo_state_with_progress("", Callable(self, "_on_world_generation_progress")) if _world_slice_controller != null else null
	if state == null:
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
		board_view.reset_camera()
	battle_ui.show_battle()
	_update_world_slice_editability(true)
	_refresh_world_visibility("init")
	_refresh_views()
	set_game_visible(true)
	if world_loading_overlay != null:
		world_loading_overlay.hide_loading()


func _on_world_generation_progress(progress_data: Dictionary) -> void:
	if world_loading_overlay == null:
		return
	var stage_label := String(progress_data.get("stage_label", "Generating world"))
	var progress_ratio := float(progress_data.get("progress", 0.0))
	world_loading_overlay.show_loading("Generating world", stage_label, progress_ratio)


func _start_new_run(seed_value) -> void:
	_close_world_npc_dialogue(false)
	_world_autopath_active = false
	_world_autopath_target = Vector2i(-1, -1)
	_world_autopath_steps.clear()
	_world_autopath_last_step_msec = 0
	_world_autopath_step_scheduled = false
	_pending_level_reward = false
	_player_input_locked = false
	_current_room_index = 0
	_current_map_node_index = 0
	_run_player_max_hp = PLAYER_DEF.max_hp
	_run_player_hp = _run_player_max_hp
	_run_player_max_san = PLAYER_DEF.max_san
	_run_player_san = _run_player_max_san
	_run_player_atk = PLAYER_DEF.atk
	_run_regen_progress = 0.0
	_run_seed = str(seed_value)
	var random_service = get_node_or_null("/root/RandomService")
	if random_service != null:
		random_service.set_seed(_run_seed)
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null:
		curse_service.reset_run()
	_world_ruin_claims.clear()
	if state != null:
		state.player_xp = 0
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
	_close_world_npc_dialogue(false)
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
	_close_world_npc_dialogue(false)
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
	if _world_npc_dialogue_active:
		if state != null:
			state.add_message("对话还没结束，先听对方把话说完。")
			_refresh_views()
		return
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
		if not _auto_submitting_plan:
			_update_auto_advance_state()

func _on_battle_finished(victory: bool) -> void:
	_close_bag_if_open()
	_close_world_npc_dialogue(false)
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
	if _pending_level_reward:
		_pending_level_reward = false
		_refresh_inventory_ui()
		_refresh_permanent_buffs_ui()
		_refresh_views()
		battle_ui.show_battle()
		return
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
	_update_world_slice_camera()
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
	_sync_actor_roots_with_board_view()


func _update_world_slice_camera() -> void:
	if state == null or not bool(state.is_world_slice):
		return
	if camera == null or state.player == null:
		return
	if not board_view.world_slice_camera_follow:
		return
	board_view.center_world_slice_camera_on_player(state)


func _sync_actor_roots_with_board_view() -> void:
	if board_view == null:
		return
	# Actor and effect views are positioned with board_view.grid_to_world(), which
	# returns the unscaled global top-left of a cell. To make them follow the
	# panned/zoomed board, apply the same scale around the same origin instead of
	# simply copying BoardView's position (that would double-transform the offset).
	var board_position: Vector2 = board_view.position
	var board_scale: Vector2 = board_view.scale
	var counter_origin: Vector2 = board_position * (Vector2.ONE - board_scale)
	$ActorRoot.position = counter_origin
	$ActorRoot.scale = board_scale
	$EffectRoot.position = counter_origin
	$EffectRoot.scale = board_scale


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
			state.add_message("进入酒馆休息区：这里可以调整行动编排，也可以按确认键和邻近幸存者交谈。")
		else:
			state.add_message("离开酒馆休息区：行动编排已锁定。")
	_world_slice_last_rest_area_state = editable_now


func _try_interact_with_world_npc() -> bool:
	if state == null or not bool(state.is_world_slice) or _actor_interaction_service == null:
		return false
	var result: Dictionary = _actor_interaction_service.interact(state, _world_npc_interaction_counts)
	if not bool(result.get("handled", false)):
		if _world_npc_dialogue_active:
			_close_world_npc_dialogue()
			return true
		if _is_player_in_world_slice_rest_area():
			state.add_message("你环顾了一圈，但附近没有人接话。")
			_refresh_views()
			return true
		return false
	var speaker: String = String(result.get("title", result.get("npc_name", "陌生人")))
	var line: String = String(result.get("line", ""))
	if line.is_empty():
		line = "只是安静地点了点头。"
	var actor_id := String(result.get("actor_id", result.get("npc_id", "")))
	var actor_name := String(result.get("actor_name", result.get("npc_name", speaker)))
	line = _resolve_world_actor_dialogue_line(actor_id, line)
	state.tracked_world_actor_id = actor_id
	state.show_tracked_world_actor_hint = true
	state.world_actor_display_names[actor_id] = actor_name
	state.tracked_world_npc_id = actor_id
	state.show_tracked_world_npc_hint = true
	_world_npc_dialogue_active = true
	_world_npc_dialogue_npc_id = actor_id
	_try_grant_world_actor_first_talk_reward(actor_id, speaker)
	if is_instance_valid(battle_ui):
		battle_ui.show_world_npc_dialogue(speaker, line)
	state.add_message("%s：%s" % [speaker, line])
	var dialogue_resource_path := String(result.get("dialogue_resource_path", ""))
	if not dialogue_resource_path.is_empty():
		var dialogue_service = get_node_or_null("/root/DialogueService")
		if dialogue_service != null and dialogue_service.has_method("start_dialogue"):
			dialogue_service.call("start_dialogue", dialogue_resource_path, String(result.get("dialogue_cue", "")), [self, state])
	_refresh_views()
	return true


func _resolve_world_actor_dialogue_line(actor_id: String, fallback_line: String) -> String:
	if actor_id == "tavern_keeper" and int(_world_npc_interaction_counts.get(actor_id, 0)) == 1:
		return "“别急着出门。我先把攻击 token 放进你的备用行动池；记得去分配键位，出手才会朝你面前劈出去。”"
	return fallback_line


func _try_grant_world_actor_first_talk_reward(actor_id: String, speaker: String) -> void:
	if actor_id != "tavern_keeper":
		return
	if int(_world_npc_interaction_counts.get(actor_id, 0)) != 1:
		return
	_ensure_action_helpers()
	if not _action_program.add_token_to_pool("A", false):
		return
	state.add_message("%s把攻击 token 放进了你的备用行动池。去背包里把它分配到一个键位上，再出门。" % speaker)
	state.add_feed_message("获得了“攻击”动作。", "token")
	_refresh_key_program_ui()


func _submit_world_interact_action() -> bool:
	if state == null or not bool(state.is_world_slice) or state.player == null:
		return false
	if _actor_interaction_service == null:
		return false
	var has_target: bool = _actor_interaction_service.find_interactable_actor(state) != null
	if not has_target:
		if _try_interact_with_world_ruin():
			return true
		if _world_npc_dialogue_active:
			return _try_interact_with_world_npc()
		if _is_player_in_world_slice_rest_area():
			state.add_message("你环顾了一圈，但附近没有人接话。")
			_refresh_views()
			return true
		return false
	if state.phase != "planning" or state.battle_finished:
		return true
	var interact_action = _build_world_interact_action()
	if interact_action == null:
		return false
	turn_controller.submit_player_plan([interact_action])
	return true


func _try_interact_with_world_ruin() -> bool:
	if state == null or not bool(state.is_world_slice) or state.player == null or state.map_data == null:
		return false
	var ruin_record: Dictionary = _find_ruin_record_at_player()
	if ruin_record.is_empty():
		return false
	var ruin_id: String = String(ruin_record.get("id", ""))
	if ruin_id.is_empty():
		return false
	if _world_ruin_claims.has(ruin_id):
		state.add_message("这处小遗迹已经调查过了。")
		_refresh_views()
		return true
	_world_ruin_claims[ruin_id] = true
	_ensure_action_helpers()
	var granted: Array[String] = []
	if _action_program.add_token_to_pool("SL", false):
		granted.append("SL")
	if _action_program.add_token_to_pool("SR", false):
		granted.append("SR")
	if granted.is_empty():
		state.add_message("你翻找了这处小遗迹，但这里只剩下已经学会的旧套路。")
	else:
		state.add_message("你调查了这处小遗迹，获得了 %s，并已放入备用行动池。" % "/".join(granted))
	_refresh_key_program_ui()
	_refresh_views()
	return true


func _on_boss_poi_requested() -> void:
	if state == null:
		return
	_start_world_autopath(Vector2i(state.tracked_boss_poi_cell), "Boss遗迹")


func _on_safe_zone_poi_requested() -> void:
	if state == null:
		return
	_start_world_autopath(Vector2i(state.tracked_safe_zone_cell), "最近安全区")


func _on_ruin_poi_requested() -> void:
	if state == null:
		return
	_start_world_autopath(Vector2i(state.tracked_nearest_ruin_cell), "最近小遗迹")


func _start_world_autopath(target_cell: Vector2i, label: String) -> void:
	if state == null or not bool(state.is_world_slice) or state.player == null or state.grid == null:
		return
	if target_cell == Vector2i(-1, -1):
		state.add_message("%s 当前未定位。" % label)
		_refresh_views()
		return
	if _world_slice_has_visible_enemy():
		state.add_message("视野内已有敌人，无法开始自动跑图。")
		_refresh_views()
		return

	var path_steps: Array[Vector2i] = _find_world_autopath_path(state.player.grid_pos, target_cell)
	if path_steps.is_empty():
		state.add_message("自动跑图失败：找不到可通行路径。")
		_refresh_views()
		return
	_world_autopath_target = target_cell
	_world_autopath_steps = path_steps
	_world_autopath_active = true
	_world_autopath_last_step_msec = 0
	_world_autopath_step_scheduled = false
	if _battle_presentation != null and _battle_presentation.has_method("use_autopath_timing_profile"):
		_battle_presentation.use_autopath_timing_profile()
	state.add_message("开始自动前往%s。" % label)
	_refresh_views()
	_schedule_world_autopath_step()


func _stop_world_autopath(show_message: bool = true) -> void:
	if not _world_autopath_active:
		return
	_world_autopath_active = false
	_world_autopath_target = Vector2i(-1, -1)
	_world_autopath_steps.clear()
	_world_autopath_last_step_msec = 0
	_world_autopath_step_scheduled = false
	if _battle_presentation != null and _battle_presentation.has_method("use_world_slice_fast_timing_profile") and state != null and bool(state.is_world_slice):
		_battle_presentation.use_world_slice_fast_timing_profile()
	if show_message and state != null:
		state.add_message("自动跑图已停止。")
		_refresh_views()


func _on_turn_finished() -> void:
	_apply_turn_regen()
	_refresh_views()
	_update_auto_advance_state()


func _on_planning_started() -> void:
	_player_input_locked = false
	_refresh_views()
	if not _auto_submitting_plan:
		_schedule_world_autopath_step()


func _schedule_world_autopath_step() -> void:
	if not _world_autopath_active or _world_autopath_step_scheduled:
		return
	_world_autopath_step_scheduled = true
	call_deferred("_run_world_autopath_step_with_delay")


func _run_world_autopath_step_with_delay() -> void:
	if not _world_autopath_active:
		_world_autopath_step_scheduled = false
		return
	var cycle_duration := 0.1
	if _battle_presentation != null and _battle_presentation.has_method("get_action_cycle_duration"):
		cycle_duration = maxf(0.01, float(_battle_presentation.get_action_cycle_duration()))
	if _world_autopath_last_step_msec > 0:
		await get_tree().create_timer(cycle_duration).timeout
	_world_autopath_step_scheduled = false
	_call_world_autopath_step()


func _call_world_autopath_step() -> void:
	if not _world_autopath_active:
		return
	if state == null or not bool(state.is_world_slice) or state.player == null or state.phase != "planning" or state.battle_finished:
		return
	if _world_slice_has_visible_enemy():
		_stop_world_autopath(false)
		state.add_message("视野内出现敌人，自动跑图已暂停。")
		_refresh_views()
		return
	if state.player.grid_pos == _world_autopath_target:
		_stop_world_autopath(false)
		state.add_message("已抵达目标位置。")
		_refresh_views()
		return
	if _world_autopath_steps.is_empty():
		_stop_world_autopath(false)
		state.add_message("自动跑图结束。")
		_refresh_views()
		return
	var next_step: Vector2i = _world_autopath_steps[0]
	if next_step == Vector2i.ZERO:
		_stop_world_autopath(false)
		state.add_message("自动跑图失败：找不到可通行路径。")
		_refresh_views()
		return
	_world_autopath_last_step_msec = Time.get_ticks_msec()
	_world_autopath_steps.remove_at(0)
	var move_action = ActionInstanceScript.new()
	move_action.actor = state.player
	move_action.def = ACTION_MOVE_KEY
	move_action.chosen_dir = next_step
	move_action.key_id = "AUTOPATH"
	if move_action.def == null:
		_stop_world_autopath(false)
		state.add_message("自动跑图失败：缺少移动动作定义。")
		_refresh_views()
		return
	turn_controller.submit_player_plan([move_action])


func _find_world_autopath_path(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	if state == null or state.grid == null:
		return []
	if start_cell == target_cell:
		return []

	var heap := _AStarHeap.new()
	var came_from: Dictionary = {}
	var g_score := {start_cell: 0}
	var closed: Dictionary = {}
	var start_h := _manhattan(start_cell, target_cell)
	heap.push(start_cell, start_h)

	while not heap.is_empty():
		var current: Vector2i = heap.pop()
		if closed.has(current):
			continue
		closed[current] = true

		if current == target_cell:
			return _reconstruct_path_steps(came_from, current, start_cell)

		var current_g: int = int(g_score.get(current, 1_000_000))
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next_cell: Vector2i = current + dir
			if not state.grid.is_inside(next_cell):
				continue
			if closed.has(next_cell):
				continue
			if next_cell != target_cell and not state.grid.can_enter(next_cell):
				continue

			var tentative_g := current_g + 1
			var existing_g: int = int(g_score.get(next_cell, 1_000_000))
			if tentative_g >= existing_g:
				continue

			came_from[next_cell] = current
			g_score[next_cell] = tentative_g
			var next_f := tentative_g + _manhattan(next_cell, target_cell)
			heap.push(next_cell, next_f)
	return []


class _AStarHeap:
	var _nodes: Array[Vector2i] = []
	var _priorities: Array[int] = []

	func is_empty() -> bool:
		return _nodes.is_empty()

	func push(node: Vector2i, priority: int) -> void:
		_nodes.append(node)
		_priorities.append(priority)
		var index := _nodes.size() - 1
		while index > 0:
			var parent := (index - 1) / 2
			if _priorities[parent] <= _priorities[index]:
				break
			_swap(index, parent)
			index = parent

	func pop() -> Vector2i:
		var last_index := _nodes.size() - 1
		_swap(0, last_index)
		var node: Vector2i = _nodes.pop_back()
		_priorities.pop_back()
		_heapify(0)
		return node

	func _heapify(index: int) -> void:
		var size := _nodes.size()
		while true:
			var left := index * 2 + 1
			var right := index * 2 + 2
			var smallest := index
			if left < size and _priorities[left] < _priorities[smallest]:
				smallest = left
			if right < size and _priorities[right] < _priorities[smallest]:
				smallest = right
			if smallest == index:
				break
			_swap(index, smallest)
			index = smallest

	func _swap(a: int, b: int) -> void:
		var temp_node := _nodes[a]
		var temp_priority := _priorities[a]
		_nodes[a] = _nodes[b]
		_priorities[a] = _priorities[b]
		_nodes[b] = temp_node
		_priorities[b] = temp_priority


func _reconstruct_path_steps(came_from: Dictionary, current: Vector2i, start_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [current]
	var cursor: Vector2i = current
	while came_from.has(cursor):
		cursor = Vector2i(came_from[cursor])
		cells.append(cursor)
		if cursor == start_cell:
			break
	cells.reverse()
	var steps: Array[Vector2i] = []
	for index in range(1, cells.size()):
		steps.append(cells[index] - cells[index - 1])
	return steps


func _world_slice_has_visible_enemy() -> bool:
	if state == null:
		return false
	for actor in state.get_alive_enemies():
		if actor != null and state.visible_cells.has(actor.grid_pos):
			return true
	return false


func _on_actor_damaged(actor, amount: int) -> void:
	if actor != null and state != null and state.player != null and actor == state.player:
		_stop_world_autopath(false)
		state.add_message("受到伤害，自动跑图已停止。")
		_refresh_views()


func _on_actor_died(actor) -> void:
	if state == null or actor == null or state.player == null:
		return
	if String(actor.team) != "enemy":
		return
	state.player_xp += 1
	state.add_message("击杀敌人，获得 1 点经验。当前经验：%d。" % int(state.player_xp))
	_ensure_action_helpers()
	if not _action_program.has_token("CA"):
		_action_program.add_token_to_pool("CA", false)
		state.add_message("第一只怪掉落了十字刃动作。你自动拾取并将其放入备用行动池。")
		state.add_feed_message("获得了“十字刃”动作。", "token")
	_try_trigger_level_up_reward()
	_refresh_inventory_ui()
	_refresh_key_program_ui()
	_refresh_views()


func _try_trigger_level_up_reward() -> void:
	if state == null or _pending_level_reward:
		return
	var target_xp := _xp_required_for_next_level(state.player_level)
	if state.player_xp < target_xp:
		return
	state.player_level += 1
	_run_player_max_hp += 1
	_run_player_hp = min(_run_player_max_hp, _run_player_hp + 1)
	if state.player != null:
		state.player.max_hp = _run_player_max_hp
		state.player.hp = min(state.player.max_hp, state.player.hp + 1)
	_pending_level_reward = true
	_current_rewards = _build_level_up_rewards()
	if is_instance_valid(battle_ui):
		battle_ui.show_reward(_current_rewards, "升级选择", "生命上限 +1，并恢复 1 点生命。请选择一个永久增益。")
	state.add_message("升级！你达到了 Lv.%d，生命上限 +1。请选择一个永久增益。" % int(state.player_level))


func _xp_required_for_next_level(level: int) -> int:
	return maxi(1, level * 2)


func _regen_per_turn(level: int) -> float:
	return 0.5 + float(maxi(0, level - 1)) * 0.05


func _apply_turn_regen() -> void:
	if state == null or state.player == null or state.battle_finished:
		return
	if bool(state.is_safe_training):
		return
	if state.player.hp >= state.player.max_hp:
		_run_regen_progress = 0.0
		_run_player_hp = state.player.hp
		return

	_run_regen_progress += _regen_per_turn(int(state.player_level))
	var healed: int = 0
	while _run_regen_progress >= 1.0 and state.player.hp < state.player.max_hp:
		state.player.hp += 1
		healed += 1
		_run_regen_progress -= 1.0

	if healed > 0:
		state.add_message("自然恢复：生命 +%d。" % healed)
	if state.player.hp >= state.player.max_hp:
		_run_regen_progress = 0.0
	_run_player_hp = state.player.hp


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _find_ruin_record_at_player() -> Dictionary:
	if state == null or state.player == null or state.map_data == null:
		return {}
	for record in state.map_data.get_poi_records():
		if String(record.get("type", "")) != "ruin":
			continue
		if Vector2i(record.get("interaction_cell", Vector2i(-1, -1))) == state.player.grid_pos:
			return record
	return {}


func _build_world_interact_action():
	if state == null or state.player == null:
		return null
	var action = ActionInstanceScript.new()
	action.actor = state.player
	action.def = ACTION_INTERACT
	action.key_id = "INTERACT"
	return action


func _on_world_npc_interaction_requested(_actor) -> void:
	_try_interact_with_world_npc()


func _close_world_npc_dialogue(refresh: bool = true) -> void:
	_world_npc_dialogue_active = false
	_world_npc_dialogue_npc_id = ""
	if is_instance_valid(battle_ui):
		battle_ui.hide_world_npc_dialogue()
	if refresh:
		_refresh_views()


func _is_player_in_world_slice_rest_area() -> bool:
	if state == null or state.player == null or state.map_data == null:
		return false
	var map_cell = state.map_data.get_cell(state.player.grid_pos)
	if map_cell == null:
		return false
	if not bool(map_cell.walkable):
		return false
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
		"wisp":
			return WISP_DEF
		"brute":
			return BRUTE_DEF
		"boss":
			return BOSS_DEF
		"line_warden":
			return LINE_WARDEN_DEF
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
		{"name": "获得遗物：力场棱镜", "kind": "add_modifier", "modifier": MOD_FORCE_PRISM},
		{"name": "最大生命 +2", "kind": "max_hp", "value": 2},
		{"name": "攻击 +1", "kind": "attack", "value": 1},
	]


func _build_level_up_rewards() -> Array:
	var rewards: Array = []
	for modifier in [
		MOD_ECHO_STRIKE,
		MOD_ECHO_STEP,
		MOD_FORCE_PRISM,
		MOD_LONG_DRAW,
		MOD_BLOOD_DRAIN,
		MOD_STORMSTEP,
		MOD_KEEN_EDGE,
		MOD_PHALANX_RUSH,
		MOD_LANCER_FOCUS,
		MOD_CYCLONE_FURY,
		MOD_BATTLE_TRANCE,
	]:
		if modifier == null:
			continue
		var modifier_id := String(modifier.id)
		if modifier_id.is_empty() or _run_modifier_ids.has(modifier_id):
			continue
		rewards.append({
			"name": "升级增益：%s" % String(modifier.display_name),
			"description": String(modifier.description),
			"kind": "add_modifier",
			"modifier": modifier,
		})
		if rewards.size() >= 3:
			return rewards

	for fallback_reward in [
		{"name": "升级增益：最大生命 +2", "description": "立刻提高 2 点生命上限，并恢复同等生命。", "kind": "max_hp", "value": 2},
		{"name": "升级增益：攻击 +1", "description": "永久提高 1 点基础攻击。", "kind": "attack", "value": 1},
		{"name": "升级增益：恢复 2 点生命", "description": "立刻恢复 2 点生命。", "kind": "heal", "value": 2},
	]:
		rewards.append(fallback_reward)
		if rewards.size() >= 3:
			break
	return rewards

func _apply_reward(reward: Dictionary) -> void:
	match String(reward["kind"]):
		"add_modifier":
			var modifier = reward.get("modifier")
			if _add_run_modifier(modifier):
				if state != null and modifier != null:
					state.add_feed_message("获得了永久效果“%s”。" % String(modifier.display_name), "modifier")
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

func _inventory_labels() -> Array[String]:
	var labels: Array[String] = []
	if state != null:
		labels.append("经验：%d" % int(state.player_xp))
		labels.append("每回合恢复：%.2f" % _regen_per_turn(int(state.player_level)))
	labels.append("基础攻击：%s" % String(ACTION_ATTACK.display_name))
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
# - `A` 是固定的基础攻击 token，会直接解析成 `attack`。
# - 后续若要加入武器风格动作，应直接做成新的独立 token，而不是切换当前武器。
# - 只有在休息点可以调整 token 与键槽，战斗中行动编码锁定。
# Key-program layer notes:
# - slots store editable base-action tokens
# - slot execution expands those tokens into runtime base actions
# - attack-style variants should be exposed as their own tokens
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
	if state != null:
		state.add_feed_message("获得了“%s”动作。" % _token_display_name(key_id), "token")
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
	if _world_npc_dialogue_active:
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


func _on_auto_advance_mode_changed(mode: int) -> void:
	match mode:
		BattleUI.AUTO_PAUSE:
			turn_controller.auto_advance_delay = 0.0
		BattleUI.AUTO_PLAY:
			turn_controller.auto_advance_delay = AUTO_PLAY_DELAY
		BattleUI.AUTO_FAST:
			turn_controller.auto_advance_delay = AUTO_FAST_DELAY
	_update_auto_advance_state()


func _update_auto_advance_state() -> void:
	if turn_controller.auto_advance_delay <= 0.0:
		return
	if state == null or state.battle_finished:
		return
	if state.phase != "planning":
		return
	if _auto_submitting_plan or _world_autopath_active or _bag_open or _world_npc_dialogue_active:
		return
	_auto_submitting_plan = true
	_player_input_locked = true
	_submit_cached_plan()
	_auto_submitting_plan = false


func _submit_cached_plan() -> void:
	turn_controller.submit_player_plan([])


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


func get_world_slice_npcs() -> Array:
	if state == null:
		return []
	var result: Array = []
	for actor in state.actors:
		if actor != null and actor.tags.has("npc") and not actor.is_dead():
			result.append(actor)
	return result


func get_tracked_world_npc_summary() -> Dictionary:
	return get_tracked_world_actor_summary()


func get_tracked_world_actor_summary() -> Dictionary:
	if state == null:
		return {}
	var actor_id := String(state.tracked_world_actor_id)
	if actor_id.is_empty():
		actor_id = String(state.tracked_world_npc_id)
	if actor_id.is_empty():
		return {}
	return {
		"actor_id": actor_id,
		"npc_id": actor_id,
		"display_name": String(state.world_actor_display_names.get(actor_id, state.world_npc_display_names.get(actor_id, actor_id))),
		"cell": Vector2i(state.world_actor_positions.get(actor_id, state.world_npc_positions.get(actor_id, Vector2i(-1, -1)))),
		"show_hint": bool(state.show_tracked_world_actor_hint) or bool(state.show_tracked_world_npc_hint),
		"relative_hint": String(state.tracked_world_actor_relative_hint if not String(state.tracked_world_actor_relative_hint).is_empty() else state.tracked_world_npc_relative_hint),
	}


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
		"run_regen_progress": _run_regen_progress,
		"run_seed": _run_seed,
		"run_modifier_ids": _run_modifier_ids,
		"world_npc_interaction_counts": _world_npc_interaction_counts.duplicate(true),
		"world_ruin_claims": _world_ruin_claims.duplicate(true),
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
	_run_regen_progress = float(data.get("run_regen_progress", 0.0))
	_run_seed = data.get("run_seed", "")
	var interaction_counts = data.get("world_npc_interaction_counts", {})
	var ruin_claims = data.get("world_ruin_claims", {})
	_world_npc_interaction_counts = interaction_counts.duplicate(true) if typeof(interaction_counts) == TYPE_DICTIONARY else {}
	_world_ruin_claims = ruin_claims.duplicate(true) if typeof(ruin_claims) == TYPE_DICTIONARY else {}

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
