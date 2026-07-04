extends SceneTree

const GameScene := preload("res://scenes/game/Game.tscn")
const ActionProgramControllerScript := preload("res://scripts/core/ActionProgramController.gd")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")
const DuplicateDamageModifierScript := preload("res://scripts/tests/DuplicateDamageModifierDef.gd")
const AmplifyTagDamageModifierScript := preload("res://scripts/tests/AmplifyTagDamageModifierDef.gd")
const DuplicateMoveModifierScript := preload("res://scripts/tests/DuplicateMoveModifierDef.gd")
const AmplifyKnockbackModifierScript := preload("res://scripts/tests/AmplifyKnockbackModifierDef.gd")
const OnHitBonusDamageModifierScript := preload("res://scripts/tests/OnHitBonusDamageModifierDef.gd")
const OnMoveZapAheadModifierScript := preload("res://scripts/tests/OnMoveZapAheadModifierDef.gd")
const WorldSliceControllerScript := preload("res://scripts/core/WorldSliceController.gd")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const TALKATIVE_SLIME_DEF := preload("res://data/actors/talkative_slime.tres")
const LINE_WARDEN_DEF := preload("res://data/actors/line_warden.tres")
const WISP_DEF := preload("res://data/actors/wisp.tres")

func _init() -> void:
	var game = GameScene.instantiate()
	root.add_child(game)
	await process_frame

	await _start_run_at_first_combat(game)

	_require(game.state.room_index == 0, "run starts in room 1")
	_require(game.state.player.hp == 8, "player starts with 8 hp")
	_require(game.state.get_alive_enemies().size() == 2, "first room has two enemies")
	_require(game.state.get_alive_enemies().any(func(actor): return actor != null and String(actor.def.id) == "wisp"), "first room now includes a non-attacking starter enemy")
	_require(game.state.danger_cells.has(Vector2i(2, 1)), "enemy attack range is previewed")

	var enemy = game.state.get_alive_enemies()[0]
	game.state.grid.remove_actor(enemy)
	game.state.grid.place_actor(enemy, Vector2i(2, 1))
	_submit_player_actions(game, ["wait"])
	await process_frame

	_require(game.state.player.hp >= 7, "opening enemies no longer guarantee full early attack pressure")

	await _start_run_at_first_combat(game)
	_submit_player_actions(game, ["move_forward", "attack", "wait"])
	await process_frame

	_require(game.state.turn_count == 1, "submitted plan executes one turn")
	_require(game.state.get_alive_enemies().size() == 1, "move + attack kills first slime")

	game._on_battle_finished(true)
	await process_frame
	_require(game._current_rewards.size() == 3, "victory offers three rewards")

	game._on_reward_chosen(0)
	await process_frame
	_require(game.state.map_node_kind == "rest", "first reward advances to post-practice rest")
	_require(not _reward_list_has_kind(game._current_rewards, "unlock_technique"), "rewards no longer offer weapon technique unlocks")
	_require(not game.get_key_program_pool_tokens().has("lunge"), "lunge does not enter key token pool")
	_require(game._key_program_editable, "post-practice rest unlocks key slot editing")
	var lunge_plan: Array = game._build_key_slot_plan(["R", "R"])
	await process_frame
	_require(_array_equals(game.get_key_program_slots()["W"], ["U"]), "rest editing keeps only natural direction tokens")
	_require(lunge_plan.size() == 2 and lunge_plan[0].def.id == "move_key" and lunge_plan[1].def.id == "move_key", "key program keeps only base move actions")
	var lunge_preview: Dictionary = game._build_key_slot_preview(["R", "R"])
	_require(_string_name_array_equals(lunge_preview.get("trace_symbols", []), [&"F", &"F"]), "rest preview predicts relative trace from absolute direction input")
	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.room_index == 1, "post-practice rest continues to second room")

	var starter_program = ActionProgramControllerScript.new()
	starter_program.setup()
	starter_program.reset_starter_slots("absolute")
	var absolute_slots := starter_program.get_key_slots()
	_require(_array_equals(absolute_slots["W"], ["U"]), "absolute starter preset keeps W mapped to U")
	_require(_array_equals(absolute_slots["S"], ["D"]), "absolute starter preset keeps S mapped to D")
	_require(_array_equals(absolute_slots["A"], ["L"]), "absolute starter preset keeps A mapped to L")
	_require(_array_equals(absolute_slots["D"], ["R"]), "absolute starter preset keeps D mapped to R")
	starter_program.reset_starter_slots("relative")
	var relative_slots := starter_program.get_key_slots()
	_require(_array_equals(relative_slots["W"], ["F"]), "relative starter preset puts F in W")
	_require(_array_equals(relative_slots["S"], ["TR", "TR", "F"]), "relative starter preset puts TR/TR/F in S")
	_require(_array_equals(relative_slots["A"], ["TL", "F"]), "relative starter preset puts TL/F in A")
	_require(_array_equals(relative_slots["D"], ["TR", "F"]), "relative starter preset puts TR/F in D")
	_require(_array_equals(relative_slots["F"], ["I"]), "starter preset now reserves physical F for the interact token")
	_require(_array_equals(starter_program.get_token_drop_pool(), ["U", "D", "L", "R", "F", "B", "SL", "SR", "DS", "HK", "SB", "HM", "RA", "PI", "TH", "SW", "BW", "CA", "TL", "TR", "A", "I", "G", "W", "J"]), "token drop pool includes all current program tokens")
	_require(starter_program.is_program_token("F"), "F is a legal program token")
	_require(starter_program.is_program_token("I"), "I is a legal program token")
	_require(starter_program.is_program_token("CA"), "CA is a legal program token")
	_require(starter_program.is_program_token("DS"), "DS is a legal program token")
	_require(starter_program.is_program_token("HK"), "HK is a legal program token")
	_require(starter_program.is_program_token("SB"), "SB is a legal program token")
	_require(starter_program.is_program_token("HM"), "HM is a legal program token")
	_require(starter_program.is_program_token("RA"), "RA is a legal program token")
	_require(starter_program.is_program_token("PI"), "PI is a legal program token")
	_require(starter_program.is_program_token("TH"), "TH is a legal program token")
	_require(starter_program.is_program_token("SW"), "SW is a legal program token")
	_require(starter_program.is_program_token("BW"), "BW is a legal program token")
	_require(starter_program.is_program_token("TL"), "TL is a legal program token")
	_require(starter_program.is_program_token("TR"), "TR is a legal program token")
	_require(_array_equals(game._build_key_slot_plan(relative_slots["A"]).map(func(action): return action.def.id), ["turn_left", "move_forward"]), "relative starter A slot builds turn_left + move_forward")
	_require(_array_equals(game._build_key_slot_plan(relative_slots["D"]).map(func(action): return action.def.id), ["turn_right", "move_forward"]), "relative starter D slot builds turn_right + move_forward")
	_require(_array_equals(game._build_key_slot_plan(relative_slots["S"]).map(func(action): return action.def.id), ["turn_right", "turn_right", "move_forward"]), "relative starter S slot builds turn_right + turn_right + move_forward")

	game.start_seeded_run("absolute")
	await process_frame
	_require(game.state.map_node_kind == "rest", "run starts at camp")
	_require(game._key_program_editable, "camp unlocks key slot editing")
	_require(game.state.is_safe_training, "camp is a safe training sandbox")
	var starter_slots: Dictionary = game.get_key_program_slots()
	_require(_array_equals(starter_slots["W"], ["U"]), "W key starts with up token")
	_require(_array_equals(starter_slots["S"], ["D"]), "S key starts with down token")
	_require(_array_equals(starter_slots["A"], ["L"]), "A key starts with left token")
	_require(_array_equals(starter_slots["D"], ["R"]), "D key starts with right token")
	game.start_seeded_run("relative")
	await process_frame
	_require(game.state.map_node_kind == "rest", "relative seeded run also starts at camp")
	var relative_starter_slots: Dictionary = game.get_key_program_slots()
	_require(_array_equals(relative_starter_slots["W"], ["F"]), "relative seeded run puts F in W")
	_require(_array_equals(relative_starter_slots["S"], ["TR", "TR", "F"]), "relative seeded run puts TR/TR/F in S")
	_require(_array_equals(relative_starter_slots["A"], ["TL", "F"]), "relative seeded run puts TL/F in A")
	_require(_array_equals(relative_starter_slots["D"], ["TR", "F"]), "relative seeded run puts TR/F in D")
	_require(_array_equals(relative_starter_slots["F"], ["I"]), "relative seeded run reserves physical F for interact by default")
	game.start_seeded_run("absolute")
	await process_frame
	_require(game.state.map_node_kind == "rest", "absolute seeded run also starts at camp")
	_require(game._battle_presentation.debug_wait_for_presentation_completion(), "legacy seeded run keeps blocking presentation flow")
	_require(game._battle_presentation.debug_current_timing_profile_name() == "legacy", "legacy seeded run keeps the legacy timing profile")
	var control_plan: Array = game._build_key_slot_plan(["U"])
	_require(control_plan.size() == 1 and control_plan[0].def.id == "move_key", "default up slot stays a pure move action")
	var f_plan: Array = game._build_key_slot_plan(["F"])
	_require(f_plan.size() == 1 and f_plan[0].def.id == "move_forward", "F token maps to move_forward action")
	var interact_plan: Array = game._build_key_slot_plan(["I"])
	_require(interact_plan.size() == 1 and interact_plan[0].def.id == "interact", "I token maps to interact action")
	_require(starter_program.token_display_name("CA") == "十字刃", "CA token display name is unified as 十字刃")
	var cross_plan: Array = game._build_key_slot_plan(["CA"])
	_require(cross_plan.size() == 1 and cross_plan[0].def.id == "cross_attack", "CA token maps to cross_attack action")
	_require(String(cross_plan[0].def.display_name) == "十字刃", "cross_attack display name is unified as 十字刃")
	var dash_plan: Array = game._build_key_slot_plan(["DS"])
	_require(dash_plan.size() == 1 and dash_plan[0].def.id == "dash", "DS token maps to dash action")
	var hook_plan: Array = game._build_key_slot_plan(["HK"])
	_require(hook_plan.size() == 1 and hook_plan[0].def.id == "hook_pull", "HK token maps to hook_pull action")
	var bash_plan: Array = game._build_key_slot_plan(["SB"])
	_require(bash_plan.size() == 1 and bash_plan[0].def.id == "shield_bash", "SB token maps to shield_bash action")
	var hammer_plan: Array = game._build_key_slot_plan(["HM"])
	_require(hammer_plan.size() == 1 and hammer_plan[0].def.id == "hammer_smash", "HM token maps to hammer_smash action")
	var spin_plan: Array = game._build_key_slot_plan(["RA"])
	_require(spin_plan.size() == 1 and spin_plan[0].def.id == "spin_axe", "RA token maps to spin_axe action")
	var pierce_plan: Array = game._build_key_slot_plan(["PI"])
	_require(pierce_plan.size() == 1 and pierce_plan[0].def.id == "pierce_line", "PI token maps to pierce_line action")
	var thrust_plan: Array = game._build_key_slot_plan(["TH"])
	_require(thrust_plan.size() == 1 and thrust_plan[0].def.id == "charge_thrust", "TH token maps to charge_thrust action")
	var sweep_plan: Array = game._build_key_slot_plan(["SW"])
	_require(sweep_plan.size() == 1 and sweep_plan[0].def.id == "great_sweep", "SW token maps to great_sweep action")
	var bow_plan: Array = game._build_key_slot_plan(["BW"])
	_require(bow_plan.size() == 1 and bow_plan[0].def.id == "bow_shot", "BW token maps to bow_shot action")
	var tl_plan: Array = game._build_key_slot_plan(["TL"])
	_require(tl_plan.size() == 1 and tl_plan[0].def.id == "turn_left", "TL token maps to turn_left action")
	var tr_plan: Array = game._build_key_slot_plan(["TR"])
	_require(tr_plan.size() == 1 and tr_plan[0].def.id == "turn_right", "TR token maps to turn_right action")

	game._on_key_token_move_requested("D", 0, "W")
	await process_frame
	_require(game.get_key_program_slots()["D"].is_empty(), "camp editing can empty D key slot")
	_require(_array_equals(game.get_key_program_slots()["W"], ["U", "R"]), "camp editing can chain W slot to up then right")
	_move_player_to(game, Vector2i(3, 3))
	game._submit_key_chain("D")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(3, 3), "empty D key slot has no mapped movement in camp")
	game._submit_key_chain("W")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(4, 2), "camp sandbox can test chained W-slot up then right movement")
	_require(_string_name_array_equals(game.get_player_action_trace_symbols(2), [&"SL", &"SR"]), "absolute input chain is recorded as relative action trace symbols")
	_require(game.get_player_action_trace_debug_string(2) == "SL -> SR", "player trace debug string reports recent relative symbols")

	var input_service = root.get_node_or_null("/root/PlayerInputService")
	_require(input_service != null, "player input service autoload exists")
	_require(input_service.get_key_id_for_action(PlayerInputService.ACTION_W) == "W", "keyboard W action maps to W key slot")
	_require(input_service.get_action_for_key_id("D") == PlayerInputService.ACTION_D, "D key slot maps back to keyboard action")

	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.map_node_kind == "combat", "camp continues to first combat")
	_require(not game._key_program_editable, "combat locks key slot editing")
	game._on_key_token_move_requested("W", 1, "D")
	await process_frame
	_require(game.get_key_program_slots()["D"].is_empty(), "combat keeps D key slot unchanged")
	_require(_array_equals(game.get_key_program_slots()["W"], ["U", "R"]), "combat keeps W key slot unchanged")

	game.start_seeded_run("absolute")
	await process_frame
	game._start_map_node(4)
	await process_frame
	_require(game.state.map_node_kind == "rest", "route has a rest node")
	_require(game._key_program_editable, "rest node unlocks key slot editing")

	game._on_key_token_move_requested("D", 0, "W")
	await process_frame
	_require(game.get_key_program_slots()["D"].is_empty(), "rest editing can empty D key slot")
	_require(_array_equals(game.get_key_program_slots()["W"], ["U", "R"]), "rest editing can chain W slot to up then right")

	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.map_node_kind == "boss", "rest continues to boss node")
	_require(not game._key_program_editable, "boss node locks key slot editing")

	_disable_enemies(game)
	_move_player_to(game, Vector2i(3, 2))
	game._submit_key_chain("D")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(3, 2), "empty D key slot has no mapped movement")

	game._submit_key_chain("W")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(4, 1), "pressing W key executes chained up then right movement")
	_require(_string_name_array_equals(game.get_player_action_trace_symbols(2), [&"SL", &"SR"]), "combat key-program execution records recent relative trace symbols")

	await _start_seeded_combat_run(game, "action-trace-turn")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	var trace_plan: Array = [_make_player_action(game, "turn_left"), _make_player_action(game, "move_forward")]
	game.turn_controller.submit_player_plan(trace_plan)
	await process_frame
	_require(_string_name_array_equals(game.get_player_action_trace_symbols(2), [&"TL", &"F"]), "turn then move records relative turn and forward trace symbols")
	_require(game.state.player.grid_pos == Vector2i(2, 1), "turn then move uses updated facing for forward movement")

	await _start_seeded_combat_run(game, "trace-semantics")
	var trace_semantic_game = game
	_move_player_to(trace_semantic_game, Vector2i(2, 2))
	trace_semantic_game.state.player.facing = Vector2i.UP
	var absolute_trace_plan: Array = trace_semantic_game._build_key_slot_plan(["R"])
	trace_semantic_game.turn_controller.submit_player_plan(absolute_trace_plan)
	await process_frame
	_require(_string_name_array_equals(trace_semantic_game.get_player_action_trace_symbols(1), [&"SR"]), "absolute move records move semantic, not explicit turn semantic")
	_require(not trace_semantic_game.get_player_action_trace_debug_string(1).contains("TL"), "absolute move trace is not disguised as TL")
	_require(not trace_semantic_game.get_player_action_trace_debug_string(1).contains("TR"), "absolute move trace is not disguised as TR")
	_require(Vector2i(trace_semantic_game.state.action_trace.get_recent_entries_for_actor(int(trace_semantic_game.state.player.id), 1)[0].move_dir) == Vector2i.RIGHT, "runtime trace move_dir stays normalized to unit direction")

	await _start_seeded_combat_run(game, "side-step-preview")
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.UP
	var side_preview: Dictionary = game._build_key_slot_preview(["SL", "SR"])
	_require(Array(side_preview.get("move_cells", [])).has(Vector2i(1, 2)), "SL preview projects one cell to the actor's left")
	var side_left_plan: Array = game._build_key_slot_plan(["SL"])
	game.turn_controller.submit_player_plan(side_left_plan)
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(1, 2), "SL action moves the player left relative to facing")
	_require(game.state.player.facing == Vector2i.UP, "SL action keeps facing unchanged")

	await _start_seeded_combat_run(game, "dash-action")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	var dash_action_plan: Array = game._build_key_slot_plan(["DS"])
	game.turn_controller.submit_player_plan(dash_action_plan)
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(4, 2), "dash moves two cells forward when unobstructed")

	await _start_seeded_combat_run(game, "hook-pull-action")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	var hooked_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(4, 2))
	hooked_enemy.team = "enemy"
	hooked_enemy.max_hp = 5
	hooked_enemy.hp = 5
	var hook_action_plan: Array = game._build_key_slot_plan(["HK"])
	game.turn_controller.submit_player_plan(hook_action_plan)
	await process_frame
	_require(hooked_enemy.hp == 3, "hook pull deals normal attack damage to the first target in line")
	_require(hooked_enemy.grid_pos == Vector2i(3, 2), "hook pull drags the target one cell closer")

	await _start_seeded_combat_run(game, "shield-bash-action")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	var bashed_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 2))
	bashed_enemy.team = "enemy"
	bashed_enemy.max_hp = 5
	bashed_enemy.hp = 5
	var bash_action_plan: Array = game._build_key_slot_plan(["SB"])
	game.turn_controller.submit_player_plan(bash_action_plan)
	await process_frame
	_require(bashed_enemy.hp == 3, "shield bash deals normal melee damage")
	_require(bashed_enemy.grid_pos == Vector2i(4, 2), "shield bash knocks the target back by one cell")

	await _start_seeded_combat_run(game, "hammer-smash-preview-and-hit")
	_disable_enemies(game)
	game.state.grid.blocked_cells.clear()
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	var hammer_preview: Dictionary = game._build_key_slot_preview(["HM"])
	_require(
		_vector2i_set_equals(
			Array(hammer_preview.get("attack_cells", [])),
			[Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3)]
		),
		"hammer smash preview covers the forward 2x3 area"
	)
	var hammer_enemy_a = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 1))
	hammer_enemy_a.team = "enemy"
	hammer_enemy_a.hp = 5
	var hammer_enemy_b = game._add_actor(game.state, SLIME_DEF, Vector2i(4, 3))
	hammer_enemy_b.team = "enemy"
	hammer_enemy_b.hp = 5
	var hammer_action_plan: Array = game._build_key_slot_plan(["HM"])
	game.turn_controller.submit_player_plan(hammer_action_plan)
	await process_frame
	_require(hammer_enemy_a.hp == 3 and hammer_enemy_b.hp == 3, "hammer smash damages multiple enemies inside the 2x3 area")

	await _start_seeded_combat_run(game, "spin-axe-preview-and-hit")
	_disable_enemies(game)
	game.state.grid.blocked_cells.clear()
	_move_player_to(game, Vector2i(3, 3))
	game.state.player.facing = Vector2i.RIGHT
	var spin_preview: Dictionary = game._build_key_slot_preview(["RA"])
	_require(
		_vector2i_set_equals(
			Array(spin_preview.get("attack_cells", [])),
			[Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(4, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]
		),
		"spin axe preview covers the surrounding 3x3 ring"
	)
	var spin_enemy_a = game._add_actor(game.state, SLIME_DEF, Vector2i(2, 3))
	spin_enemy_a.team = "enemy"
	spin_enemy_a.hp = 5
	var spin_enemy_b = game._add_actor(game.state, SLIME_DEF, Vector2i(4, 4))
	spin_enemy_b.team = "enemy"
	spin_enemy_b.hp = 5
	var spin_action_plan: Array = game._build_key_slot_plan(["RA"])
	game.turn_controller.submit_player_plan(spin_action_plan)
	await process_frame
	_require(spin_enemy_a.hp == 3 and spin_enemy_b.hp == 3, "spin axe damages enemies around the player")

	await _start_seeded_combat_run(game, "pierce-line-preview-and-hit")
	_disable_enemies(game)
	game.state.grid.blocked_cells.clear()
	_move_player_to(game, Vector2i(1, 3))
	game.state.player.facing = Vector2i.RIGHT
	var pierce_preview: Dictionary = game._build_key_slot_preview(["PI"])
	_require(
		_vector2i_set_equals(
			Array(pierce_preview.get("attack_cells", [])),
			[Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
		),
		"pierce line preview covers four cells straight ahead"
	)
	var pierce_enemy_a = game._add_actor(game.state, SLIME_DEF, Vector2i(2, 3))
	pierce_enemy_a.team = "enemy"
	pierce_enemy_a.hp = 5
	var pierce_enemy_b = game._add_actor(game.state, SLIME_DEF, Vector2i(5, 3))
	pierce_enemy_b.team = "enemy"
	pierce_enemy_b.hp = 5
	var pierce_action_plan: Array = game._build_key_slot_plan(["PI"])
	game.turn_controller.submit_player_plan(pierce_action_plan)
	await process_frame
	_require(pierce_enemy_a.hp == 3 and pierce_enemy_b.hp == 3, "pierce line damages enemies along the full 1x4 line")

	var attack_dir_game = GameScene.instantiate()
	root.add_child(attack_dir_game)
	await process_frame
	attack_dir_game.start_seeded_run("attack-direction")
	await process_frame
	_enter_first_combat_from_camp(attack_dir_game)
	await process_frame
	attack_dir_game.enemy_planner.enemies_are_static = true
	attack_dir_game.state.grid.blocked_cells.clear()
	_prepare_single_enemy_room(attack_dir_game, Vector2i(3, 2), 10, Vector2i(2, 2))
	_move_player_to(attack_dir_game, Vector2i(2, 2))
	attack_dir_game.state.player.facing = Vector2i.UP
	var attack_dir_action = attack_dir_game._build_key_slot_plan(["A"])[0]
	attack_dir_action.chosen_dir = Vector2i.RIGHT
	var right_enemy = attack_dir_game.state.grid.get_actor(Vector2i(3, 2))
	var right_enemy_hp_before: int = right_enemy.hp
	attack_dir_game.resolver.resolve(attack_dir_action, attack_dir_game.state)
	_require(attack_dir_game.state.player.facing == Vector2i.RIGHT, "attack action updates facing to chosen_dir when present")
	_require(right_enemy.hp < right_enemy_hp_before, "A token uses the concrete attack action instead of current facing")

	var bow_game = GameScene.instantiate()
	root.add_child(bow_game)
	await process_frame
	bow_game.start_seeded_run("bow-shot")
	await process_frame
	_enter_first_combat_from_camp(bow_game)
	await process_frame
	bow_game.enemy_planner.enemies_are_static = true
	_disable_enemies(bow_game)
	_move_player_to(bow_game, Vector2i(2, 2))
	bow_game.state.player.facing = Vector2i.RIGHT
	var near_enemy = bow_game._add_actor(bow_game.state, SLIME_DEF, Vector2i(3, 2))
	near_enemy.team = "enemy"
	near_enemy.max_hp = 5
	near_enemy.hp = 5
	var far_enemy = bow_game._add_actor(bow_game.state, SLIME_DEF, Vector2i(5, 2))
	far_enemy.team = "enemy"
	far_enemy.max_hp = 5
	far_enemy.hp = 5
	var bow_preview: Dictionary = bow_game._build_key_slot_preview(["BW"])
	_require(_vector2i_array_equals(Array(bow_preview.get("attack_cells", [])), [Vector2i(3, 2)]), "bow preview locks onto the nearest enemy cell in front")
	var bow_action = bow_game._build_key_slot_plan(["BW"])[0]
	bow_game.resolver.resolve(bow_action, bow_game.state)
	_require(near_enemy.hp == 3, "bow shot hits the nearest enemy in front")
	_require(far_enemy.hp == 5, "bow shot does not pierce through to farther enemies")

	await _start_seeded_combat_run(game, "line-warden-ai")
	_disable_enemies(game)
	var line_enemy = game._add_actor(game.state, LINE_WARDEN_DEF, Vector2i(2, 4))
	line_enemy.team = "enemy"
	_move_player_to(game, Vector2i(2, 1))
	var line_action = game.enemy_planner.decide_enemy_action(line_enemy, game.state)
	_require(line_action != null and line_action.def != null and line_action.def.id == "move_forward", "line keeper advances along the player's line when out of range")
	_require(line_action.chosen_dir == Vector2i.UP, "line keeper moves straight along the same column toward the player")

	game.start_seeded_run("absolute")
	await process_frame
	_require(game.state.map_node_kind == "rest", "mixed-drop test starts from camp")
	_require(game._key_program_editable, "mixed-drop test keeps rest editing enabled")
	_require(_array_equals(game.get_token_drop_pool(), ["U", "D", "L", "R", "F", "B", "SL", "SR", "DS", "HK", "SB", "HM", "RA", "PI", "TH", "SW", "BW", "CA", "TL", "TR", "A", "I", "G", "W", "J"]), "game exposes the full token drop pool")
	_require(not game.get_key_program_pool_tokens().has("lunge"), "lunge is not a key program pool token")
	_require(not game.get_key_program_pool_tokens().has("sweep"), "sweep is not a key program pool token")
	game.state.drop_key_at(Vector2i(2, 2), "F")
	var dropped_f: String = game.state.pickup_key_at(Vector2i(2, 2))
	_require(dropped_f == "F", "F can be picked up from a dropped key")
	game._on_key_picked(game.state.player, dropped_f, Vector2i(2, 2))
	game.state.drop_key_at(Vector2i(2, 3), "TL")
	var dropped_tl: String = game.state.pickup_key_at(Vector2i(2, 3))
	_require(dropped_tl == "TL", "TL can be picked up from a dropped key")
	game._on_key_picked(game.state.player, dropped_tl, Vector2i(2, 3))
	game.state.drop_key_at(Vector2i(2, 4), "TR")
	var dropped_tr: String = game.state.pickup_key_at(Vector2i(2, 4))
	_require(dropped_tr == "TR", "TR can be picked up from a dropped key")
	game._on_key_picked(game.state.player, dropped_tr, Vector2i(2, 4))
	_require(game.get_key_program_pool_tokens().has("F") and game.get_key_program_pool_tokens().has("TL") and game.get_key_program_pool_tokens().has("TR"), "mixed tokens enter the spare-token pool")
	game._on_key_token_move_requested("W", 0, "POOL")
	_require(game.get_key_program_slots()["W"].is_empty(), "starter token can be moved out to make room for pooled tokens")
	_move_pool_token_to_slot(game, "F", "W")
	_move_pool_token_to_slot(game, "TL", "W")
	_move_pool_token_to_slot(game, "TR", "W")
	_require(_array_equals(game.get_key_program_slots()["W"], ["F", "TL", "TR"]), "pooled F/TL/TR tokens can be dragged into one physical slot")
	var mixed_plan: Array = game._build_key_slot_plan(game.get_key_program_slots()["W"])
	_require(mixed_plan.size() == 3 and mixed_plan[0].def.id == "move_forward" and mixed_plan[1].def.id == "turn_left" and mixed_plan[2].def.id == "turn_right", "mixed F/TL/TR slot builds the expected action plan")

	var world_game = GameScene.instantiate()
	root.add_child(world_game)
	await process_frame
	world_game.start_world_slice_debug()
	await process_frame
	_require(FileAccess.file_exists("res://art/tiles/board/plain.png"), "board tile asset plain.png exists")
	_require(FileAccess.file_exists("res://art/tiles/board/building_floor.png"), "board tile asset building_floor.png exists")
	_require(FileAccess.file_exists("res://art/tiles/board/tavern_floor.png"), "board tile asset tavern_floor.png exists")
	_require(FileAccess.file_exists("res://art/tiles/board/tavern_door.png"), "board tile asset tavern_door.png exists")
	_require(world_game.board_view._load_tile_texture_asset("plain") != null, "board view can load real plain tile asset")
	_require(world_game.board_view._load_tile_texture_asset("building_floor") != null, "board view can load real building floor tile asset")
	var visible_plain_texture = world_game.board_view.debug_get_tile_texture_variant("plain", 0.0)
	var explored_plain_texture = world_game.board_view.debug_get_tile_texture_variant("plain", 0.52)
	_require(visible_plain_texture != null and explored_plain_texture != null, "board view can build visible and explored tile variants")
	_require(visible_plain_texture != explored_plain_texture, "explored fog uses a darkened tile variant instead of reusing the visible texture")
	_require(world_game.state.map_node_kind == "world_slice", "world slice entry creates the world slice state")
	_require(not world_game._battle_presentation.debug_wait_for_presentation_completion(), "world slice defaults to non-blocking layered presentation")
	_require(world_game._battle_presentation.debug_current_timing_profile_name() == "world_slice_fast", "world slice defaults to the fast timing profile")
	_require(world_game.state.grid.width >= 256 and world_game.state.grid.height >= 256, "world slice defaults to a 256x256 grid")
	_require(world_game.state.map_data != null, "world slice creates map data")
	_require(world_game.state.player != null, "world slice creates a player")
	_require(world_game.state.get_alive_enemies().size() >= 4, "world slice creates at least the initial test enemies")
	_require(world_game.state.world_enemy_stream_target >= 4, "world slice exposes a streamed enemy target count")
	_require(world_game.state.player.grid_pos == world_game.state.map_data.player_spawn, "world slice uses the generated player spawn")
	_require(world_game.state.grid.get_actor(world_game.state.player.grid_pos) == world_game.state.player, "world slice places the player at the generated spawn")
	for safe_zone_enemy in world_game.state.get_alive_enemies():
		_require(not _is_world_slice_rest_area_cell(world_game.state.map_data, safe_zone_enemy.grid_pos), "world slice initial enemies do not spawn inside the tavern safe area")
	var world_spawn_cell = world_game.state.map_data.get_cell(world_game.state.map_data.player_spawn)
	_require(world_spawn_cell != null, "world slice spawn cell exists in map data")
	_require(
		world_spawn_cell.tags.has("building_floor") or world_spawn_cell.tags.has("building_door") or world_spawn_cell.tags.has("building_open_ground"),
		"world slice spawn now lands inside or at the entrance of the tavern footprint"
	)
	_require(world_spawn_cell.tags.has("poi:tavern"), "world slice spawn cell belongs to the tavern footprint")
	_require(world_game._key_program_editable, "world slice starts with key editing enabled inside the tavern rest area")
	var tavern_interactable_cell: Vector2i = _find_world_slice_tavern_interactable_cell(world_game.state.map_data)
	_require(tavern_interactable_cell != Vector2i(-1, -1), "world slice tavern footprint includes a reachable interactable tavern cell")
	_require(_is_world_slice_rest_area_cell(world_game.state.map_data, tavern_interactable_cell), "tavern interactable cell also counts as editable rest area")
	_require(String(world_game.state.messages[0]).contains("酒馆休息区"), "world slice start announces tavern rest-area editing")
	_require(_count_world_slice_props(world_game.state) >= 1, "world slice places at least one world prop")
	var world_npcs: Array = world_game.get_world_slice_npcs()
	_require(world_npcs.size() == 1, "world slice spawns exactly one tavern host NPC near the world spawn")
	for npc in world_npcs:
		_require(npc.tags.has("safe_zone_npc"), "world slice NPCs are tagged as safe-zone residents")
		_require(_is_world_slice_rest_area_cell(world_game.state.map_data, npc.grid_pos), "world slice keeps NPCs inside the tavern safe area")
	var tavern_keeper = _find_world_slice_npc(world_game, "tavern_keeper")
	_require(tavern_keeper != null, "world slice includes the tavern keeper NPC")
	_require(bool(tavern_keeper.def.get("interaction_enabled")), "world slice tavern NPC now uses the shared actor interaction capability")
	var tavern_record: Dictionary = _find_world_slice_poi_record(world_game.state.map_data, "tavern")
	_require(not tavern_record.is_empty(), "world slice exposes the tavern poi record")
	_require(not Array(tavern_record.get("entrance_cells", [])).has(tavern_keeper.grid_pos), "world slice NPC does not spawn directly on a tavern entrance cell")
	_require(not _is_adjacent_to_any_cell(tavern_keeper.grid_pos, Array(tavern_record.get("entrance_cells", []))), "world slice NPC does not block the immediate doorway corridor")
	_require(absi(tavern_keeper.grid_pos.x - world_game.state.player.grid_pos.x) + absi(tavern_keeper.grid_pos.y - world_game.state.player.grid_pos.y) == 1, "world slice tavern actor now uses the fixed adjacent starter cell")
	_require(Vector2i(world_game.state.world_actor_positions.get("tavern_keeper", Vector2i(-1, -1))) == tavern_keeper.grid_pos, "world slice also records tracked actor coordinates under actor naming")
	_require(Vector2i(world_game.state.world_npc_positions.get("tavern_keeper", Vector2i(-1, -1))) == tavern_keeper.grid_pos, "world slice records tavern NPC coordinates in runtime state")
	_require(String(world_game.state.tracked_world_actor_id) == "tavern_keeper", "world slice tracks the tavern keeper by default under actor naming")
	_require(String(world_game.state.tracked_world_npc_id) == "tavern_keeper", "world slice tracks the tavern keeper by default")
	_require(absi(tavern_keeper.grid_pos.x - world_game.state.player.grid_pos.x) + absi(tavern_keeper.grid_pos.y - world_game.state.player.grid_pos.y) == 1, "world slice fixes the tavern keeper adjacent to the player spawn")
	_require(world_game.state.player.facing == tavern_keeper.grid_pos - world_game.state.player.grid_pos, "world slice starts the player facing the tavern keeper for immediate interaction")
	_require(bool(world_game.state.show_tracked_world_actor_hint), "world slice enables tracked actor hint display by default")
	_require(bool(world_game.state.show_tracked_world_npc_hint), "world slice enables tracked NPC hint display by default")
	_require(not String(world_game.state.tracked_world_actor_relative_hint).is_empty(), "world slice computes a relative direction hint to the tracked actor")
	_require(not String(world_game.state.tracked_world_npc_relative_hint).is_empty(), "world slice computes a relative direction hint to the tracked NPC")
	var tavern_keeper_talk_cell: Vector2i = _find_walkable_adjacent_world_cell(world_game.state, tavern_keeper.grid_pos)
	_require(tavern_keeper_talk_cell != Vector2i(-1, -1), "tavern keeper has a reachable adjacent interaction cell")
	var previous_npc_test_cell: Vector2i = world_game.state.player.grid_pos
	_move_player_to(world_game, tavern_keeper_talk_cell)
	if world_game._world_slice_controller != null:
		world_game._world_slice_controller.on_player_moved(world_game.state, previous_npc_test_cell, tavern_keeper_talk_cell)
	world_game._refresh_views()
	await process_frame
	_require(String(world_game.state.tracked_world_npc_relative_hint) == "西（1 格）" or String(world_game.state.tracked_world_npc_relative_hint) == "东（1 格）" or String(world_game.state.tracked_world_npc_relative_hint) == "北（1 格）" or String(world_game.state.tracked_world_npc_relative_hint) == "南（1 格）", "world slice updates tracked NPC direction after the player moves next to the target")
	world_game.state.player.facing = -(tavern_keeper.grid_pos - world_game.state.player.grid_pos)
	var message_count_before_wrong_facing: int = world_game.state.messages.size()
	_require(world_game._submit_world_interact_action(), "interact action still resolves input when facing the wrong direction")
	_require(not world_game._world_npc_dialogue_active, "interact action does not open dialogue when the target is adjacent but not in front of the player")
	_require(not world_game.battle_ui.is_world_npc_dialogue_visible(), "wrong-facing interact does not show the dialogue panel")
	_require(world_game.state.messages.size() >= message_count_before_wrong_facing, "wrong-facing interact can still report that nothing in front responded")
	world_game.state.player.facing = tavern_keeper.grid_pos - world_game.state.player.grid_pos
	_require(_array_equals(world_game.get_key_program_slots()["F"], ["I"]), "world slice starts with the interact token on the physical F slot")
	var npc_turn_count_before_interact: int = int(world_game.state.turn_count)
	_require(world_game._submit_world_interact_action(), "world slice can submit a dedicated interact action near a tavern NPC")
	await process_frame
	_require(world_game.state.turn_count == npc_turn_count_before_interact, "world slice interact action does not consume a combat turn or trigger enemy follow-up")
	_require(world_game._world_npc_dialogue_active, "world slice NPC interaction opens a dedicated dialogue state")
	_require(world_game.battle_ui.is_world_npc_dialogue_visible(), "world slice NPC interaction shows a bottom dialogue panel")
	_require(world_game.battle_ui.get_node("NpcDialoguePanel/Margin/Content/NpcDialogueTitle").text == "酒馆掌柜", "world slice dialogue panel shows the NPC speaker name")
	_require(world_game.battle_ui.get_node("NpcDialoguePanel/Margin/Content/NpcDialogueBody").text.contains("备用行动池"), "tavern keeper first dialogue now teaches that the attack token goes into the spare pool")
	_require(String(world_game.state.messages[0]).contains("酒馆掌柜"), "world slice NPC interaction adds tavern dialogue to the message log")
	_require(world_game.get_key_program_pool_tokens().has("A"), "tavern keeper first dialogue adds the attack token into the spare pool")
	_require(int(world_game._world_npc_interaction_counts.get("tavern_keeper", 0)) == 1, "tavern keeper first dialogue is tracked for one-time rewards")
	var world_save_data: Dictionary = world_game.get_save_data()
	_require(int(Dictionary(world_save_data.get("world_npc_interaction_counts", {})).get("tavern_keeper", 0)) == 1, "world npc interaction counts are included in run save data")
	var interaction_message_before_f: String = String(world_game.state.messages[0])
	var npc_turn_count_before_block: int = int(world_game.state.turn_count)
	var npc_pos_before_block: Vector2i = world_game.state.player.grid_pos
	world_game._submit_key_chain("W")
	await process_frame
	_require(world_game.state.turn_count == npc_turn_count_before_block, "world slice dialogue freezes turn submission until the interaction ends")
	_require(world_game.state.player.grid_pos == npc_pos_before_block, "world slice dialogue blocks movement while the interaction panel is open")
	var message_before_close: String = String(world_game.state.messages[0])
	var f_interaction_event := InputEventKey.new()
	f_interaction_event.keycode = KEY_F
	f_interaction_event.pressed = true
	world_game._unhandled_input(f_interaction_event)
	await process_frame
	_require(not world_game._world_npc_dialogue_active, "pressing any key while the dialogue is visible now closes the interaction immediately")
	_require(not world_game.battle_ui.is_world_npc_dialogue_visible(), "pressing any key hides the dialogue panel immediately")
	_require(String(world_game.state.messages[0]) == message_before_close, "closing the dialogue does not cycle to a second line")
	_require(world_game.state.turn_count == npc_turn_count_before_block, "closing the dialogue with a key still does not consume a turn")
	_require(not world_game._world_npc_dialogue_active, "world slice dialogue can be closed explicitly")
	_require(not world_game.battle_ui.is_world_npc_dialogue_visible(), "closing the dialogue hides the bottom dialogue panel")
	_require(world_game.state.map_data.get_poi_records().size() >= 5, "world slice generates footprint-based poi records")
	_require(_world_slice_has_poi_type(world_game.state.map_data, "tavern"), "world slice generates a tavern footprint")
	_require(_world_slice_has_poi_type(world_game.state.map_data, "challenge_entrance"), "world slice generates a challenge footprint")
	_require(_world_slice_has_poi_type(world_game.state.map_data, "ruin"), "world slice generates a ruin footprint")
	_require(_world_slice_has_poi_type(world_game.state.map_data, "chest"), "world slice generates a chest footprint")
	_require(_world_slice_has_poi_type(world_game.state.map_data, "easter_egg"), "world slice generates an egg footprint")
	_require(_world_slice_has_poi_type(world_game.state.map_data, "shrine"), "world slice generates a shrine footprint")
	_require(_world_slice_building_footprints_are_valid(world_game.state.map_data), "world slice building records keep valid footprint metadata")
	_require(world_game.state.map_data.reachable_count > 0, "world slice tracks reachable walkable cells")
	_require(world_game.state.map_data.unreachable_poi_count == 0, "world slice connectivity keeps POIs reachable")
	_require(world_game.state.map_data.reachable_count == world_game.state.map_data.get_walkable_cells().size(), "world slice stitches walkable terrain into one reachable region")
	_require(_mountain_passes_use_cardinal_connections(world_game.state.map_data), "world slice carved passes stay cardinal instead of diagonal-only")
	var world_terrain_counts: Dictionary = world_game.state.map_data.get_terrain_counts()
	_require(int(world_terrain_counts.get("hill", 0)) > 0, "world slice generates hills")
	_require(int(world_terrain_counts.get("mountain", 0)) > 0, "world slice generates mountains")
	_require(int(world_terrain_counts.get("peak", 0)) > 0, "world slice generates peaks")
	_require(_array_equals(world_game.get_key_program_slots()["W"], ["U"]), "world slice reuses the current key program")
	_require(world_game.state.visible_cells.size() > 0, "world slice computes initial visible cells")
	_require(world_game.state.explored_cells.size() >= world_game.state.visible_cells.size(), "world slice explored cells include current visible cells")
	_require(world_game.state.visible_cells.has(world_game.state.player.grid_pos), "world slice reveals the player cell")
	var far_world_cell: Vector2i = _pick_far_world_cell(world_game.state.map_data, world_game.state.player.grid_pos, int(world_game.state.fov_radius) + 2)
	if far_world_cell != Vector2i(-1, -1):
		_require(not world_game.state.visible_cells.has(far_world_cell), "world slice hides cells outside the FOV radius")
	_require(world_game.state.explored_cells.has(world_game.state.player.grid_pos), "world slice explored keeps the player cell")
	var visible_enemy_count: int = _count_visible_world_slice_enemies(world_game.state)
	_require(world_game.state.enemy_intents.size() == visible_enemy_count, "world slice only previews intents for visible enemies")
	var autopath_blocker = null
	if visible_enemy_count == 0:
		var blocker_cell := Vector2i(-1, -1)
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var candidate: Vector2i = world_game.state.player.grid_pos + dir
			if not world_game.state.map_data.is_walkable(candidate):
				continue
			if world_game.state.grid.get_actor(candidate) != null:
				continue
			blocker_cell = candidate
			break
		_require(blocker_cell != Vector2i(-1, -1), "world slice can place a temporary visible enemy next to the player for autopath guard coverage")
		autopath_blocker = world_game._add_actor(world_game.state, SLIME_DEF, blocker_cell)
		world_game._refresh_world_visibility("test_visible_enemy_for_autopath")
		world_game._refresh_views()
		await process_frame
	_require(_count_visible_world_slice_enemies(world_game.state) > 0, "world slice has at least one visible enemy before the autopath click test")
	var autopath_turn_before_click: int = int(world_game.state.turn_count)
	var autopath_player_before_click: Vector2i = world_game.state.player.grid_pos
	world_game._on_ruin_poi_requested()
	await process_frame
	_require(not world_game._world_autopath_active, "world slice does not start autopath when an enemy is already visible")
	_require(world_game.state.turn_count == autopath_turn_before_click, "blocked autopath click does not consume a turn")
	_require(world_game.state.player.grid_pos == autopath_player_before_click, "blocked autopath click does not move the player")
	_require(String(world_game.state.messages[0]).contains("视野内已有敌人"), "blocked autopath click explains that visible enemies prevent auto movement")
	if autopath_blocker != null:
		world_game.state.grid.remove_actor(autopath_blocker)
		autopath_blocker.hp = 0
		world_game._refresh_world_visibility("cleanup_autopath_test_enemy")
		world_game._refresh_views()
		await process_frame
	var world_snapshot_before: String = _world_slice_snapshot_key(world_game.state)
	var world_seed_before: String = String(world_game.state.map_data.seed)
	var explored_before_move: int = world_game.state.explored_cells.size()
	var stream_refresh_before: int = world_game.state.world_enemy_stream_refresh_count
	var stream_spawn_total_before: int = world_game.state.world_enemy_stream_spawn_total
	world_game.enemy_planner.enemies_are_static = true
	var world_move: Dictionary = _pick_first_walkable_world_move(world_game.state, world_game.state.player.grid_pos)
	_require(not world_move.is_empty(), "world slice has at least one walkable move from spawn")
	var world_action_plan: Array = world_game._build_key_slot_plan([String(world_move.get("token_id", ""))])
	_require(world_action_plan.size() == 1 and world_action_plan[0].def.id == "move_key", "world slice can generate an action plan from the current key program")
	world_game.state.player.facing = Vector2i(world_move.get("delta", Vector2i.ZERO))
	world_game.turn_controller.submit_player_plan(world_action_plan)
	await process_frame
	_require(world_game.state.player.grid_pos == Vector2i(world_move.get("target", world_game.state.player.grid_pos)), "world slice executes one movement step through the shared battle core")
	_require(
		world_game._key_program_editable == _is_world_slice_rest_area_cell(world_game.state.map_data, world_game.state.player.grid_pos),
		"world slice editability follows whether the player is still standing in the tavern rest area"
	)
	var outside_rest_cell: Vector2i = _find_nearest_world_slice_non_rest_area_cell(world_game.state.map_data, world_game.state.player.grid_pos)
	_require(outside_rest_cell != Vector2i(-1, -1), "world slice exposes a reachable non-rest-area cell")
	var previous_world_cell: Vector2i = world_game.state.player.grid_pos
	_move_player_to(world_game, outside_rest_cell)
	if world_game._world_slice_controller != null:
		world_game._world_slice_controller.on_player_moved(world_game.state, previous_world_cell, outside_rest_cell)
	world_game._refresh_views()
	await process_frame
	_require(not world_game._key_program_editable, "world slice locks key editing after leaving the tavern rest area")
	_require(String(world_game.state.messages[0]).contains("离开酒馆休息区"), "world slice announces when the player leaves the tavern rest area")
	_require(world_game.state.last_visibility_recompute_reason == "player_moved", "world slice recomputes visibility after player movement")
	_require(world_game.state.visible_cells.has(world_game.state.player.grid_pos), "world slice keeps the moved player cell visible")
	_require(world_game.state.explored_cells.size() >= explored_before_move, "world slice explored cells never shrink after moving")
	_require(world_game.state.world_enemy_stream_refresh_count > stream_refresh_before, "world slice refreshes enemy streaming after player movement")
	_require(world_game.state.world_enemy_stream_spawn_total >= stream_spawn_total_before, "world slice tracks cumulative streamed enemy spawns")
	for streamed_enemy in world_game.state.get_alive_enemies():
		_require(not _is_world_slice_rest_area_cell(world_game.state.map_data, streamed_enemy.grid_pos), "world slice streamed enemies also stay out of the tavern safe area")
	_require(not String(world_game.state.tracked_boss_poi_relative_hint).is_empty(), "world slice computes a boss-ruin direction hint")
	_require(not String(world_game.state.tracked_nearest_ruin_relative_hint).is_empty(), "world slice computes a nearest small-ruin direction hint")
	var ruin_record: Dictionary = _find_world_slice_poi_record(world_game.state.map_data, "ruin")
	_require(not ruin_record.is_empty(), "world slice exposes a ruin poi record")
	var ruin_interaction_cell: Vector2i = Vector2i(ruin_record.get("interaction_cell", Vector2i(-1, -1)))
	_require(ruin_interaction_cell != Vector2i(-1, -1), "ruin poi exposes an interaction cell")
	_move_player_to(world_game, ruin_interaction_cell)
	if world_game._world_slice_controller != null:
		world_game._world_slice_controller.on_player_moved(world_game.state, outside_rest_cell, ruin_interaction_cell)
	world_game._refresh_views()
	await process_frame
	_require(world_game.battle_ui.get_node("RunSidebar/PoiHintPanel/Margin/Content/RuinPoiHint").text.contains("附近可调查"), "sidebar upgrades the ruin hint once the player gets close enough to investigate")
	var pool_count_before_ruin: int = world_game.get_key_program_pool_tokens().size()
	_require(world_game._submit_world_interact_action(), "world slice can investigate a ruin via interact action")
	_require(world_game.get_key_program_pool_tokens().has("SL") and world_game.get_key_program_pool_tokens().has("SR"), "ruin investigation adds side-step tokens to the spare pool")
	_require(world_game.get_key_program_pool_tokens().size() >= pool_count_before_ruin + 2, "ruin investigation grows the spare token pool")
	var ruin_message_after_claim: String = String(world_game.state.messages[0])
	_require(ruin_message_after_claim.contains("小遗迹"), "ruin investigation reports a reward message")
	_require(world_game._submit_world_interact_action(), "already-claimed ruin still resolves interact input")
	_require(String(world_game.state.messages[0]).contains("已经调查过"), "revisiting a claimed ruin reports that it was already investigated")
	var world_player_view = world_game._battle_presentation.actor_views.get(int(world_game.state.player.id))
	_require(world_player_view != null, "world slice keeps a player actor view after movement")
	var expected_world_pos: Vector2 = world_game.board_view.grid_to_world(world_game.state.player.grid_pos) + Vector2(world_game.board_view.cell_size * 0.5, world_game.board_view.cell_size * 0.5)
	_require(world_player_view.position.is_equal_approx(expected_world_pos), "world slice actor overlay stays aligned after the board window scrolls")
	world_game._world_slice_controller.set_reveal_all_debug(world_game.state, true, "debug_toggle")
	_require(world_game.state.reveal_all_debug, "world slice reveal-all toggle turns on")
	_require(world_game.state.visible_cells.size() == world_game.state.map_data.get_size().x * world_game.state.map_data.get_size().y, "world slice reveal-all shows the whole map")
	world_game._world_slice_controller.set_reveal_all_debug(world_game.state, false, "debug_toggle")
	_require(not world_game.state.reveal_all_debug, "world slice reveal-all toggle turns off")
	world_game._world_slice_controller.regenerate_same_seed(world_game.state)
	_require(String(world_game.state.map_data.seed) == world_seed_before, "world slice same-seed regeneration keeps the same seed")
	_require(_world_slice_snapshot_key(world_game.state) == world_snapshot_before, "world slice same-seed regeneration reproduces the same layout snapshot")
	_require(world_game.state.visible_cells.size() > 0, "world slice reset recomputes visible cells")
	_require(world_game.state.explored_cells.size() >= world_game.state.visible_cells.size(), "world slice reset keeps explored at least current visible")
	world_game._world_slice_controller.regenerate_new_seed(world_game.state)
	_require(String(world_game.state.map_data.seed) != world_seed_before, "world slice new-seed regeneration changes the seed")
	_require(_world_slice_snapshot_key(world_game.state) != world_snapshot_before, "world slice new-seed regeneration changes the layout snapshot")
	world_game.queue_free()
	await process_frame

	await _start_seeded_combat_run(game, "movement-chain-speed")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	var talkative_slime = game._add_actor(game.state, TALKATIVE_SLIME_DEF, Vector2i(3, 2))
	_require(bool(talkative_slime.def.get("interaction_enabled")), "talkative slime sample enables the shared actor interaction capability")
	var monster_interaction_result: Dictionary = game._actor_interaction_service.interact(game.state, {})
	_require(bool(monster_interaction_result.get("handled", false)), "shared actor interaction service can interact with a monster actor")
	_require(String(monster_interaction_result.get("actor_id", "")) == "talkative_slime", "monster interaction uses the same actor-based interaction payload")
	_require(String(monster_interaction_result.get("title", "")) == "絮语史莱姆", "monster interaction surfaces actor-specific interaction text")
	game.state.grid.remove_actor(talkative_slime)
	talkative_slime.hp = 0
	var repeated_move_plan: Array = game._build_key_slot_plan(["R", "R"])
	game.turn_controller.submit_player_plan(repeated_move_plan)
	await process_frame
	_require(repeated_move_plan[0].chain_speed == 1, "first repeated movement has speed 1")
	_require(repeated_move_plan[1].chain_speed == 2, "second repeated movement has speed 2")
	_require(game.state.player.grid_pos == Vector2i(4, 2), "repeated movement still executes both chained move actions")

	await _start_seeded_combat_run(game, "effect-pipeline")
	var duplicate_damage = DuplicateDamageModifierScript.new()
	var amplify_duplicated = AmplifyTagDamageModifierScript.new()
	game.state.player.effect_modifiers.append(duplicate_damage)
	game.state.player.effect_modifiers.append(amplify_duplicated)
	var pipeline_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 20)
	var pipeline_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(pipeline_plan)
	await process_frame
	_require(duplicate_damage.copied_packets == 1, "effect modifier can duplicate a damage packet")
	_require(amplify_duplicated.amplified_packets == 1, "later effect modifier can read tags from generated packets")
	_require(pipeline_enemy.hp == 14, "effect pipeline composes duplicate and amplify modifiers multiplicatively")

	await _start_seeded_combat_run(game, "effect-pipeline-move")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	var duplicate_move = DuplicateMoveModifierScript.new()
	game.state.player.effect_modifiers.append(duplicate_move)
	var move_pipeline_plan: Array = game._build_key_slot_plan(["R"])
	game.turn_controller.submit_player_plan(move_pipeline_plan)
	await process_frame
	_require(duplicate_move.copied_packets == 1, "effect modifier can duplicate a move packet")
	_require(game.state.player.grid_pos == Vector2i(4, 2), "duplicated move packet moves one extra step")

	await _start_seeded_combat_run(game, "effect-pipeline-knockback")
	var amplify_knockback = AmplifyKnockbackModifierScript.new()
	game.state.player.effect_modifiers.append(amplify_knockback)
	var amplified_enemy = _prepare_single_enemy_room(game, Vector2i(4, 2), 10, Vector2i(2, 2))
	game.resolver.apply_effect_knockback(game.state.player, amplified_enemy, Vector2i.RIGHT, 1, game.state, null, [&"knockback_test"])
	_require(amplify_knockback.amplified_packets == 1, "effect modifier can amplify a knockback packet")
	_require(amplified_enemy.hp == 10, "knockback packet does not imply damage")
	_require(amplified_enemy.grid_pos == Vector2i(6, 2), "amplified knockback packet pushes farther")

	game.start_seeded_run("late-reward")
	await process_frame
	game._on_rest_continue_requested()
	await process_frame
	game._on_battle_finished(true)
	await process_frame
	game._on_reward_chosen(0)
	await process_frame
	game._on_rest_continue_requested()
	await process_frame
	game._on_battle_finished(true)
	await process_frame
	_require(not _reward_list_has_kind(game._current_rewards, "equip_weapon"), "later combat reward pool no longer offers weapon swaps")
	_require(_reward_list_has_kind(game._current_rewards, "add_modifier"), "later combat reward pool can offer permanent modifiers")

	await _start_seeded_combat_run(game, "modifier-reward")
	game._current_rewards = game._build_rewards()
	game._on_reward_chosen(0)
	await process_frame
	_require(game.state.map_node_kind == "rest", "modifier reward advances to post-practice rest")
	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.room_index == 1, "post-practice rest continues after modifier reward")
	_require(game._run_modifier_ids.has("echo_strike"), "modifier reward is tracked in run state")
	_require(_actor_has_modifier(game.state.player, "echo_strike"), "modifier reward is applied to the new room player")
	var reward_save_data: Dictionary = game.get_save_data()
	_require(reward_save_data.get("run_modifier_ids", []).has("echo_strike"), "modifier reward is included in save data")
	var reward_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 20)
	var reward_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(reward_plan)
	await process_frame
	_require(reward_enemy.hp == 17, "formal echo strike modifier reward affects attack damage")

	await _start_seeded_combat_run(game, "effect-event-on-hit")
	var on_hit_bonus = OnHitBonusDamageModifierScript.new()
	game.state.player.effect_modifiers.append(on_hit_bonus)
	var on_hit_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 20)
	var on_hit_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(on_hit_plan)
	await process_frame
	_require(on_hit_bonus.triggered_count == 1, "effect event modifier reacts to attack damage dealt")
	_require(on_hit_enemy.hp == 17, "on-hit event can generate a follow-up damage packet")

	await _start_seeded_combat_run(game, "effect-event-attack-hit-confirmed")
	game.state.player.atk = 1
	game.enemy_planner.enemies_are_static = true
	var confirmed_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 10)
	confirmed_enemy.guarded = true
	var confirmed_event_types: Array[StringName] = []
	var on_confirmed_event = func(event) -> void:
		if event == null:
			return
		confirmed_event_types.append(StringName(event.event_type))
	if not game.resolver.combat_event_emitted.is_connected(on_confirmed_event):
		game.resolver.combat_event_emitted.connect(on_confirmed_event)
	var confirmed_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(confirmed_plan)
	await process_frame
	if game.resolver.combat_event_emitted.is_connected(on_confirmed_event):
		game.resolver.combat_event_emitted.disconnect(on_confirmed_event)
	_require(confirmed_event_types.has(&"attack_hit_confirmed"), "attack hit confirmed event fires even when guard reduces damage to zero")
	_require(not confirmed_event_types.has(&"damage_dealt"), "guarded zero-damage hit does not fake a damage dealt event")

	await _start_seeded_combat_run(game, "effect-packet-teleport")
	game.enemy_planner.enemies_are_static = true
	_move_player_to(game, Vector2i(2, 2))
	var teleport_events: Array[StringName] = []
	var on_teleport_event = func(event) -> void:
		if event != null:
			teleport_events.append(StringName(event.event_type))
	if not game.resolver.combat_event_emitted.is_connected(on_teleport_event):
		game.resolver.combat_event_emitted.connect(on_teleport_event)
	game.resolver.apply_effect_teleport(game.state.player, Vector2i(4, 2), game.state, null, [&"teleport_test"])
	if game.resolver.combat_event_emitted.is_connected(on_teleport_event):
		game.resolver.combat_event_emitted.disconnect(on_teleport_event)
	_require(game.state.player.grid_pos == Vector2i(4, 2), "teleport packet moves the actor to the target cell")
	_require(teleport_events.has(&"teleport_applied"), "teleport packet emits teleport_applied event")

	await _start_seeded_combat_run(game, "effect-packet-pull")
	game.enemy_planner.enemies_are_static = true
	_move_player_to(game, Vector2i(2, 2))
	var pull_enemy = _prepare_single_enemy_room(game, Vector2i(5, 2), 10, Vector2i(2, 2))
	var pull_events: Array[StringName] = []
	var on_pull_event = func(event) -> void:
		if event != null:
			pull_events.append(StringName(event.event_type))
	if not game.resolver.combat_event_emitted.is_connected(on_pull_event):
		game.resolver.combat_event_emitted.connect(on_pull_event)
	game.resolver.apply_effect_pull(game.state.player, pull_enemy, Vector2i.LEFT, 3, game.state, null, [&"pull_test"])
	if game.resolver.combat_event_emitted.is_connected(on_pull_event):
		game.resolver.combat_event_emitted.disconnect(on_pull_event)
	_require(pull_enemy.grid_pos == Vector2i(3, 2), "pull packet stops the target one cell before the source")
	_require(pull_events.has(&"pull_applied"), "pull packet emits pull_applied event")

	await _start_seeded_combat_run(game, "effect-packet-swap")
	game.enemy_planner.enemies_are_static = true
	_move_player_to(game, Vector2i(2, 2))
	var swap_enemy = _prepare_single_enemy_room(game, Vector2i(4, 2), 10, Vector2i(2, 2))
	var swap_events: Array[StringName] = []
	var on_swap_event = func(event) -> void:
		if event != null:
			swap_events.append(StringName(event.event_type))
	if not game.resolver.combat_event_emitted.is_connected(on_swap_event):
		game.resolver.combat_event_emitted.connect(on_swap_event)
	game.resolver.apply_effect_swap(game.state.player, swap_enemy, game.state, null, [&"swap_test"])
	if game.resolver.combat_event_emitted.is_connected(on_swap_event):
		game.resolver.combat_event_emitted.disconnect(on_swap_event)
	_require(game.state.player.grid_pos == Vector2i(4, 2), "swap packet moves source actor into target cell")
	_require(swap_enemy.grid_pos == Vector2i(2, 2), "swap packet moves target actor into source cell")
	_require(swap_events.has(&"swap_applied"), "swap packet emits swap_applied event")

	await _start_seeded_combat_run(game, "effect-event-on-move")
	game.enemy_planner.enemies_are_static = true
	_move_player_to(game, Vector2i(2, 2))
	var on_move_enemy = _prepare_single_enemy_room(game, Vector2i(4, 2), 10)
	_move_player_to(game, Vector2i(2, 2))
	var on_move_zap = OnMoveZapAheadModifierScript.new()
	game.state.player.effect_modifiers.append(on_move_zap)
	var on_move_plan: Array = game._build_key_slot_plan(["R"])
	game.turn_controller.submit_player_plan(on_move_plan)
	await process_frame
	_require(on_move_zap.triggered_count == 1, "effect event modifier reacts to actor moved")
	_require(game.state.player.grid_pos == Vector2i(3, 2), "on-move event keeps normal movement result")
	_require(on_move_enemy.hp == 9, "on-move event can generate a follow-up damage packet")

	await _start_seeded_combat_run(game, "turn-regen")
	game.enemy_planner.enemies_are_static = true
	var regen_enemy = _prepare_single_enemy_room(game, Vector2i(6, 6), 10, Vector2i(1, 1))
	regen_enemy.team = "enemy"
	game.state.player.hp = 5
	game._run_player_hp = 5
	game._run_regen_progress = 0.0
	var regen_turn_before := int(game.state.turn_count)
	game.turn_controller.submit_player_plan([])
	await _wait_for_turn_completion(game, regen_turn_before)
	_require(game.state.player.hp == 5, "first regen half-step does not heal immediately")
	_require(absf(game._run_regen_progress - 0.5) < 0.001, "first combat turn stores 0.5 regen progress")
	regen_turn_before = int(game.state.turn_count)
	game.turn_controller.submit_player_plan([])
	await _wait_for_turn_completion(game, regen_turn_before)
	_require(game.state.player.hp == 6, "second combat turn converts accumulated regen into 1 hp")
	_require(absf(game._run_regen_progress - 0.0) < 0.001, "regen progress resets after spending exactly 1 hp")
	game.state.player.hp = 5
	game._run_player_hp = 5
	game.state.player_level = 2
	game._run_regen_progress = 0.0
	regen_turn_before = int(game.state.turn_count)
	game.turn_controller.submit_player_plan([])
	await _wait_for_turn_completion(game, regen_turn_before)
	_require(absf(game._run_regen_progress - 0.55) < 0.001, "level 2 slightly increases passive regen per turn")

	await _start_seeded_combat_run(game, "modifier-long-draw")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	_require(game._add_run_modifier(game._modifier_for_id("long_draw")), "long draw modifier can be added to the run")
	var long_draw_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 2))
	long_draw_enemy.team = "enemy"
	long_draw_enemy.max_hp = 5
	long_draw_enemy.hp = 5
	var long_draw_action = game._build_key_slot_plan(["BW"])[0]
	game.resolver.resolve(long_draw_action, game.state)
	_require(long_draw_enemy.hp == 2, "long draw increases ranged damage by 50 percent")

	await _start_seeded_combat_run(game, "modifier-keen-edge")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	_require(game._add_run_modifier(game._modifier_for_id("keen_edge")), "keen edge modifier can be added to the run")
	var keen_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 2))
	keen_enemy.team = "enemy"
	keen_enemy.max_hp = 5
	keen_enemy.hp = 5
	var keen_action = game._build_key_slot_plan(["A"])[0]
	game.resolver.resolve(keen_action, game.state)
	_require(keen_enemy.hp == 2, "keen edge increases base attack damage by 50 percent")

	await _start_seeded_combat_run(game, "modifier-phalanx-rush")
	_disable_enemies(game)
	game.state.grid.blocked_cells.clear()
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	_require(game._add_run_modifier(game._modifier_for_id("phalanx_rush")), "phalanx rush modifier can be added to the run")
	var phalanx_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 2))
	phalanx_enemy.team = "enemy"
	phalanx_enemy.max_hp = 5
	phalanx_enemy.hp = 5
	var phalanx_action = game._build_key_slot_plan(["SB"])[0]
	game.resolver.resolve(phalanx_action, game.state)
	_require(phalanx_enemy.hp == 2, "phalanx rush increases shield-bash damage by 50 percent")

	await _start_seeded_combat_run(game, "modifier-blood-drain")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.UP
	game.state.player.hp = 5
	game._run_player_hp = 5
	_require(game._add_run_modifier(game._modifier_for_id("blood_drain")), "blood drain modifier can be added to the run")
	var blood_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(2, 1))
	blood_enemy.team = "enemy"
	blood_enemy.hp = 1
	var blood_attack = _make_player_action(game, "attack")
	game.resolver.resolve(blood_attack, game.state)
	_require(game.state.player.hp == 6, "blood drain heals the player after a kill")

	await _start_seeded_combat_run(game, "modifier-stormstep")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	_require(game._add_run_modifier(game._modifier_for_id("stormstep")), "stormstep modifier can be added to the run")
	var storm_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(4, 2))
	storm_enemy.team = "enemy"
	storm_enemy.max_hp = 5
	storm_enemy.hp = 5
	var storm_plan: Array = game._build_key_slot_plan(["R"])
	game.turn_controller.submit_player_plan(storm_plan)
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(3, 2), "stormstep keeps the original movement result")
	_require(storm_enemy.hp == 4, "stormstep zaps the enemy now standing directly ahead after a move")

	await _start_seeded_combat_run(game, "modifier-battle-trance")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	game.state.player.guarded = false
	_require(game._add_run_modifier(game._modifier_for_id("battle_trance")), "battle trance modifier can be added to the run")
	var trance_enemy = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 2))
	trance_enemy.team = "enemy"
	trance_enemy.max_hp = 5
	trance_enemy.hp = 5
	var trance_action = game._build_key_slot_plan(["A"])[0]
	game.resolver.resolve(trance_action, game.state)
	_require(game.state.player.guarded, "battle trance grants guard after dealing attack damage")

	await _start_seeded_combat_run(game, "xp-and-level-up")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	var xp_enemy_a = game._add_actor(game.state, SLIME_DEF, Vector2i(2, 1))
	xp_enemy_a.team = "enemy"
	xp_enemy_a.hp = 1
	game.state.player.facing = Vector2i.UP
	var xp_attack_a = _make_player_action(game, "attack")
	game.resolver.resolve(xp_attack_a, game.state)
	_require(game.state.player_xp == 1, "killing the first enemy grants 1 xp")
	_require(game.get_key_program_pool_tokens().has("CA"), "first kill now grants the 十字刃 attack action into the pool")
	var xp_enemy_b = game._add_actor(game.state, SLIME_DEF, Vector2i(3, 2))
	xp_enemy_b.team = "enemy"
	xp_enemy_b.hp = 1
	_move_player_to(game, Vector2i(2, 2))
	game.state.player.facing = Vector2i.RIGHT
	var hp_before_level_up: int = game.state.player.hp
	var max_hp_before_level_up: int = game.state.player.max_hp
	var xp_attack_b = _make_player_action(game, "attack")
	game.resolver.resolve(xp_attack_b, game.state)
	_require(game.state.player_xp == 2, "second kill increases xp again")
	_require(game.state.player_level == 2, "reaching the threshold levels the player up")
	_require(game.state.player.max_hp == max_hp_before_level_up + 1, "leveling up increases max hp")
	_require(game.state.player.hp >= hp_before_level_up, "leveling up restores hp immediately")
	_require(game._current_rewards.size() == 3, "level up offers three permanent buff choices")
	_require(String(game._current_rewards[0].get("name", "")).contains("回响刃"), "first level-up reward set starts from the modifier reward pool")
	game._on_reward_chosen(0)
	await process_frame
	_require(game._run_modifier_ids.size() >= 1, "choosing a level-up reward grants a permanent modifier")
	game._run_modifier_ids.clear()
	game._run_modifier_ids.append("echo_strike")
	game._run_modifier_ids.append("echo_step")
	game._run_modifier_ids.append("force_prism")
	var late_level_rewards: Array = game._build_level_up_rewards()
	_require(late_level_rewards.size() == 3, "later level-up reward pool still offers three choices")
	_require(String(late_level_rewards[0].get("name", "")).contains("长弦校准"), "later level-up rewards rotate to newly added permanent buffs")
	_require(String(late_level_rewards[1].get("name", "")).contains("收割回生"), "later level-up rewards include the kill-heal permanent buff")
	_require(String(late_level_rewards[2].get("name", "")).contains("追电步"), "later level-up rewards include the move-zap permanent buff")
	game._run_modifier_ids.clear()
	game._run_modifier_ids.append("echo_strike")
	game._run_modifier_ids.append("echo_step")
	game._run_modifier_ids.append("force_prism")
	game._run_modifier_ids.append("long_draw")
	game._run_modifier_ids.append("blood_drain")
	game._run_modifier_ids.append("stormstep")
	var richer_level_rewards: Array = game._build_level_up_rewards()
	_require(richer_level_rewards.size() == 3, "expanded modifier roster still returns three level-up choices")
	_require(String(richer_level_rewards[0].get("name", "")).contains("锋刃校准"), "expanded level-up pool includes a universal attack-damage buff")
	_require(String(richer_level_rewards[1].get("name", "")).contains("壁垒猛进"), "expanded level-up pool includes a shield-and-hammer build buff")
	_require(String(richer_level_rewards[2].get("name", "")).contains("枪锋专注"), "expanded level-up pool includes a piercing build buff")

	var achievement_service = root.get_node_or_null("/root/AchievementService")
	_require(achievement_service != null, "achievement service autoload exists")
	_require(achievement_service.has_definition("rooms_cleared"), "achievement definitions are registered")
	_require(achievement_service.get_target("rooms_cleared") == 3, "achievement definition exposes target")

	achievement_service.reset_all()
	achievement_service.record_event("room_cleared", {"room_index": 0})
	_require(achievement_service.get_progress("rooms_cleared") == 1, "achievement event advances progress")
	_require(not achievement_service.is_unlocked("rooms_cleared"), "progress achievement waits for target")
	achievement_service.record_event("room_cleared", {"room_index": 1})
	achievement_service.record_event("room_cleared", {"room_index": 2})
	_require(achievement_service.is_unlocked("rooms_cleared"), "progress achievement unlocks at target")
	achievement_service.record_event("run_cleared", {"seed": "achievement-smoke"})
	_require(achievement_service.is_unlocked("first_clear"), "single event achievement unlocks")
	var achievement_save: Dictionary = achievement_service.get_save_data()
	_require(achievement_save.get("unlocked", {}).has("first_clear"), "achievement save stores unlocked achievements")
	_require(int(achievement_save.get("progress", {}).get("rooms_cleared", 0)) >= 3, "achievement save stores progress")
	achievement_service.reset_all()
	_require(not achievement_service.is_unlocked("first_clear"), "achievement reset clears unlocked state")
	achievement_service.load_save_data(achievement_save)
	_require(achievement_service.is_unlocked("first_clear"), "achievement load restores unlocked state")

	achievement_service.reset_all()
	await _start_seeded_combat_run(game, "achievement-modifier-event")
	game._current_rewards = game._build_rewards()
	game._on_reward_chosen(1)
	await process_frame
	_require(achievement_service.is_unlocked("first_modifier"), "modifier reward triggers achievement event")

	achievement_service.reset_all()
	await _start_seeded_combat_run(game, "achievement-action-event")
	game._current_rewards = game._build_rewards()
	game._on_reward_chosen(0)
	await process_frame
	_require(not achievement_service.is_unlocked("first_action_reward"), "reward no longer tracks a weapon-technique unlock event")

	achievement_service.reset_all()
	await _start_seeded_combat_run(game, "achievement-key-event")
	game._on_key_picked(game.state.player, "R", Vector2i(1, 2))
	await process_frame
	_require(achievement_service.is_unlocked("first_key"), "key pickup triggers achievement event")

	print("SmokeTest passed")
	quit(0)

