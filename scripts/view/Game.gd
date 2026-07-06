extends Node

signal pause_menu_requested

@export var show_title_on_ready := true

const GameStateScript := preload("res://scripts/core/GameState.gd")
const GridModelScript := preload("res://scripts/core/GridModel.gd")
const MapDataScript := preload("res://scripts/core/MapData.gd")
const MapCellScript := preload("res://scripts/core/MapCell.gd")
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
const GOBLIN_SCOUT_DEF := preload("res://data/actors/goblin_scout.tres")
const GOBLIN_SLINGER_DEF := preload("res://data/actors/goblin_slinger.tres")
const AOE_SLIME_DEF := preload("res://data/actors/aoe_slime.tres")
const SPLIT_SLIME_DEF := preload("res://data/actors/split_slime.tres")
const SMALL_SLIME_DEF := preload("res://data/actors/small_slime.tres")
const SLIME_GOD_DEF := preload("res://data/actors/slime_god.tres")

const ACTION_MOVE_FORWARD := preload("res://data/actions/move_forward.tres")
const ACTION_MOVE_BACK := preload("res://data/actions/move_back.tres")
const ACTION_STEP_LEFT := preload("res://data/actions/step_left.tres")
const ACTION_STEP_RIGHT := preload("res://data/actions/step_right.tres")
const ACTION_DASH := preload("res://data/actions/dash.tres")
const ACTION_HOOK_PULL := preload("res://data/actions/hook_pull.tres")
const ACTION_SLIME_BIND := preload("res://data/actions/slime_bind.tres")
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
const MOD_FORCE_PRISM := preload("res://data/modifiers/force_prism.tres")
const MOD_LONG_DRAW := preload("res://data/modifiers/long_draw.tres")
const MOD_BLOOD_DRAIN := preload("res://data/modifiers/blood_drain.tres")
const MOD_STORMSTEP := preload("res://data/modifiers/stormstep.tres")
const MOD_KEEN_EDGE := preload("res://data/modifiers/keen_edge.tres")
const MOD_PHALANX_RUSH := preload("res://data/modifiers/phalanx_rush.tres")
const MOD_LANCER_FOCUS := preload("res://data/modifiers/lancer_focus.tres")
const MOD_CYCLONE_FURY := preload("res://data/modifiers/cyclone_fury.tres")
const MOD_BATTLE_TRANCE := preload("res://data/modifiers/battle_trance.tres")

const MUSIC_TITLE := "title"
const MUSIC_DUNGEON := "dungeon"
const MUSIC_ELITE := "elite"
const MUSIC_BOSS := "boss"
const MUSIC_REST := "rest"

const ROOM_SIZE := 8
const MAP_NODE_COMBAT := "combat"
const MAP_NODE_REST := "rest"
const MAP_NODE_BOSS := "boss"
const KEY_TOKEN_POOL_SLOT_ID := "POOL"
const AUTO_PLAY_DELAY := 2.0
const AUTO_FAST_DELAY := 1.0
const AUTO_ADVANCE_PAUSE := 0
const AUTO_ADVANCE_PLAY := 1
const AUTO_ADVANCE_FAST := 2
const BOSS_DUNGEON_MAP_SIZE := Vector2i(256, 256)
const BOSS_DUNGEON_CHAMBER_SIZE := Vector2i(56, 56)

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
@onready var world_loading_overlay = $CanvasLayerLoading/WorldLoadingOverlay
@onready var tile_reveal_loading_screen = $CanvasLayerLoading/TileRevealLoadingScreen
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
var _auto_advance_mode := AUTO_ADVANCE_PAUSE
var _boss_adhesive_key_id := ""
var _boss_hidden_layer_triggered := false
var _boss_hidden_layer_active := false
var _hidden_boss_locked_keys: Array[String] = []
var _slime_god_phase_two_triggered := false

var _held_move_action := ""
var _held_move_repeat_delay := 0.0
const MOVE_REPEAT_INITIAL_DELAY := 0.28
const MOVE_REPEAT_INTERVAL := 0.12
const KEY_SUBMIT_COOLDOWN_MS := 150
var _last_key_submit_msec: Dictionary = {}

func _ready() -> void:
	_action_by_id = {
		"move_forward": ACTION_MOVE_FORWARD,
		"move_back": ACTION_MOVE_BACK,
		"step_left": ACTION_STEP_LEFT,
		"step_right": ACTION_STEP_RIGHT,
		"dash": ACTION_DASH,
		"hook_pull": ACTION_HOOK_PULL,
		"slime_bind": ACTION_SLIME_BIND,
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
	enemy_planner.attack_actions_by_id = _action_by_id
	var enemy_spawn_service = get_node_or_null("/root/EnemySpawnService")
	if enemy_spawn_service != null:
		enemy_spawn_service.register_enemy_defs([SLIME_DEF, WISP_DEF, BRUTE_DEF, BOSS_DEF, LINE_WARDEN_DEF, GOBLIN_SCOUT_DEF, GOBLIN_SLINGER_DEF, AOE_SLIME_DEF, SPLIT_SLIME_DEF, SMALL_SLIME_DEF, SLIME_GOD_DEF])

	_connect_signals()
	_register_save_provider()
	if show_title_on_ready:
		battle_ui.show_title()
		_play_music_for_state()

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
			if OS.is_debug_build() and event.keycode == KEY_COMMA:
				_debug_enter_boss_room()
				get_viewport().set_input_as_handled()
				return
			if OS.is_debug_build() and event.keycode == KEY_PERIOD:
				_debug_set_player_san(15)
				get_viewport().set_input_as_handled()
				return
			if OS.is_debug_build() and event.keycode == KEY_SEMICOLON:
				_kill_all_enemies_debug()
				get_viewport().set_input_as_handled()
				return
			if OS.is_debug_build() and event.keycode == KEY_APOSTROPHE:
				_restore_player_debug_state()
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
	if input_service.is_move_action(action_name):
		_held_move_action = action_name
		_held_move_repeat_delay = MOVE_REPEAT_INITIAL_DELAY
	_submit_key_chain(key_id)


func _process(delta: float) -> void:
	if _held_move_action.is_empty():
		return
	if state == null or state.phase != "planning" or state.battle_finished:
		_held_move_action = ""
		return
	if _bag_open or _world_npc_dialogue_active or _player_input_locked or _auto_submitting_plan:
		return

	var input_service = get_node_or_null("/root/PlayerInputService")
	if input_service == null or not input_service.is_move_action(_held_move_action):
		_held_move_action = ""
		return

	if not Input.is_action_pressed(_held_move_action):
		_held_move_action = ""
		return

	_held_move_repeat_delay -= delta
	if _held_move_repeat_delay > 0.0:
		return

	_held_move_repeat_delay = MOVE_REPEAT_INTERVAL
	var key_id: String = input_service.get_key_id_for_action(_held_move_action)
	_submit_key_chain(key_id, true)


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


func return_to_title() -> void:
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.play_music_by_key(MUSIC_TITLE)
	set_game_visible(false)


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
	if tile_reveal_loading_screen != null:
		tile_reveal_loading_screen.show_loading("生成地图中", "准备世界参数…", 0.0)
	elif world_loading_overlay != null:
		world_loading_overlay.show_loading("生成地图中", "准备世界参数…", 0.0)
	await get_tree().process_frame
	start_world_slice_debug(_make_runtime_seed("world_slice_run"))
	_play_music_for_state()


func start_run_legacy() -> void:
	_start_new_run(_make_runtime_seed("legacy_run"))


func start_room_chain_legacy() -> void:
	start_run_legacy()

func start_seeded_run(seed_value) -> void:
	_start_new_run(seed_value)


func start_world_slice_debug(seed_value: String = "") -> void:
	_ensure_action_helpers()
	_world_npc_interaction_counts.clear()
	_world_ruin_claims.clear()
	_run_seed = seed_value if not seed_value.is_empty() else _make_runtime_seed("world_slice_debug")
	var random_service = get_node_or_null("/root/RandomService")
	if random_service != null:
		random_service.set_seed(_run_seed)
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
	_boss_adhesive_key_id = ""
	_boss_hidden_layer_triggered = false
	_boss_hidden_layer_active = false
	_hidden_boss_locked_keys.clear()
	_slime_god_phase_two_triggered = false
	_close_world_npc_dialogue(false)
	state = await _world_slice_controller.create_demo_state_with_progress(_run_seed, Callable(self, "_on_world_generation_progress")) if _world_slice_controller != null else null
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
	_restore_auto_advance_mode()
	_update_world_slice_editability(true)
	_refresh_world_visibility("init")
	_refresh_views()
	set_game_visible(true)
	if tile_reveal_loading_screen != null and tile_reveal_loading_screen.visible:
		tile_reveal_loading_screen.set_progress(1.0)
		await get_tree().create_timer(1.0).timeout
		await tile_reveal_loading_screen.fade_to_black_and_hide()
	elif tile_reveal_loading_screen != null:
		tile_reveal_loading_screen.hide_loading()
	elif world_loading_overlay != null:
		world_loading_overlay.hide_loading()
	_play_music_for_state()


func _make_runtime_seed(prefix: String = "run") -> String:
	return "%s_%d_%d" % [prefix, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]


func _on_world_generation_progress(progress_data: Dictionary) -> void:
	var progress_ratio := float(progress_data.get("progress", 0.0))
	if tile_reveal_loading_screen != null:
		tile_reveal_loading_screen.set_progress(progress_ratio, String(progress_data.get("stage_label", "")))
	elif world_loading_overlay != null:
		world_loading_overlay.show_loading("Generating world", String(progress_data.get("stage_label", "Generating world")), progress_ratio)


func _start_new_run(seed_value) -> void:
	_close_world_npc_dialogue(false)
	_world_autopath_active = false
	_world_autopath_target = Vector2i(-1, -1)
	_world_autopath_steps.clear()
	_world_autopath_last_step_msec = 0
	_world_autopath_step_scheduled = false
	_boss_adhesive_key_id = ""
	_boss_hidden_layer_triggered = false
	_boss_hidden_layer_active = false
	_hidden_boss_locked_keys.clear()
	_slime_god_phase_two_triggered = false
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
	_play_music_for_state()


func _start_map_node(node_index: int) -> void:
	_current_map_node_index = clampi(node_index, 0, MAP_NODES.size() - 1)
	var node := _current_map_node()
	match String(node.get("kind", MAP_NODE_COMBAT)):
		MAP_NODE_REST:
			_start_rest_node(node)
		MAP_NODE_BOSS:
			_start_boss_dungeon_node(node)
		MAP_NODE_COMBAT:
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
	_restore_auto_advance_mode()
	_refresh_views()
	_play_music_for_state()


func _start_boss_dungeon_node(node: Dictionary) -> void:
	_next_actor_id = 0
	_key_program_editable = false
	_world_npc_interaction_counts.clear()
	_world_ruin_claims.clear()
	_world_autopath_active = false
	_world_autopath_target = Vector2i(-1, -1)
	_world_autopath_steps.clear()
	_world_autopath_last_step_msec = 0
	_world_autopath_step_scheduled = false
	_close_world_npc_dialogue(false)
	_slime_god_phase_two_triggered = false
	state = _create_boss_dungeon_state(node)
	_clear_key_slot_preview(false)
	_apply_run_modifiers_to_player()
	if _battle_presentation != null:
		_battle_presentation.reset_for_state(state)
		_battle_presentation.use_world_slice_fast_timing_profile()
		_battle_presentation.set_wait_for_presentation_completion(false)
	enemy_planner.enemies_are_static = false
	turn_controller.start_battle(state)
	battle_ui.set_key_program_editable(false)
	_refresh_key_program_ui()
	_refresh_inventory_ui()
	if board_view != null:
		board_view.world_slice_window_size = Vector2i(29, 29)
		board_view.reset_camera()
	_setup_boss_adhesive_key()
	battle_ui.show_battle()
	_restore_auto_advance_mode()
	_refresh_world_visibility("boss_dungeon_init")
	_refresh_views()
	_play_music_for_state()

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
	_restore_auto_advance_mode()
	_refresh_views()
	_play_music_for_state()

func _submit_key_chain(key_id: String, ignore_cooldown: bool = false) -> void:
	if not ignore_cooldown:
		var now: int = Time.get_ticks_msec()
		var last_msec: int = int(_last_key_submit_msec.get(key_id, 0))
		if now - last_msec < KEY_SUBMIT_COOLDOWN_MS:
			return
	if _world_npc_dialogue_active:
		if state != null:
			state.add_message("对话还没结束，先听对方把话说完。")
			_refresh_views()
		return
	_clear_key_slot_preview(false)
	var curse_service = get_node_or_null("/root/CurseService")
	if _is_boss_dungeon_state() and key_id == _boss_adhesive_key_id:
		_play_slime_adhesive_effect()
		var san_ratio: float = 0.0 if state.player.max_san <= 0 else float(state.player.san) / float(state.player.max_san)
		var fail_probability: float = sqrt(maxf(0.0, 1.0 - san_ratio))
		if not _boss_hidden_layer_active:
			state.player.san = max(0, state.player.san - 1)
			_run_player_san = state.player.san
			san_ratio = 0.0 if state.player.max_san <= 0 else float(state.player.san) / float(state.player.max_san)
			fail_probability = sqrt(maxf(0.0, 1.0 - san_ratio))
			state.add_message("黏附触发：%s键被Boss黏住了。SAN -1。当前失效率 %.0f%%。" % [state.key_name(key_id), fail_probability * 100.0])
			if state.player.san <= 10:
				_try_force_hidden_boss_transition()
				return
		else:
			state.add_message("黏神压制：%s键被持续干扰，但隐藏层不再改动 SAN。当前失效率 %.0f%%。" % [state.key_name(key_id), fail_probability * 100.0])
		var random_service = get_node_or_null("/root/RandomService")
		var roll: float = randf()
		if random_service != null and random_service.has_method("randf_value"):
			roll = float(random_service.randf_value())
		if roll < fail_probability:
			state.add_message("黏附失效：这次按键没有成功触发动作。")
			_refresh_views()
			return
	if _is_boss_dungeon_state() and _hidden_boss_locked_keys.has(key_id):
		state.add_message("黏神压制：%s键已经被彻底封死，无法再用。" % state.key_name(key_id))
		_play_slime_adhesive_effect()
		_refresh_views()
		return
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
		_last_key_submit_msec[key_id] = Time.get_ticks_msec()
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
		_play_music_for_state()
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
		var result_title := "胜利"
		var result_body := "Boss 已被消灭，这趟 run 通关了。"
		if _boss_hidden_layer_active:
			result_title = "隐藏胜利"
			result_body = "黏神已被消灭。你穿过了隐藏层的污染核心。"
		battle_ui.show_custom_result(result_title, result_body)
		_play_music_for_state()
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
	if _is_world_slice_state():
		return state != null and String(state.map_node_kind) == MAP_NODE_REST
	return String(_current_map_node().get("kind", "")) == MAP_NODE_REST

func _is_current_boss_node() -> bool:
	if _is_world_slice_state():
		return state != null and String(state.map_node_kind) == MAP_NODE_BOSS
	return String(_current_map_node().get("kind", "")) == MAP_NODE_BOSS


func _find_first_map_node_index_by_kind(kind: String, fallback_index: int = 0) -> int:
	for index in range(MAP_NODES.size()):
		if String(MAP_NODES[index].get("kind", "")) == kind:
			return index
	return clampi(fallback_index, 0, max(0, MAP_NODES.size() - 1))

func _is_safe_training_state() -> bool:
	return state != null and state.is_safe_training


func _is_world_slice_state() -> bool:
	return state != null and bool(state.is_world_slice)


func _is_boss_dungeon_state() -> bool:
	return state != null and bool(state.is_world_slice) and String(state.map_node_kind) == MAP_NODE_BOSS

func _advance_to_next_map_node(choice_index: int = 0) -> void:
	var next_nodes := _current_map_next_nodes()
	if next_nodes.is_empty():
		battle_ui.show_result(true)
		return

	var safe_choice := clampi(choice_index, 0, next_nodes.size() - 1)
	_sync_run_player_state_from_current_state()
	_start_map_node(int(next_nodes[safe_choice]))
	_play_music_for_state()


func _sync_run_player_state_from_current_state() -> void:
	if state == null or state.player == null:
		return
	_run_player_max_hp = max(1, int(state.player.max_hp))
	_run_player_hp = clampi(int(state.player.hp), 0, _run_player_max_hp)
	_run_player_max_san = max(0, int(state.player.max_san))
	_run_player_san = clampi(int(state.player.san), 0, _run_player_max_san)
	_run_player_atk = max(0, int(state.player.atk))


func _play_music_for_state() -> void:
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service == null:
		return
	if battle_ui != null and battle_ui.visible and battle_ui.is_title_visible():
		audio_service.play_music_by_key(MUSIC_TITLE)
		return
	if state == null or state.battle_finished:
		audio_service.stop_music()
		return
	if _is_boss_dungeon_state():
		audio_service.play_music_by_key(MUSIC_BOSS)
		return
	if _is_current_rest_node() or _is_player_in_world_slice_rest_area():
		audio_service.play_music_by_key(MUSIC_REST)
		return
	if _is_world_slice_state():
		if _world_slice_has_visible_enemy():
			audio_service.play_music_by_key(MUSIC_ELITE)
		else:
			audio_service.play_music_by_key(MUSIC_DUNGEON)
		return
	if _is_current_boss_node():
		audio_service.play_music_by_key(MUSIC_BOSS)
		return
	audio_service.play_music_by_key(MUSIC_DUNGEON)


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

	var refresh_started_at: int = Time.get_ticks_msec()

	if bool(state.is_world_slice):
		_update_world_slice_editability()

	var enemy_preview_started_at: int = Time.get_ticks_msec()
	_update_enemy_preview()
	state.last_refresh_enemy_preview_ms = float(Time.get_ticks_msec() - enemy_preview_started_at)

	_update_world_slice_camera()

	var board_render_started_at: int = Time.get_ticks_msec()
	board_view.render(state)
	state.last_refresh_board_render_ms = float(Time.get_ticks_msec() - board_render_started_at)

	var sync_views_ms: int = 0
	if _battle_presentation != null:
		var snap_actor_views: bool = not _battle_presentation.should_wait_for_presentation()
		if bool(state.is_world_slice):
			# The world-slice board renders a moving window around the player, so
			# visible actor overlays need to resnap when the window origin shifts.
			# BattlePresentationController keeps this scoped to the player plus
			# currently visible actors instead of maintaining views for the whole map.
			snap_actor_views = true
		var sync_started_at: int = Time.get_ticks_msec()
		_battle_presentation.sync_views(state, snap_actor_views)
		sync_views_ms = Time.get_ticks_msec() - sync_started_at

	var hud_started_at: int = Time.get_ticks_msec()
	battle_ui.update_state(state)
	state.last_refresh_hud_ms = float(Time.get_ticks_msec() - hud_started_at)

	_sync_actor_roots_with_board_view()

	var music_started_at: int = Time.get_ticks_msec()
	_play_music_for_state()
	state.last_refresh_music_ms = float(Time.get_ticks_msec() - music_started_at)

	state.last_refresh_total_ms = float(Time.get_ticks_msec() - refresh_started_at)
	state.last_refresh_sync_views_ms = float(sync_views_ms)


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
	if _is_boss_dungeon_state():
		_world_slice_controller.recompute_visibility(state, "player_moved" if actor == state.player else "actor_moved")
		_refresh_views()
		_play_music_for_state()
		return
	_world_slice_controller.on_actor_moved(state, actor, from_cell, to_cell)
	_refresh_views()
	if actor == state.player:
		_play_music_for_state()


func _refresh_world_visibility(reason: String) -> void:
	if state == null or _world_slice_controller == null:
		return
	if not bool(state.is_world_slice):
		return
	_world_slice_controller.recompute_visibility(state, reason)
	_play_music_for_state()


func _update_world_slice_editability(force_refresh: bool = false) -> void:
	if state == null or not bool(state.is_world_slice):
		return
	if _is_boss_dungeon_state():
		_key_program_editable = false
		if is_instance_valid(battle_ui):
			battle_ui.set_key_program_editable(false)
		_world_slice_last_rest_area_state = false
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
		_play_music_for_state()
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
	var actor = result.get("actor")
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
	var handled_poi_npc := _try_resolve_world_poi_npc_interaction(actor_id, actor)
	if handled_poi_npc:
		return true
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
	if actor_id == "ruin_guide":
		var interaction_count := int(_world_npc_interaction_counts.get(actor_id, 0))
		if interaction_count <= 1:
			return "“先别动手翻。附近已经有东西在盯着这边了。再往前一步，它们就会扑上来。”"
		if interaction_count == 2:
			return "“来不及了，它们已经听见了。顶住这五波，我再带你翻下面的刻印。”"
		return "“还没结束。要么继续撑住，要么就别再碰这片废墟。”"
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


func _try_resolve_world_poi_npc_interaction(actor_id: String, actor) -> bool:
	match actor_id:
		"boss_gatekeeper":
			state.add_message("守门人侧过身，让你踏入 Boss遗迹。")
			_refresh_views()
			_sync_run_player_state_from_current_state()
			_start_map_node(_find_first_map_node_index_by_kind(MAP_NODE_BOSS, _current_map_node_index))
			return true
		"ruin_guide":
			var ruin_record := _record_for_world_poi_actor(actor)
			if ruin_record.is_empty():
				return false
			if int(_world_npc_interaction_counts.get(actor_id, 0)) == 1:
				state.add_message("遗迹拾荒者压低声音示警：别急着翻，附近的怪物已经被惊动了。再靠近一步，就会真的冲过来。")
				_refresh_views()
				return true
			_trigger_world_ruin_enemy_waves(5)
			return _claim_world_ruin_record(ruin_record)
		_:
			return false


func _record_for_world_poi_actor(actor) -> Dictionary:
	if actor == null or state == null or state.map_data == null:
		return {}
	for tag in actor.tags:
		var text := String(tag)
		if not text.begins_with("poi_record:"):
			continue
		var record_id := text.trim_prefix("poi_record:")
		for record_value in state.map_data.get_poi_records():
			var record: Dictionary = Dictionary(record_value)
			if String(record.get("id", "")) == record_id:
				return record
	return {}


func _claim_world_ruin_record(ruin_record: Dictionary) -> bool:
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
	if _world_slice_controller != null and state != null:
		state.world_enemy_spawn_profile = "event_alert"
		_world_slice_controller.refresh_streamed_enemies(state, "ruin_event_alert")
		var existing_messages: Array[String] = state.messages.duplicate()
		state.messages.clear()
		for existing_message in existing_messages:
			state.messages.append(existing_message)
		state.messages.append("遗迹的动静惊动了周围更危险的怪物。")
		if state.messages.size() > 9:
			state.messages.resize(9)
	_refresh_key_program_ui()
	_refresh_views()
	return true


func _trigger_world_ruin_enemy_waves(wave_count: int) -> void:
	if _world_slice_controller == null or state == null:
		return
	state.world_enemy_spawn_profile = "event_alert"
	for wave_index in range(maxi(1, wave_count)):
		_world_slice_controller.refresh_streamed_enemies(state, "ruin_npc_wave_%d" % (wave_index + 1))


func _find_world_slice_npc_by_id(npc_id: String):
	if state == null:
		return null
	for actor in state.actors:
		if actor == null or actor.is_dead() or actor.def == null:
			continue
		if not actor.tags.has("npc"):
			continue
		if String(actor.def.id) == npc_id:
			return actor
	return null


func _world_interaction_cell_for_actor(actor) -> Vector2i:
	if actor == null or state == null or state.map_data == null or state.grid == null or state.player == null:
		return Vector2i(-1, -1)
	var preferred_cell: Vector2i = actor.grid_pos - actor.facing
	if preferred_cell != Vector2i(-1, -1) and state.map_data.is_walkable(preferred_cell):
		var preferred_occupant = state.grid.get_actor(preferred_cell)
		if preferred_occupant == null or preferred_occupant == state.player:
			return preferred_cell
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = actor.grid_pos + dir
		if not state.map_data.is_walkable(cell):
			continue
		var occupant = state.grid.get_actor(cell)
		if occupant != null and occupant != state.player:
			continue
		var distance := float(state.player.grid_pos.distance_squared_to(cell))
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _submit_world_interact_action() -> bool:
	if state == null or not bool(state.is_world_slice) or state.player == null:
		return false
	if _actor_interaction_service == null:
		return false
	var target_actor = _actor_interaction_service.find_interactable_actor(state)
	var has_target: bool = target_actor != null
	if not has_target:
		if _world_npc_dialogue_active:
			return _try_interact_with_world_npc()
		if _is_player_in_world_slice_rest_area():
			state.add_message("你环顾了一圈，但附近没有人接话。")
			_refresh_views()
			return true
		return false
	if target_actor != null and target_actor.tags.has("poi_npc"):
		return _try_interact_with_world_npc()
	if state.phase != "planning" or state.battle_finished:
		return true
	var interact_action = _build_world_interact_action()
	if interact_action == null:
		return false
	turn_controller.submit_player_plan([interact_action])
	return true


func _on_boss_poi_requested() -> void:
	if state == null:
		return
	var boss_gatekeeper = _find_world_slice_npc_by_id("boss_gatekeeper")
	if boss_gatekeeper != null:
		var interaction_cell := _world_interaction_cell_for_actor(boss_gatekeeper)
		_focus_world_poi(interaction_cell if interaction_cell != Vector2i(-1, -1) else Vector2i(boss_gatekeeper.grid_pos), "Boss遗迹")
		return
	_focus_world_poi(Vector2i(state.tracked_boss_poi_cell), "Boss遗迹")


func _on_safe_zone_poi_requested() -> void:
	if state == null:
		return
	_focus_world_poi(Vector2i(state.tracked_safe_zone_cell), "最近安全区")


func _on_ruin_poi_requested() -> void:
	if state == null:
		return
	var ruin_guide = _find_world_slice_npc_by_id("ruin_guide")
	if ruin_guide != null:
		var interaction_cell := _world_interaction_cell_for_actor(ruin_guide)
		_focus_world_poi(interaction_cell if interaction_cell != Vector2i(-1, -1) else Vector2i(ruin_guide.grid_pos), "最近小遗迹")
		return
	_focus_world_poi(Vector2i(state.tracked_nearest_ruin_cell), "最近小遗迹")


func _focus_world_poi(target_cell: Vector2i, label: String) -> void:
	if state == null or not bool(state.is_world_slice) or state.player == null:
		return
	if target_cell == Vector2i(-1, -1):
		state.add_message("%s 当前未定位。" % label)
		_refresh_views()
		return
	if turn_controller != null and float(turn_controller.auto_advance_delay) > 0.0:
		_start_world_autopath(target_cell, label)
		return
	state.focused_nav_target_cell = target_cell
	state.focused_nav_target_label = label
	_stop_world_autopath(false)
	state.add_message("已指向%s。不会自动移动，请自行前往。" % label)
	_refresh_views()


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
	_update_slime_god_corruption_zone()
	_apply_persistent_corruption_penalty()
	_maybe_apply_hidden_boss_key_lock()
	_refresh_views()
	_update_auto_advance_state()
	_play_music_for_state()


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
		_play_music_for_state()
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
		_play_music_for_state()
		_refresh_views()


func _on_actor_died(actor) -> void:
	if state == null or actor == null or state.player == null:
		return
	if String(actor.team) != "enemy":
		return
	_try_spawn_split_children(actor)
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
	_play_music_for_state()


func _maybe_trigger_slime_god_phase_two() -> void:
	if not _boss_hidden_layer_active or _slime_god_phase_two_triggered or state == null:
		return
	for enemy in state.get_alive_enemies():
		if enemy == null or enemy.def == null or String(enemy.def.id) != "slime_god":
			continue
		if enemy.hp > int(floor(float(enemy.max_hp) * 0.5)):
			return
		_slime_god_phase_two_triggered = true
		enemy.atk += 1
		state.add_message("黏神进入第二阶段：攻击更猛烈，封键速度也更快了。")
		_force_lock_hidden_boss_key()
		_update_slime_god_corruption_zone()
		_refresh_key_program_ui()
		_refresh_views()
		return


func _update_slime_god_corruption_zone() -> void:
	if state == null:
		return
	state.persistent_danger_cells.clear()
	if not _boss_hidden_layer_active or not _slime_god_phase_two_triggered:
		return
	for enemy in state.get_alive_enemies():
		if enemy == null or enemy.def == null or String(enemy.def.id) != "slime_god":
			continue
		for y in range(-2, 3):
			for x in range(-2, 3):
				if abs(x) + abs(y) > 3:
					continue
				var cell: Vector2i = enemy.grid_pos + Vector2i(x, y)
				if state.grid == null or not state.grid.is_inside(cell):
					continue
				if not state.persistent_danger_cells.has(cell):
					state.persistent_danger_cells.append(cell)
		state.add_message("黏神的污染在地面扩张，周围区域被长期侵蚀。")
		return


func _apply_persistent_corruption_penalty() -> void:
	if state == null or state.player == null or state.battle_finished:
		return
	if _boss_hidden_layer_active:
		return
	if state.persistent_danger_cells.is_empty():
		return
	if not state.persistent_danger_cells.has(state.player.grid_pos):
		return
	state.player.san = max(0, state.player.san - 1)
	_run_player_san = state.player.san
	state.add_message("污染侵蚀：你站在黏神污染区里。SAN -1。")


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


func _find_challenge_record_at_player() -> Dictionary:
	if state == null or state.player == null or state.map_data == null:
		return {}
	for record in state.map_data.get_poi_records():
		if String(record.get("type", "")) != "challenge_entrance":
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
	for npc_id in ["boss_gatekeeper", "ruin_guide"]:
		var npc = _find_world_slice_npc_by_id(npc_id)
		if npc != null and _world_interaction_cell_for_actor(npc) == state.player.grid_pos:
			return true
	return false

func _update_enemy_preview() -> void:
	if state.phase != "planning" or state.battle_finished:
		state.enemy_intents = []
		state.danger_cells = []
		state.danger_cell_labels.clear()
		state.preview_move_cells = []
		state.preview_attack_cells = []
		return

	var enemy_actions = enemy_planner.preview_enemy_actions(state)
	var intents: Array[String] = []
	for action in enemy_actions:
		intents.append(enemy_planner.describe_action(action))

	state.enemy_intents = intents
	if _is_world_slice_state() and not _is_boss_dungeon_state():
		state.danger_cells = []
		state.danger_cell_labels.clear()
		return
	state.danger_cells = enemy_planner.get_threat_cells(state)
	state.danger_cell_labels = enemy_planner.get_threat_labels(state)

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


func _create_boss_dungeon_state(node: Dictionary):
	var new_state = GameStateScript.new()
	new_state.grid = GridModelScript.new()
	new_state.grid.setup(BOSS_DUNGEON_MAP_SIZE.x, BOSS_DUNGEON_MAP_SIZE.y)
	new_state.room_index = int(node.get("room", 0))
	new_state.room_name = "Boss地牢"
	new_state.map_node_index = _current_map_node_index
	new_state.map_node_kind = MAP_NODE_BOSS
	new_state.map_node_label = String(node.get("label", new_state.room_name))
	new_state.exit_cell = Vector2i(-99, -99)
	new_state.is_world_slice = true
	new_state.is_safe_training = false
	new_state.fov_radius = 10
	new_state.map_data = _build_boss_dungeon_map_data()
	_sync_boss_dungeon_grid_from_map_data(new_state)

	var chamber_origin := Vector2i(
		int((BOSS_DUNGEON_MAP_SIZE.x - BOSS_DUNGEON_CHAMBER_SIZE.x) / 2),
		int((BOSS_DUNGEON_MAP_SIZE.y - BOSS_DUNGEON_CHAMBER_SIZE.y) / 2)
	)
	var chamber_center := chamber_origin + Vector2i(int(BOSS_DUNGEON_CHAMBER_SIZE.x / 2), int(BOSS_DUNGEON_CHAMBER_SIZE.y / 2))
	var player_cell := chamber_center + Vector2i(0, 12)
	var boss_cell := chamber_center + Vector2i(0, 4)

	var player = _add_actor(new_state, PLAYER_DEF, player_cell)
	player.facing = Vector2i.UP
	player.max_hp = _run_player_max_hp
	player.hp = min(_run_player_hp, _run_player_max_hp)
	player.max_san = _run_player_max_san
	player.san = min(_run_player_san, _run_player_max_san)
	player.atk = _run_player_atk

	var boss_def = SLIME_GOD_DEF if _boss_hidden_layer_active else BOSS_DEF
	var boss = _add_actor(new_state, boss_def, boss_cell)
	if boss != null:
		boss.facing = Vector2i.DOWN

	if _boss_hidden_layer_active:
		new_state.room_name = "隐藏黏神层"
		new_state.add_message("路线：%s。SAN 崩塌后你被强制拖入隐藏Boss层，黏神正在深处等待。" % _map_summary())
	else:
		new_state.add_message("路线：%s。你进入了Boss地牢，整层扩展成与外部世界同级的大地图墓室；行动编码已锁定。" % _map_summary())
	return new_state


func _build_boss_dungeon_map_data():
	var map_data = MapDataScript.new()
	map_data.setup(BOSS_DUNGEON_MAP_SIZE.x, BOSS_DUNGEON_MAP_SIZE.y)
	map_data.seed = "%s_boss_dungeon" % _run_seed
	for cell in map_data.get_all_cells():
		map_data.set_terrain(cell, MapCellScript.TerrainType.STRUCTURE_WALL)

	var chamber_origin := Vector2i(
		int((BOSS_DUNGEON_MAP_SIZE.x - BOSS_DUNGEON_CHAMBER_SIZE.x) / 2),
		int((BOSS_DUNGEON_MAP_SIZE.y - BOSS_DUNGEON_CHAMBER_SIZE.y) / 2)
	)
	_carve_boss_dungeon_rect(map_data, Rect2i(chamber_origin, BOSS_DUNGEON_CHAMBER_SIZE))
	_carve_boss_dungeon_rect(map_data, Rect2i(chamber_origin + Vector2i(8, 8), BOSS_DUNGEON_CHAMBER_SIZE - Vector2i(16, 16)))
	_carve_boss_dungeon_rect(map_data, Rect2i(chamber_origin + Vector2i(25, 0), Vector2i(6, 14)))
	_carve_boss_dungeon_rect(map_data, Rect2i(chamber_origin + Vector2i(25, 42), Vector2i(6, 14)))

	for pillar_offset in [Vector2i(10, 10), Vector2i(42, 10), Vector2i(10, 42), Vector2i(42, 42), Vector2i(26, 18), Vector2i(26, 34)]:
		_fill_boss_dungeon_wall_rect(map_data, Rect2i(chamber_origin + pillar_offset, Vector2i(4, 4)))
	_fill_boss_dungeon_wall_rect(map_data, Rect2i(chamber_origin + Vector2i(24, 0), Vector2i(8, 3)))
	_mark_boss_dungeon_gate(map_data, Rect2i(chamber_origin + Vector2i(24, 0), Vector2i(8, 3)))

	var player_spawn := chamber_origin + Vector2i(int(BOSS_DUNGEON_CHAMBER_SIZE.x / 2), 46)
	map_data.set_player_spawn(player_spawn)
	return map_data


func _carve_boss_dungeon_rect(map_data, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			map_data.set_terrain(Vector2i(x, y), MapCellScript.TerrainType.PLAIN)


func _fill_boss_dungeon_wall_rect(map_data, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			map_data.set_terrain(Vector2i(x, y), MapCellScript.TerrainType.STRUCTURE_WALL)


func _mark_boss_dungeon_gate(map_data, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var map_cell = map_data.get_or_create_cell(Vector2i(x, y))
			if map_cell == null:
				continue
			if not map_cell.tags.has("boss_locked_door"):
				map_cell.tags.append("boss_locked_door")


func _sync_boss_dungeon_grid_from_map_data(new_state) -> void:
	if new_state == null or new_state.grid == null or new_state.map_data == null:
		return
	for cell in new_state.map_data.get_all_cells():
		if not new_state.map_data.is_walkable(cell):
			new_state.grid.add_blocked(cell)

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
		"goblin_scout":
			return GOBLIN_SCOUT_DEF
		"goblin_slinger":
			return GOBLIN_SLINGER_DEF
		"aoe_slime":
			return AOE_SLIME_DEF
		"split_slime":
			return SPLIT_SLIME_DEF
		"small_slime":
			return SMALL_SLIME_DEF
		"slime_god":
			return SLIME_GOD_DEF
		_:
			return SLIME_DEF


func _setup_boss_adhesive_key() -> void:
	_boss_adhesive_key_id = ""
	if state == null or not _is_boss_dungeon_state() or _boss_hidden_layer_active:
		return
	_ensure_action_helpers()
	var available_keys: Array[String] = []
	for key_id in ["W", "A", "S", "D"]:
		if _action_program.has_slot(key_id) and not _action_program.get_slot(key_id).is_empty():
			available_keys.append(key_id)
	if available_keys.is_empty():
		return
	available_keys.sort()
	var random_service = get_node_or_null("/root/RandomService")
	var chosen_index := 0
	if random_service != null and random_service.has_method("randi_range_value"):
		chosen_index = int(random_service.randi_range_value(0, available_keys.size() - 1))
	_boss_adhesive_key_id = available_keys[chosen_index]
	var curse_service = get_node_or_null("/root/CurseService")
	if curse_service != null:
		curse_service.ban_key(_boss_adhesive_key_id, "adhesive", -1)
	if state != null:
		state.add_message("Boss 战开始：%s键被“黏附”锁住了，误按会持续掉 SAN。" % state.key_name(_boss_adhesive_key_id))


func _maybe_apply_hidden_boss_key_lock() -> void:
	if not _boss_hidden_layer_active or state == null or not _is_boss_dungeon_state():
		return
	var lock_interval: int = 5 if _slime_god_phase_two_triggered else 10
	if state.turn_count <= 0 or state.turn_count % lock_interval != 0:
		return
	_force_lock_hidden_boss_key()


func _force_lock_hidden_boss_key() -> void:
	if state == null:
		return
	_ensure_action_helpers()
	var candidates: Array[String] = []
	for key_id in ["W", "A", "S", "D", "Q", "E", "R", "F", "Z", "X", "C", "V"]:
		if _hidden_boss_locked_keys.has(key_id):
			continue
		if not _action_program.has_slot(key_id):
			continue
		if _action_program.get_slot(key_id).is_empty():
			continue
		candidates.append(key_id)
	if candidates.is_empty():
		return
	candidates.sort()
	var random_service = get_node_or_null("/root/RandomService")
	var chosen_index := 0
	if random_service != null and random_service.has_method("randi_range_value"):
		chosen_index = int(random_service.randi_range_value(0, candidates.size() - 1))
	var locked_key_id: String = candidates[chosen_index]
	_hidden_boss_locked_keys.append(locked_key_id)
	state.add_message("黏神扩张：%s键的权限被彻底剥夺了。" % state.key_name(locked_key_id))
	_play_slime_adhesive_effect()
	_refresh_key_program_ui()


func _try_force_hidden_boss_transition() -> void:
	if state == null or not _is_boss_dungeon_state() or _boss_hidden_layer_triggered or _boss_hidden_layer_active:
		return
	_boss_hidden_layer_triggered = true
	_boss_hidden_layer_active = true
	_boss_adhesive_key_id = ""
	state.add_message("SAN 已跌到 10 以下。你被强制拖入隐藏Boss层。")
	_refresh_views()
	_start_boss_dungeon_node(_current_map_node())

func _try_spawn_split_children(actor) -> void:
	if actor == null or actor.def == null or state == null or state.grid == null:
		return
	if not bool(actor.def.split_on_death):
		return
	var spawn_actor_id := String(actor.def.split_spawn_actor_id)
	var spawn_count := int(actor.def.split_spawn_count)
	if spawn_actor_id.is_empty() or spawn_count <= 0:
		return
	var spawn_def = _enemy_def(spawn_actor_id)
	if spawn_def == null:
		return
	var spawned := 0
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if spawned >= spawn_count:
			break
		var spawn_cell: Vector2i = actor.grid_pos + offset
		if not state.grid.is_inside(spawn_cell):
			continue
		if not state.grid.can_enter(spawn_cell):
			continue
		var spawned_actor = _add_actor(state, spawn_def, spawn_cell)
		if spawned_actor == null:
			continue
		spawned_actor.facing = offset
		spawned += 1
	if spawned > 0:
		state.add_message("%s 裂成了 %d 只小史莱姆。" % [actor.def.display_name, spawned])

func _build_rewards() -> Array:
	if _current_room_index == 0:
		return [
			{"name": "获得遗物：回响刃", "kind": "add_modifier", "modifier": MOD_ECHO_STRIKE},
			{"name": "最大生命 +2", "kind": "max_hp", "value": 2},
			{"name": "攻击 +1", "kind": "attack", "value": 1},
		]

	return [
		{"name": "获得遗物：力场棱镜", "kind": "add_modifier", "modifier": MOD_FORCE_PRISM},
		{"name": "最大生命 +2", "kind": "max_hp", "value": 2},
		{"name": "攻击 +1", "kind": "attack", "value": 1},
	]


func _build_level_up_rewards() -> Array:
	var modifier_pool := [
		MOD_ECHO_STRIKE,
		MOD_FORCE_PRISM,
		MOD_LONG_DRAW,
		MOD_BLOOD_DRAIN,
		MOD_STORMSTEP,
		MOD_KEEN_EDGE,
		MOD_PHALANX_RUSH,
		MOD_LANCER_FOCUS,
		MOD_CYCLONE_FURY,
		MOD_BATTLE_TRANCE,
	]
	var random_service = get_node_or_null("/root/RandomService")
	var selected_modifiers: Array = []
	while not modifier_pool.is_empty() and selected_modifiers.size() < 3:
		var chosen_index := 0
		if random_service != null and random_service.has_method("randi_range_value"):
			chosen_index = int(random_service.randi_range_value(0, modifier_pool.size() - 1))
		else:
			chosen_index = randi_range(0, modifier_pool.size() - 1)
		selected_modifiers.append(modifier_pool[chosen_index])
		modifier_pool.remove_at(chosen_index)
	var rewards: Array = []
	for modifier in selected_modifiers:
		if modifier == null:
			continue
		var modifier_id := String(modifier.id)
		if modifier_id.is_empty():
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
	if modifier_id.is_empty():
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
		if state != null and target_slot_id != KEY_TOKEN_POOL_SLOT_ID:
			state.add_message("%s键槽已经放满了；当前每个键位只有 2 个栏位，且每栏只能放 1 个 token。" % state.key_name(target_slot_id))
			_refresh_views()
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
	battle_ui.set_key_program(_action_program.get_key_slots(), _action_program.get_pool_token_stacks())
	battle_ui.set_adhesive_slot(_boss_adhesive_key_id if _is_boss_dungeon_state() and not _boss_hidden_layer_active else "")
	battle_ui.set_disabled_slots(_hidden_boss_locked_keys)


func _play_slime_adhesive_effect() -> void:
	if _battle_presentation == null or state == null or state.player == null:
		return
	var effect_controller = _battle_presentation.effect_controller if _battle_presentation.get("effect_controller") != null else null
	if effect_controller == null or not effect_controller.has_method("spawn_effect_world"):
		return
	effect_controller.spawn_effect_world("slime_burst", board_view.grid_to_world(state.player.grid_pos) + Vector2(board_view.cell_size * 0.5, board_view.cell_size * 0.5), {
		"intensity": 1.15,
		"tint": Color(0.68, 0.34, 0.86, 1.0),
	})


func _kill_all_enemies_debug() -> void:
	if state == null:
		return
	var enemies: Array = state.get_alive_enemies().duplicate()
	var hit_count := 0
	for enemy in enemies:
		if enemy == null:
			continue
		if not state.visible_cells.is_empty() and not state.visible_cells.has(enemy.grid_pos):
			continue
		hit_count += 1
		if resolver != null and resolver.has_method("apply_damage"):
			resolver.apply_damage(state.player, enemy, 9999, state)
		elif resolver != null and resolver.has_method("_kill_actor"):
			enemy.hp = 0
			resolver._kill_actor(enemy, state)
		elif state.grid != null:
			enemy.hp = 0
			state.grid.remove_actor(enemy)
			state.actors.erase(enemy)
			if _battle_presentation != null:
				_battle_presentation.handle_actor_died(enemy)
	if hit_count > 0:
		state.add_message("[debug] 已对视野内 %d 个敌人造成致死伤害。" % hit_count)
	else:
		state.add_message("[debug] 当前视野内没有可处理的敌人。")
	_refresh_views()


func _restore_player_debug_state() -> void:
	if state == null or state.player == null:
		return
	_run_player_max_hp = 50
	_run_player_hp = 50
	_run_player_max_san = 100
	_run_player_san = 100
	state.player.max_hp = 50
	state.player.hp = 50
	state.player.max_san = 100
	state.player.san = 100
	state.add_message("[debug] 玩家状态已恢复：HP 50/50，SAN 100/100。")
	_refresh_inventory_ui()
	_refresh_views()


func _debug_set_player_san(value: int) -> void:
	if state == null or state.player == null:
		return
	var clamped_value := clampi(value, 0, state.player.max_san)
	state.player.san = clamped_value
	_run_player_san = clamped_value
	state.add_message("[debug] 玩家 SAN 已调整到 %d。" % clamped_value)
	_refresh_inventory_ui()
	_refresh_views()


func _debug_enter_boss_room() -> void:
	if state == null:
		return
	state.add_message("[debug] 直接进入 Boss 房。")
	_refresh_views()
	_sync_run_player_state_from_current_state()
	_start_map_node(_find_first_map_node_index_by_kind(MAP_NODE_BOSS, _current_map_node_index))


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
		var audio_service = get_node_or_null("/root/AudioService")
		if audio_service != null:
			audio_service.set_duck_active(_bag_open)


func _close_bag_if_open() -> void:
	if _bag_open and is_instance_valid(battle_ui):
		battle_ui.toggle_bag()
		_bag_open = false
		get_tree().paused = false
		var audio_service = get_node_or_null("/root/AudioService")
		if audio_service != null:
			audio_service.set_duck_active(false)


func _on_auto_advance_mode_changed(mode: int) -> void:
	_auto_advance_mode = mode
	match mode:
		AUTO_ADVANCE_PAUSE:
			turn_controller.auto_advance_delay = 0.0
		AUTO_ADVANCE_PLAY:
			turn_controller.auto_advance_delay = AUTO_PLAY_DELAY
		AUTO_ADVANCE_FAST:
			turn_controller.auto_advance_delay = AUTO_FAST_DELAY
	if mode == AUTO_ADVANCE_PAUSE and _world_autopath_active:
		_stop_world_autopath(false)
		if state != null:
			state.add_message("已关闭自动播放，自动跑图已暂停。")
			_refresh_views()
			return
	_update_auto_advance_state()


func _restore_auto_advance_mode() -> void:
	if not is_instance_valid(battle_ui):
		return
	battle_ui.set_auto_advance_mode(_auto_advance_mode)


func _update_auto_advance_state() -> void:
	if turn_controller.auto_advance_delay <= 0.0:
		return
	if state == null or state.battle_finished:
		return
	if bool(state.is_world_slice):
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
	_play_music_for_state()

func _load_key_program(data: Dictionary) -> void:
	_ensure_action_helpers()
	_action_program.load_save_data(data)
	_refresh_key_program_ui()