func _require(condition: bool, label: String) -> void:
	if condition:
		return

	push_error("SmokeTest failed: %s" % label)
	quit(1)

func _array_equals(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false

	for index in range(values.size()):
		if String(values[index]) != String(expected[index]):
			return false

	return true

func _string_name_array_equals(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false

	for index in range(values.size()):
		if StringName(values[index]) != StringName(expected[index]):
			return false

	return true

func _start_run_at_first_combat(game) -> void:
	game.start_seeded_run("absolute")
	await process_frame
	_enter_first_combat_from_camp(game)
	await process_frame

func _start_seeded_combat_run(game, seed_value: String) -> void:
	game.start_seeded_run(seed_value)
	await process_frame
	_enter_first_combat_from_camp(game)
	await process_frame

func _enter_first_combat_from_camp(game) -> void:
	_require(game.state.map_node_kind == "rest", "run starts at camp")
	_require(game._key_program_editable, "camp allows key slot editing")
	_require(game.state.is_safe_training, "camp allows safe action testing")
	game._on_rest_continue_requested()

func _disable_enemies(game) -> void:
	game.enemy_planner.enemies_are_static = true
	for enemy in game.state.get_alive_enemies():
		game.state.grid.remove_actor(enemy)
		enemy.hp = 0

func _move_player_to(game, cell: Vector2i) -> void:
	var player = game.state.player
	game.state.grid.remove_actor(player)
	player.facing = Vector2i.RIGHT
	game.state.grid.place_actor(player, cell)

func _prepare_single_enemy_room(game, enemy_cell: Vector2i, enemy_hp: int, player_cell: Vector2i = Vector2i(1, 1)):
	game.enemy_planner.enemies_are_static = true
	_move_player_to(game, player_cell)

	var enemies: Array = game.state.get_alive_enemies()
	_require(not enemies.is_empty(), "test room has an enemy")
	var primary_enemy = enemies[0]
	for index in range(enemies.size()):
		var enemy = enemies[index]
		game.state.grid.remove_actor(enemy)
		if index == 0:
			enemy.max_hp = enemy_hp
			enemy.hp = enemy_hp
			game.state.grid.place_actor(enemy, enemy_cell)
		else:
			enemy.hp = 0

	return primary_enemy

func _make_player_action(game, action_id: String):
	var action = ActionInstanceScript.new()
	action.actor = game.state.player
	action.def = game._action_by_id[action_id]
	return action


func _find_world_slice_poi_record(map_data, poi_type: String) -> Dictionary:
	if map_data == null:
		return {}
	for record in map_data.get_poi_records():
		if String(record.get("type", "")) == poi_type:
			return record
	return {}


func _is_adjacent_to_any_cell(cell: Vector2i, other_cells: Array) -> bool:
	for other_value in other_cells:
		var other_cell: Vector2i = Vector2i(other_value)
		if absi(cell.x - other_cell.x) + absi(cell.y - other_cell.y) == 1:
			return true
	return false


func _world_slice_cell_hugs_wall(map_data, cell: Vector2i) -> bool:
	if map_data == null:
		return false
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = map_data.get_cell(cell + dir)
		if neighbor == null:
			continue
		if neighbor.tags.has("building_wall") or not bool(neighbor.walkable):
			return true
	return false


func _reward_list_has_kind(rewards: Array, kind: String) -> bool:
	for reward in rewards:
		if String(reward.get("kind", "")) == kind:
			return true
	return false




func _wait_for_turn_completion(game, initial_turn_count: int) -> void:
	for _step in range(30):
		if game == null or game.state == null:
			return
		if (game.state.phase == "planning" or game.state.phase == "finished") and game.state.turn_count > initial_turn_count:
			return
		await process_frame


func _move_pool_token_to_slot(game, token_id: String, slot_id: String) -> void:
	var pool_tokens: Array = game.get_key_program_pool_tokens()
	var token_index := pool_tokens.find(token_id)
	_require(token_index >= 0, "pool contains token %s before move" % token_id)
	game._on_key_token_move_requested("POOL", token_index, slot_id)


func _vector2i_array_equals(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false

	for index in range(values.size()):
		if Vector2i(values[index]) != Vector2i(expected[index]):
			return false

	return true


func _vector2i_set_equals(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false
	for expected_cell in expected:
		if not values.has(Vector2i(expected_cell)):
			return false
	return true


func _count_world_slice_props(state) -> int:
	if state == null or state.grid == null:
		return 0
	var count := 0
	for cell in state.grid.grid_items_at.keys():
		for item in state.grid.get_grid_items(cell):
			if item != null and item.tags.has("world_slice_placeholder"):
				count += 1
	return count


func _count_visible_world_slice_enemies(state) -> int:
	if state == null:
		return 0
	var count := 0
	for enemy in state.get_alive_enemies():
		if state.visible_cells.has(enemy.grid_pos):
			count += 1
	return count


func _world_slice_has_poi_type(map_data, poi_type: String) -> bool:
	if map_data == null:
		return false
	for record in map_data.get_poi_records():
		if String(record.get("type", "")) == poi_type:
			return true
	return false


func _world_slice_building_footprints_are_valid(map_data) -> bool:
	if map_data == null:
		return false
	for record in map_data.get_poi_records():
		var occupied: Array = record.get("occupied_cells", [])
		var interaction_cell: Vector2i = Vector2i(record.get("interaction_cell", Vector2i(-1, -1)))
		var origin: Vector2i = Vector2i(record.get("origin", Vector2i(-1, -1)))
		var size: Vector2i = Vector2i(record.get("size", Vector2i.ZERO))
		if occupied.is_empty() or interaction_cell == Vector2i(-1, -1) or origin == Vector2i(-1, -1):
			return false
		if size.x <= 0 or size.y <= 0:
			return false
		if interaction_cell == map_data.player_spawn:
			return false
		if _world_path_length(map_data, map_data.player_spawn, interaction_cell) < 0:
			return false
	return true


func _mountain_passes_use_cardinal_connections(map_data) -> bool:
	if map_data == null:
		return true
	for cell in map_data.get_all_cells():
		var map_cell = map_data.get_cell(cell)
		if map_cell == null or not map_cell.tags.has("mountain_pass"):
			continue
		var has_cardinal_neighbor := false
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = map_data.get_cell(cell + dir)
			if neighbor != null and neighbor.tags.has("mountain_pass"):
				has_cardinal_neighbor = true
				break
		if not has_cardinal_neighbor:
			for entry in map_data.get_all_poi_entries():
				var poi_cell: Vector2i = entry.get("cell", Vector2i(-1, -1))
				if poi_cell == cell:
					has_cardinal_neighbor = true
					break
			if cell == map_data.player_spawn:
				has_cardinal_neighbor = true
		if not has_cardinal_neighbor:
			return false
	return true


func _pick_far_world_cell(map_data, origin: Vector2i, min_distance: int) -> Vector2i:
	if map_data == null:
		return Vector2i(-1, -1)
	for cell in map_data.get_all_cells():
		if origin.distance_to(cell) > float(min_distance):
			return cell
	return Vector2i(-1, -1)


func _pick_first_walkable_world_move(state, origin: Vector2i) -> Dictionary:
	if state == null or state.map_data == null or state.grid == null:
		return {}
	var options := [
		{"token_id": "U", "delta": Vector2i.UP},
		{"token_id": "R", "delta": Vector2i.RIGHT},
		{"token_id": "D", "delta": Vector2i.DOWN},
		{"token_id": "L", "delta": Vector2i.LEFT},
	]
	for option in options:
		var target: Vector2i = origin + Vector2i(option["delta"])
		if state.map_data.is_walkable(target) and state.grid.can_enter(target):
			return {"token_id": String(option["token_id"]), "target": target, "delta": Vector2i(option["delta"])}
	return {}


func _world_path_length(map_data, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if map_data == null or not map_data.is_walkable(from_cell) or not map_data.is_walkable(to_cell):
		return -1
	if from_cell == to_cell:
		return 0
	var queue: Array[Vector2i] = [from_cell]
	var visited: Dictionary = {from_cell: 0}
	var queue_index: int = 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		var distance: int = int(visited[current])
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + dir
			if visited.has(next) or not map_data.is_walkable(next):
				continue
			if next == to_cell:
				return distance + 1
			visited[next] = distance + 1
			queue.append(next)
	return -1


func _is_world_slice_rest_area_cell(map_data, cell: Vector2i) -> bool:
	if map_data == null:
		return false
	var map_cell = map_data.get_cell(cell)
	if map_cell == null:
		return false
	if not bool(map_cell.walkable):
		return false
	for tag in map_cell.tags:
		var text := String(tag)
		if text == "poi:tavern" or text.begins_with("structure:tavern") or text.begins_with("building:tavern_"):
			return true
	return false


func _find_world_slice_tavern_interactable_cell(map_data) -> Vector2i:
	if map_data == null:
		return Vector2i(-1, -1)
	for cell in map_data.get_walkable_cells():
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		if not map_cell.tags.has("interactable"):
			continue
		for tag in map_cell.tags:
			var text := String(tag)
			if text == "poi:tavern" or text.begins_with("structure:tavern") or text.begins_with("building:tavern_"):
				return cell
	return Vector2i(-1, -1)


func _find_world_slice_npc(game, npc_id: String):
	if game == null:
		return null
	for npc in game.get_world_slice_npcs():
		if npc != null and npc.def != null and String(npc.def.id) == npc_id:
			return npc
	return null


func _find_walkable_adjacent_world_cell(state, origin: Vector2i) -> Vector2i:
	if state == null or state.map_data == null or state.grid == null:
		return Vector2i(-1, -1)
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = origin + dir
		if not state.map_data.is_walkable(cell):
			continue
		var occupant = state.grid.get_actor(cell)
		if occupant != null and occupant != state.player:
			continue
		return cell
	return Vector2i(-1, -1)


func _find_nearest_world_slice_non_rest_area_cell(map_data, origin: Vector2i) -> Vector2i:
	if map_data == null:
		return Vector2i(-1, -1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for cell in map_data.get_walkable_cells():
		if _is_world_slice_rest_area_cell(map_data, cell):
			continue
		var distance: float = origin.distance_squared_to(cell)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _world_slice_snapshot_key(state) -> String:
	if state == null or state.map_data == null:
		return ""
	var counts: Dictionary = state.map_data.get_terrain_counts()
	return "|".join([
		String(state.map_data.seed),
		str(state.map_data.player_spawn),
		str(state.map_data.tavern_cell),
		str(state.map_data.challenge_cells),
		str(state.map_data.chest_cells),
		str(state.map_data.ruin_cells),
		str(state.map_data.easter_egg_cells),
		str(state.map_data.shrine_cells),
		str(state.map_data.get_poi_records().size()),
		str(int(counts.get("plain", 0))),
		str(int(counts.get("forest", 0))),
		str(int(counts.get("tree", 0))),
		str(int(counts.get("structure_wall", 0))),
		str(int(counts.get("hill", 0))),
		str(int(counts.get("mountain", 0))),
		str(int(counts.get("peak", 0))),
		str(int(counts.get("swamp", 0))),
		str(int(counts.get("desert", 0))),
		str(int(state.map_data.reachable_count)),
		str(int(state.map_data.unreachable_poi_count)),
	])

func _submit_player_actions(game, action_ids: Array) -> void:
	var plan: Array = []
	for action_id in action_ids:
		plan.append(_make_player_action(game, String(action_id)))
	game.turn_controller.submit_player_plan(plan)

func _actor_has_modifier(actor, modifier_id: String) -> bool:
	if actor == null:
		return false
	for modifier in actor.effect_modifiers:
		if modifier != null and String(modifier.id) == modifier_id:
			return true
	return false
