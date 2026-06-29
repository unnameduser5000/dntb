extends SceneTree

const GameScene := preload("res://scenes/game/Game.tscn")
const ActionProgramControllerScript := preload("res://scripts/core/ActionProgramController.gd")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")
const ProbeWeaponScript := preload("res://scripts/tests/ProbeWeaponDef.gd")
const DuplicateDamageModifierScript := preload("res://scripts/tests/DuplicateDamageModifierDef.gd")
const AmplifyTagDamageModifierScript := preload("res://scripts/tests/AmplifyTagDamageModifierDef.gd")
const DuplicateMoveModifierScript := preload("res://scripts/tests/DuplicateMoveModifierDef.gd")
const AmplifyKnockbackModifierScript := preload("res://scripts/tests/AmplifyKnockbackModifierDef.gd")
const OnHitBonusDamageModifierScript := preload("res://scripts/tests/OnHitBonusDamageModifierDef.gd")
const OnMoveZapAheadModifierScript := preload("res://scripts/tests/OnMoveZapAheadModifierDef.gd")
const WorldSliceControllerScript := preload("res://scripts/core/WorldSliceController.gd")
const IMPACT_SHIELD := preload("res://data/weapons/impact_shield.tres")

func _init() -> void:
	var game = GameScene.instantiate()
	root.add_child(game)
	await process_frame

	await _start_run_at_first_combat(game)

	_require(game.state.room_index == 0, "run starts in room 1")
	_require(game.state.player.hp == 8, "player starts with 8 hp")
	_require(game.state.get_alive_enemies().size() == 2, "first room has two enemies")
	_require(game.state.danger_cells.has(Vector2i(2, 1)), "enemy attack range is previewed")

	var enemy = game.state.get_alive_enemies()[0]
	game.state.grid.remove_actor(enemy)
	game.state.grid.place_actor(enemy, Vector2i(2, 1))
	_submit_player_actions(game, ["wait"])
	await process_frame

	_require(game.state.player.hp == 7, "adjacent enemy attacks after player plan")

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
	_require(game.state.player.active_weapon.supports_technique("lunge"), "equipped weapon already supports lunge")
	_require(game.state.player.active_weapon.supports_technique("sweep"), "equipped weapon already supports sweep")
	_require(not game.get_key_program_pool_tokens().has("lunge"), "lunge does not enter key token pool")
	_require(game._key_program_editable, "post-practice rest unlocks key slot editing")
	var lunge_plan: Array = game._build_key_slot_plan(["R", "R"])
	await process_frame
	_require(_array_equals(game.get_key_program_slots()["U"], ["U"]), "rest editing keeps only natural direction tokens")
	_require(lunge_plan.size() == 2 and lunge_plan[0].def.id == "move_key" and lunge_plan[1].def.id == "move_key", "key program keeps only base move actions even when lunge is unlocked")
	var lunge_preview: Dictionary = game._build_key_slot_preview(["R", "R"])
	_require(_string_name_array_equals(lunge_preview.get("trace_symbols", []), [&"F", &"F"]), "rest preview predicts relative trace from absolute direction input")
	_require(lunge_preview.get("predicted_combo_match_ids", []).has("lunge"), "rest preview predicts lunge from trace semantics instead of replacing the key plan")
	_require(lunge_preview["attack_cells"].has(Vector2i(6, 3)), "predicted lunge preview shows the follow-up attack cell")
	_require(lunge_preview["move_cells"].has(Vector2i(6, 3)), "predicted lunge preview extends movement through the combo follow-up")
	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.room_index == 1, "post-practice rest continues to second room")

	var starter_program = ActionProgramControllerScript.new()
	starter_program.setup()
	starter_program.reset_starter_slots("absolute")
	var absolute_slots := starter_program.get_key_slots()
	_require(_array_equals(absolute_slots["U"], ["U"]), "absolute starter preset keeps U as U")
	_require(_array_equals(absolute_slots["D"], ["D"]), "absolute starter preset keeps D as D")
	_require(_array_equals(absolute_slots["L"], ["L"]), "absolute starter preset keeps L as L")
	_require(_array_equals(absolute_slots["R"], ["R"]), "absolute starter preset keeps R as R")
	starter_program.reset_starter_slots("relative")
	var relative_slots := starter_program.get_key_slots()
	_require(_array_equals(relative_slots["U"], ["F"]), "relative starter preset puts F in U")
	_require(_array_equals(relative_slots["D"], ["TR", "TR", "F"]), "relative starter preset puts TR/TR/F in D")
	_require(_array_equals(relative_slots["L"], ["TL", "F"]), "relative starter preset puts TL/F in L")
	_require(_array_equals(relative_slots["R"], ["TR", "F"]), "relative starter preset puts TR/F in R")
	_require(_array_equals(starter_program.get_token_drop_pool(), ["U", "D", "L", "R", "F", "TL", "TR"]), "token drop pool includes mixed direction and control tokens")
	_require(starter_program.is_program_token("F"), "F is a legal program token")
	_require(starter_program.is_program_token("TL"), "TL is a legal program token")
	_require(starter_program.is_program_token("TR"), "TR is a legal program token")
	_require(_array_equals(game._build_key_slot_plan(relative_slots["L"]).map(func(action): return action.def.id), ["turn_left", "move_forward"]), "relative starter L slot builds turn_left + move_forward")
	_require(_array_equals(game._build_key_slot_plan(relative_slots["R"]).map(func(action): return action.def.id), ["turn_right", "move_forward"]), "relative starter R slot builds turn_right + move_forward")
	_require(_array_equals(game._build_key_slot_plan(relative_slots["D"]).map(func(action): return action.def.id), ["turn_right", "turn_right", "move_forward"]), "relative starter D slot builds turn_right + turn_right + move_forward")

	game.start_seeded_run("absolute")
	await process_frame
	_require(game.state.map_node_kind == "rest", "run starts at camp")
	_require(game._key_program_editable, "camp unlocks key slot editing")
	_require(game.state.is_safe_training, "camp is a safe training sandbox")
	var starter_slots: Dictionary = game.get_key_program_slots()
	_require(_array_equals(starter_slots["U"], ["U"]), "up key starts with up token")
	_require(_array_equals(starter_slots["D"], ["D"]), "down key starts with down token")
	_require(_array_equals(starter_slots["L"], ["L"]), "left key starts with left token")
	_require(_array_equals(starter_slots["R"], ["R"]), "right key starts with right token")
	game.start_seeded_run("relative")
	await process_frame
	_require(game.state.map_node_kind == "rest", "relative seeded run also starts at camp")
	var relative_starter_slots: Dictionary = game.get_key_program_slots()
	_require(_array_equals(relative_starter_slots["U"], ["F"]), "relative seeded run puts F in U")
	_require(_array_equals(relative_starter_slots["D"], ["TR", "TR", "F"]), "relative seeded run puts TR/TR/F in D")
	_require(_array_equals(relative_starter_slots["L"], ["TL", "F"]), "relative seeded run puts TL/F in L")
	_require(_array_equals(relative_starter_slots["R"], ["TR", "F"]), "relative seeded run puts TR/F in R")
	game.start_seeded_run("absolute")
	await process_frame
	_require(game.state.map_node_kind == "rest", "absolute seeded run also starts at camp")
	var control_plan: Array = game._build_key_slot_plan(["U"])
	_require(control_plan.size() == 1 and control_plan[0].def.id == "move_key", "default up slot stays a pure move action")
	var f_plan: Array = game._build_key_slot_plan(["F"])
	_require(f_plan.size() == 1 and f_plan[0].def.id == "move_forward", "F token maps to move_forward action")
	var tl_plan: Array = game._build_key_slot_plan(["TL"])
	_require(tl_plan.size() == 1 and tl_plan[0].def.id == "turn_left", "TL token maps to turn_left action")
	var tr_plan: Array = game._build_key_slot_plan(["TR"])
	_require(tr_plan.size() == 1 and tr_plan[0].def.id == "turn_right", "TR token maps to turn_right action")

	game._on_key_token_move_requested("R", 0, "U")
	await process_frame
	_require(game.get_key_program_slots()["R"].is_empty(), "camp editing can empty right key slot")
	_require(_array_equals(game.get_key_program_slots()["U"], ["U", "R"]), "camp editing can chain up then right")
	_move_player_to(game, Vector2i(3, 3))
	game._submit_key_chain("R")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(3, 3), "empty right key slot has no mapped movement in camp")
	game._submit_key_chain("U")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(4, 2), "camp sandbox can test chained up then right movement")
	_require(_string_name_array_equals(game.get_player_action_trace_symbols(2), [&"SL", &"SR"]), "absolute input chain is recorded as relative action trace symbols")
	_require(game.get_player_action_trace_debug_string(2) == "SL -> SR", "player trace debug string reports recent relative symbols")

	var input_service = root.get_node_or_null("/root/PlayerInputService")
	_require(input_service != null, "player input service autoload exists")
	_require(input_service.get_key_id_for_action("player_move_up") == "U", "keyboard up action maps to up key slot")
	_require(input_service.get_action_for_key_id("R") == "player_move_right", "right key slot maps back to keyboard action")

	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.map_node_kind == "combat", "camp continues to first combat")
	_require(not game._key_program_editable, "combat locks key slot editing")
	game._on_key_token_move_requested("U", 1, "R")
	await process_frame
	_require(game.get_key_program_slots()["R"].is_empty(), "combat keeps right key slot unchanged")
	_require(_array_equals(game.get_key_program_slots()["U"], ["U", "R"]), "combat keeps up key slot unchanged")

	game.start_seeded_run("absolute")
	await process_frame
	game._start_map_node(4)
	await process_frame
	_require(game.state.map_node_kind == "rest", "route has a rest node")
	_require(game._key_program_editable, "rest node unlocks key slot editing")

	game._on_key_token_move_requested("R", 0, "U")
	await process_frame
	_require(game.get_key_program_slots()["R"].is_empty(), "rest editing can empty right key slot")
	_require(_array_equals(game.get_key_program_slots()["U"], ["U", "R"]), "rest editing can chain up then right")

	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.map_node_kind == "boss", "rest continues to boss node")
	_require(not game._key_program_editable, "boss node locks key slot editing")

	_disable_enemies(game)
	_move_player_to(game, Vector2i(3, 2))
	game._submit_key_chain("R")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(3, 2), "empty right key slot has no mapped movement")

	game._submit_key_chain("U")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(4, 1), "pressing up key executes chained up then right movement")
	_require(_string_name_array_equals(game.get_player_action_trace_symbols(2), [&"SL", &"SR"]), "combat key-program execution records recent relative trace symbols")

	await _start_seeded_combat_run(game, "action-trace-turn")
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	var trace_plan: Array = [_make_player_action(game, "turn_left"), _make_player_action(game, "move_forward")]
	game.turn_controller.submit_player_plan(trace_plan)
	await process_frame
	_require(_string_name_array_equals(game.get_player_action_trace_symbols(2), [&"TL", &"F"]), "turn then move records relative turn and forward trace symbols")
	_require(game.state.player.grid_pos == Vector2i(2, 1), "turn then move uses updated facing for forward movement")

	var combo_lunge_game = await _make_weapon_combo_game("weapon-combo-lunge")
	var combo_lunge_hits := await _run_weapon_combo_chain(combo_lunge_game, ["R", "R"], Vector2i.DOWN, Vector2i(2, 3), "lunge")
	_require(combo_lunge_hits == 1, "R,R triggers lunge once")
	_require(combo_lunge_game.get_player_action_trace_move_dirs_debug_string(2) == "R -> R", "R,R combo reports repeated move directions")
	_require(combo_lunge_game.get_player_weapon_combo_debug_string(1) == "lunge", "R,R combo reports lunge id in debug string")
	var combo_lunge_u_game = await _make_weapon_combo_game("weapon-combo-lunge-u")
	var combo_lunge_u_hits := await _run_weapon_combo_chain(combo_lunge_u_game, ["U", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge")
	_require(combo_lunge_u_hits == 1, "U,U triggers lunge once")
	var combo_lunge_rrrr_game = await _make_weapon_combo_game("weapon-combo-lunge-rrrr")
	_require(await _run_weapon_combo_chain(combo_lunge_rrrr_game, ["R", "R", "R", "R"], Vector2i.DOWN, Vector2i(2, 3), "lunge") == 2, "R,R,R,R triggers lunge twice")
	var combo_lunge_rruu_game = await _make_weapon_combo_game("weapon-combo-lunge-rruu")
	_require(await _run_weapon_combo_chain(combo_lunge_rruu_game, ["R", "R", "U", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge") == 2, "R,R,U,U triggers lunge twice")
	var rruu_lunge_matches: Array = _combo_matches_by_id(combo_lunge_rruu_game, "lunge")
	_require(rruu_lunge_matches.size() == 2, "R,R,U,U stores two lunge matches")
	_require(Vector2i(rruu_lunge_matches[0].get("matched_move_dir", Vector2i.ZERO)) == Vector2i.RIGHT, "R,R,U,U first lunge match stores RIGHT")
	_require(Vector2i(rruu_lunge_matches[1].get("matched_move_dir", Vector2i.ZERO)) == Vector2i.UP, "R,R,U,U second lunge match stores UP")
	_require(_vector2i_array_equals(await _capture_combo_followup_dirs(combo_lunge_rruu_game, ["R", "R", "U", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge"), [Vector2i.RIGHT, Vector2i.UP]), "R,R,U,U follow-up lunges execute in RIGHT then UP order")
	var combo_lunge_ruu_game = await _make_weapon_combo_game("weapon-combo-lunge-ruu")
	_require(await _run_weapon_combo_chain(combo_lunge_ruu_game, ["R", "U", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge") == 1, "R,U,U triggers lunge once")
	_require(_vector2i_array_equals(await _capture_combo_followup_dirs(combo_lunge_ruu_game, ["R", "U", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge"), [Vector2i.UP]), "R,U,U lunge follow-up executes upward")
	var combo_lunge_ru_game = await _make_weapon_combo_game("weapon-combo-lunge-ru")
	_require(await _run_weapon_combo_chain(combo_lunge_ru_game, ["R", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge") == 0, "R,U does not trigger lunge")
	var combo_lunge_ruru_game = await _make_weapon_combo_game("weapon-combo-lunge-ruru")
	_require(await _run_weapon_combo_chain(combo_lunge_ruru_game, ["R", "U", "R", "U"], Vector2i.DOWN, Vector2i(3, 3), "lunge") == 0, "R,U,R,U does not trigger lunge")
	var combo_lunge_blocked_game = await _make_weapon_combo_game("weapon-combo-lunge-blocked")
	combo_lunge_blocked_game.state.grid.add_blocked(Vector2i(4, 3))
	_require(await _run_weapon_combo_chain(combo_lunge_blocked_game, ["R", "R"], Vector2i.RIGHT, Vector2i(2, 3), "lunge") == 0, "blocked second move does not trigger lunge")

	var combo_sweep_game = await _make_weapon_combo_game("weapon-combo-sweep")
	_require(await _run_weapon_combo_chain(combo_sweep_game, ["TL", "TR"], Vector2i.DOWN, Vector2i(3, 3), "sweep") == 1, "TL,TR triggers sweep once")
	var combo_sweep_double_game = await _make_weapon_combo_game("weapon-combo-sweep-double")
	_require(await _run_weapon_combo_chain(combo_sweep_double_game, ["TL", "TR", "TL", "TR"], Vector2i.DOWN, Vector2i(3, 3), "sweep") == 2, "TL,TR,TL,TR triggers sweep twice")
	var combo_sweep_negative_game = await _make_weapon_combo_game("weapon-combo-sweep-negative")
	_require(await _run_weapon_combo_chain(combo_sweep_negative_game, ["TL", "F", "TR"], Vector2i.DOWN, Vector2i(3, 3), "sweep") == 0, "TL,F,TR does not trigger sweep")
	var combo_sweep_implicit_game = await _make_weapon_combo_game("weapon-combo-sweep-implicit")
	_require(await _run_weapon_combo_chain(combo_sweep_implicit_game, ["R", "R"], Vector2i.DOWN, Vector2i(2, 3), "sweep") == 0, "implicit turn from R,R does not trigger sweep")

	var combo_mix_game = await _make_weapon_combo_game("weapon-combo-mix")
	_require(await _run_weapon_combo_chain(combo_mix_game, ["TL", "TR", "F", "F"], Vector2i.DOWN, Vector2i(3, 3), "sweep") == 1, "TL,TR,F,F triggers sweep once")
	_require(_count_combo_matches(combo_mix_game, "lunge") == 1, "TL,TR,F,F also triggers lunge once")
	var combo_mix_preview_game = await _make_weapon_combo_game("weapon-combo-mix-preview")
	_move_player_to(combo_mix_preview_game, Vector2i(3, 3))
	combo_mix_preview_game.state.player.facing = Vector2i.DOWN
	var combo_mix_preview: Dictionary = combo_mix_preview_game._build_key_slot_preview(["TL", "TR", "F", "F"])
	_require(_array_equals(combo_mix_preview.get("predicted_combo_match_ids", []), ["sweep", "lunge"]), "preview predicts sweep + lunge for TL,TR,F,F")

	var trace_semantic_game = await _make_weapon_combo_game("weapon-combo-trace-semantics")
	_move_player_to(trace_semantic_game, Vector2i(2, 2))
	trace_semantic_game.state.player.facing = Vector2i.UP
	trace_semantic_game.state.player.active_weapon = IMPACT_SHIELD
	var absolute_trace_plan: Array = trace_semantic_game._build_key_slot_plan(["R"])
	trace_semantic_game.turn_controller.submit_player_plan(absolute_trace_plan)
	await process_frame
	_require(_string_name_array_equals(trace_semantic_game.get_player_action_trace_symbols(1), [&"SR"]), "absolute move records move semantic, not explicit turn semantic")
	_require(not trace_semantic_game.get_player_action_trace_debug_string(1).contains("TL"), "absolute move trace is not disguised as TL")
	_require(not trace_semantic_game.get_player_action_trace_debug_string(1).contains("TR"), "absolute move trace is not disguised as TR")
	_require(Vector2i(trace_semantic_game.state.action_trace.get_recent_entries_for_actor(int(trace_semantic_game.state.player.id), 1)[0].move_dir) == Vector2i.RIGHT, "runtime trace move_dir stays normalized to unit direction")

	var preview_rruu_game = await _make_weapon_combo_game("weapon-combo-preview-rruu")
	_move_player_to(preview_rruu_game, Vector2i(3, 3))
	preview_rruu_game.state.player.facing = Vector2i.DOWN
	var preview_rruu: Dictionary = preview_rruu_game._build_key_slot_preview(["R", "R", "U", "U"])
	var preview_rruu_lunge_matches := _preview_matches_by_id(preview_rruu, "lunge")
	_require(preview_rruu_lunge_matches.size() == 2, "preview R,R,U,U predicts two lunge matches")
	_require(Vector2i(preview_rruu_lunge_matches[0].get("matched_move_dir", Vector2i.ZERO)) == Vector2i.RIGHT, "preview R,R,U,U first lunge direction is RIGHT")
	_require(Vector2i(preview_rruu_lunge_matches[1].get("matched_move_dir", Vector2i.ZERO)) == Vector2i.UP, "preview R,R,U,U second lunge direction is UP")

	var lunge_dir_game = await _make_weapon_combo_game("weapon-combo-lunge-direction", Vector2i(3, 2))
	lunge_dir_game.enemy_planner.enemies_are_static = true
	lunge_dir_game.state.grid.blocked_cells.clear()
	_move_player_to(lunge_dir_game, Vector2i(2, 2))
	lunge_dir_game.state.player.facing = Vector2i.UP
	var lunge_dir_action = _make_player_action(lunge_dir_game, "lunge")
	lunge_dir_action.chosen_dir = Vector2i.RIGHT
	var right_enemy = lunge_dir_game.state.grid.get_actor(Vector2i(3, 2))
	var right_enemy_hp_before: int = right_enemy.hp
	lunge_dir_game.resolver.resolve(lunge_dir_action, lunge_dir_game.state)
	_require(lunge_dir_game.state.player.facing == Vector2i.RIGHT, "lunge updates facing to chosen_dir when present")
	_require(right_enemy.hp < right_enemy_hp_before, "lunge uses chosen_dir to hit the right-side enemy instead of current facing")

	var lab_game = GameScene.instantiate()
	root.add_child(lab_game)
	await process_frame
	lab_game.start_weapon_combo_lab_debug()
	await process_frame
	_require(lab_game.state.map_node_kind == "weapon_combo_lab", "weapon combo lab debug entry creates the lab state")
	_require(lab_game.state.is_safe_training, "weapon combo lab runs as safe training")
	_require(lab_game.state.player.active_weapon == IMPACT_SHIELD, "weapon combo lab equips impact shield")
	_require(lab_game._key_program_editable, "weapon combo lab keeps key editing enabled")
	_require(_array_equals(lab_game.get_key_program_slots()["U"], ["F"]), "weapon combo lab starts with relative preset in U")
	_require(_array_equals(lab_game.get_key_program_slots()["D"], ["TR", "TR", "F"]), "weapon combo lab starts with relative preset in D")
	_require(_array_equals(lab_game.get_key_program_slots()["L"], ["TL", "F"]), "weapon combo lab starts with relative preset in L")
	_require(_array_equals(lab_game.get_key_program_slots()["R"], ["TR", "F"]), "weapon combo lab starts with relative preset in R")
	_require(_array_equals(lab_game.get_key_program_pool_tokens(), []), "weapon combo lab starts with empty pool")
	_require(lab_game.get_player_action_trace_symbols().is_empty(), "weapon combo lab starts with empty trace")
	_require(lab_game.state.get_alive_enemies().size() >= 2, "weapon combo lab spawns test enemies")
	_require(_array_equals(lab_game.get_player_weapon_combo_match_ids(1), []), "weapon combo lab starts with no cached combo match")
	_require(lab_game.state.player.active_weapon.supports_technique("lunge"), "weapon combo lab weapon already supports lunge")
	_require(lab_game.state.player.active_weapon.supports_technique("sweep"), "weapon combo lab weapon already supports sweep")
	var lab_lunge_plan: Array = lab_game._build_key_slot_plan(["F", "F"])
	lab_game.turn_controller.submit_player_plan(lab_lunge_plan)
	await process_frame
	_require(lab_game.get_player_weapon_combo_match_ids(1).has("lunge"), "weapon combo lab can trigger lunge from F/F")
	lab_game.start_weapon_combo_lab_debug()
	await process_frame
	var lab_sweep_plan: Array = lab_game._build_key_slot_plan(["TL", "TR"])
	lab_game.turn_controller.submit_player_plan(lab_sweep_plan)
	await process_frame
	_require(lab_game.get_player_weapon_combo_match_ids(1).has("sweep"), "weapon combo lab can trigger sweep from TL/TR")
	lab_game.queue_free()
	await process_frame

	game.start_seeded_run("absolute")
	await process_frame
	_require(game.state.map_node_kind == "rest", "mixed-drop test starts from camp")
	_require(game._key_program_editable, "mixed-drop test keeps rest editing enabled")
	_require(_array_equals(game.get_token_drop_pool(), ["U", "D", "L", "R", "F", "TL", "TR"]), "game exposes the mixed token drop pool")
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
	_require(_array_equals(game.get_key_program_pool_tokens(), ["F", "TL", "TR"]), "mixed tokens enter the spare-token pool")
	game._on_key_token_move_requested("U", 0, "POOL")
	_require(game.get_key_program_slots()["U"].is_empty(), "starter token can be moved out to make room for pooled tokens")
	game._on_key_token_move_requested("POOL", 0, "U")
	game._on_key_token_move_requested("POOL", 0, "U")
	game._on_key_token_move_requested("POOL", 0, "U")
	_require(_array_equals(game.get_key_program_slots()["U"], ["F", "TL", "TR"]), "pooled F/TL/TR tokens can be dragged into one physical slot")
	var mixed_plan: Array = game._build_key_slot_plan(game.get_key_program_slots()["U"])
	_require(mixed_plan.size() == 3 and mixed_plan[0].def.id == "move_forward" and mixed_plan[1].def.id == "turn_left" and mixed_plan[2].def.id == "turn_right", "mixed F/TL/TR slot builds the expected action plan")

	var world_game = GameScene.instantiate()
	root.add_child(world_game)
	await process_frame
	world_game.start_run()
	await process_frame
	_require(world_game.state.map_node_kind == "world_slice", "default run entry creates the world slice state")
	_require(world_game.state.grid.width >= 30 and world_game.state.grid.height >= 30, "world slice uses a larger grid than the room demo")
	_require(world_game.state.player != null, "world slice creates a player")
	_require(world_game.state.get_alive_enemies().size() == 4, "world slice creates four test enemies")
	_require(world_game.state.grid.get_actor(Vector2i(4, 4)) == world_game.state.player, "world slice places the player in the grid")
	_require(world_game.state.grid.get_actor(Vector2i(8, 4)) != null, "world slice places the first enemy in the grid")
	_require(world_game.state.grid.get_actor(Vector2i(4, 8)) != null, "world slice places the second enemy in the grid")
	_require(world_game.state.grid.get_actor(Vector2i(11, 6)) != null, "world slice places the third enemy in the grid")
	_require(world_game.state.grid.get_actor(Vector2i(6, 11)) != null, "world slice places the fourth enemy in the grid")
	_require(world_game.state.grid.get_grid_items(Vector2i(10, 10)).size() == 1, "world slice places a placeholder prop")
	_require(_array_equals(world_game.get_key_program_slots()["U"], ["U"]), "world slice reuses the current key program")
	_require(world_game.state.visible_cells.size() > 0, "world slice computes initial visible cells")
	_require(world_game.state.explored_cells.size() >= world_game.state.visible_cells.size(), "world slice explored cells include current visible cells")
	_require(world_game.state.visible_cells.has(Vector2i(4, 4)), "world slice reveals the player cell")
	_require(not world_game.state.visible_cells.has(Vector2i(14, 4)), "world slice hides far cell at init")
	_require(not world_game.state.visible_cells.has(Vector2i(10, 4)), "world slice wall blocks line of sight")
	_require(world_game.state.explored_cells.has(Vector2i(4, 4)), "world slice explored keeps the player cell")
	var explored_before_move: int = world_game.state.explored_cells.size()
	world_game.enemy_planner.enemies_are_static = true
	var world_action_plan: Array = world_game._build_key_slot_plan(["U"])
	_require(world_action_plan.size() == 1 and world_action_plan[0].def.id == "move_key", "world slice can generate an action plan from the current key program")
	world_game.turn_controller.submit_player_plan(world_action_plan)
	await process_frame
	_require(world_game.state.player.grid_pos == Vector2i(4, 3), "world slice executes one movement step through the shared battle core")
	_require(world_game.state.last_visibility_recompute_reason == "player_moved", "world slice recomputes visibility after player movement")
	_require(world_game.state.visible_cells.has(Vector2i(4, 3)), "world slice keeps the moved player cell visible")
	_require(world_game.state.explored_cells.size() >= explored_before_move, "world slice explored cells never shrink after moving")
	world_game._world_slice_controller.set_reveal_all_debug(world_game.state, true, "debug_toggle")
	_require(world_game.state.reveal_all_debug, "world slice reveal-all toggle turns on")
	_require(world_game.state.visible_cells.size() == world_game.state.map_data.get_size().x * world_game.state.map_data.get_size().y, "world slice reveal-all shows the whole map")
	world_game._world_slice_controller.set_reveal_all_debug(world_game.state, false, "debug_toggle")
	_require(not world_game.state.reveal_all_debug, "world slice reveal-all toggle turns off")
	world_game._world_slice_controller.reset_world_slice(world_game.state)
	_require(world_game.state.visible_cells.size() > 0, "world slice reset recomputes visible cells")
	_require(world_game.state.explored_cells.size() >= world_game.state.visible_cells.size(), "world slice reset keeps explored at least current visible")
	world_game.queue_free()
	await process_frame

	await _start_seeded_combat_run(game, "impact-shield-single")
	game.state.player.active_weapon = _make_collision_only_weapon()
	var single_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 10)
	var single_plan: Array = game._build_key_slot_plan(["R"])
	game.turn_controller.submit_player_plan(single_plan)
	await process_frame
	_require(single_plan[0].chain_speed == 1, "single movement collision has speed 1")
	_require(single_enemy.hp == 9, "speed 1 impact shield deals 1 damage")
	_require(single_enemy.grid_pos == Vector2i(3, 1), "speed 1 impact shield knocks enemy back 1 cell")
	_require(game.state.player.grid_pos == Vector2i(2, 1), "attacker enters collision cell after speed 1 impact")

	await _start_seeded_combat_run(game, "impact-shield-double")
	game.state.player.active_weapon = _make_collision_only_weapon()
	var double_enemy = _prepare_single_enemy_room(game, Vector2i(3, 1), 10)
	var double_plan: Array = game._build_key_slot_plan(["R", "R"])
	game.turn_controller.submit_player_plan(double_plan)
	await process_frame
	_require(double_plan[0].chain_speed == 1, "first repeated movement has speed 1")
	_require(double_plan[1].chain_speed == 2, "second repeated movement has speed 2")
	_require(double_enemy.hp == 8, "speed 2 impact shield deals higher damage")
	_require(double_enemy.grid_pos == Vector2i(5, 1), "speed 2 impact shield knocks enemy back 2 cells")
	_require(game.state.player.grid_pos == Vector2i(3, 1), "attacker enters collision cell after speed 2 impact")

	await _start_seeded_combat_run(game, "weapon-hooks")
	var probe_weapon = ProbeWeaponScript.new()
	probe_weapon.id = "probe_weapon"
	probe_weapon.display_name = "Probe Weapon"
	game.state.player.active_weapon = probe_weapon
	var hooked_enemy = _prepare_single_enemy_room(game, Vector2i(3, 1), 10)
	var hook_plan: Array = game._build_key_slot_plan(["R", "R"])
	hook_plan.append(_make_player_action(game, "attack"))
	game.turn_controller.submit_player_plan(hook_plan)
	await process_frame
	_require(probe_weapon.hit_calls == 1, "weapon attack hit hook is called")
	_require(probe_weapon.chain_finished_calls == 1, "weapon chain finished hook is called")
	_require(probe_weapon.last_hit_speed == 2, "attack hook receives current movement momentum")
	_require(probe_weapon.last_hit_damage == 2, "attack hook receives default attack damage")
	_require(probe_weapon.last_chain_speed == 2, "chain finished hook receives final momentum")
	_require(hooked_enemy.hp == 5, "weapon attack hit hook can override default damage resolution")

	await _start_seeded_combat_run(game, "weapon-miss-hook")
	probe_weapon = ProbeWeaponScript.new()
	probe_weapon.id = "probe_weapon"
	probe_weapon.display_name = "Probe Weapon"
	game.state.player.active_weapon = probe_weapon
	_disable_enemies(game)
	_move_player_to(game, Vector2i(2, 2))
	var miss_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(miss_plan)
	await process_frame
	_require(probe_weapon.miss_calls == 1, "weapon attack miss hook is called")
	_require(probe_weapon.chain_finished_calls == 1, "weapon chain finished hook runs after a miss")

	await _start_seeded_combat_run(game, "effect-pipeline")
	game.state.player.active_weapon = null
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
	var amplified_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 10)
	var knockback_pipeline_plan: Array = game._build_key_slot_plan(["R"])
	game.turn_controller.submit_player_plan(knockback_pipeline_plan)
	await process_frame
	_require(amplify_knockback.amplified_packets == 1, "effect modifier can amplify a knockback packet")
	_require(amplified_enemy.hp == 9, "knockback modifier does not change impact shield damage")
	_require(amplified_enemy.grid_pos == Vector2i(4, 1), "amplified knockback packet pushes farther")

	await _start_seeded_combat_run(game, "modifier-reward")
	game._current_rewards = game._build_rewards()
	game._on_reward_chosen(1)
	await process_frame
	_require(game.state.map_node_kind == "rest", "modifier reward advances to post-practice rest")
	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.room_index == 1, "post-practice rest continues after modifier reward")
	_require(game._run_modifier_ids.has("echo_strike"), "modifier reward is tracked in run state")
	_require(_actor_has_modifier(game.state.player, "echo_strike"), "modifier reward is applied to the new room player")
	var reward_save_data: Dictionary = game.get_save_data()
	_require(reward_save_data.get("run_modifier_ids", []).has("echo_strike"), "modifier reward is included in save data")
	game.state.player.active_weapon = null
	var reward_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 20)
	var reward_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(reward_plan)
	await process_frame
	_require(reward_enemy.hp == 17, "formal echo strike modifier reward affects attack damage")

	await _start_seeded_combat_run(game, "effect-event-on-hit")
	game.state.player.active_weapon = null
	var on_hit_bonus = OnHitBonusDamageModifierScript.new()
	game.state.player.effect_modifiers.append(on_hit_bonus)
	var on_hit_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 20)
	var on_hit_plan: Array = [_make_player_action(game, "attack")]
	game.turn_controller.submit_player_plan(on_hit_plan)
	await process_frame
	_require(on_hit_bonus.triggered_count == 1, "effect event modifier reacts to attack damage dealt")
	_require(on_hit_enemy.hp == 17, "on-hit event can generate a follow-up damage packet")

	await _start_seeded_combat_run(game, "effect-event-on-move")
	game.state.player.active_weapon = null
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


func _make_weapon_combo_game(seed_value: String, enemy_cell: Vector2i = Vector2i(6, 2)):
	var combo_game = GameScene.instantiate()
	root.add_child(combo_game)
	await process_frame
	combo_game.start_seeded_run(seed_value)
	await process_frame
	_enter_first_combat_from_camp(combo_game)
	await process_frame
	combo_game.state.player.active_weapon = IMPACT_SHIELD
	combo_game.enemy_planner.enemies_are_static = true
	combo_game.state.grid.blocked_cells.clear()
	_prepare_single_enemy_room(combo_game, enemy_cell, 10, Vector2i(2, 2))
	return combo_game


func _make_collision_only_weapon():
	var weapon = IMPACT_SHIELD.duplicate(true)
	weapon.combo_techniques = []
	return weapon


func _run_weapon_combo_chain(game, token_ids: Array, facing: Vector2i, player_cell: Vector2i, expected_combo_id: String) -> int:
	_move_player_to(game, player_cell)
	game.state.player.facing = facing
	var initial_turn_count: int = int(game.state.turn_count)
	var plan: Array = game._build_key_slot_plan(token_ids)
	game.turn_controller.submit_player_plan(plan)
	await _wait_for_turn_completion(game, initial_turn_count)
	return _count_combo_matches(game, expected_combo_id)


func _count_combo_matches(game, technique_id: String) -> int:
	var count := 0
	for match_data in game.get_player_weapon_combo_matches(1):
		if String(match_data.get("technique_id", "")) == technique_id:
			count += 1
	return count


func _reward_list_has_kind(rewards: Array, kind: String) -> bool:
	for reward in rewards:
		if String(reward.get("kind", "")) == kind:
			return true
	return false


func _combo_matches_by_id(game, technique_id: String) -> Array:
	var matches: Array = []
	for match_data in game.get_player_weapon_combo_matches(1):
		if String(match_data.get("technique_id", "")) == technique_id:
			matches.append(match_data)
	return matches


func _preview_matches_by_id(preview: Dictionary, technique_id: String) -> Array:
	var matches: Array = []
	for match_data in preview.get("predicted_combo_matches", []):
		if String(match_data.get("technique_id", "")) == technique_id:
			matches.append(match_data)
	return matches


func _capture_combo_followup_dirs(game, token_ids: Array, facing: Vector2i, player_cell: Vector2i, technique_id: String) -> Array[Vector2i]:
	var captured_dirs: Array[Vector2i] = []
	var on_action_started = func(action) -> void:
		if action == null or action.def == null:
			return
		if String(action.key_id) != "technique:%s" % technique_id:
			return
		captured_dirs.append(Vector2i(action.chosen_dir))

	if not game.turn_controller.action_started.is_connected(on_action_started):
		game.turn_controller.action_started.connect(on_action_started)

	_move_player_to(game, player_cell)
	game.state.player.facing = facing
	var initial_turn_count: int = int(game.state.turn_count)
	var plan: Array = game._build_key_slot_plan(token_ids)
	game.turn_controller.submit_player_plan(plan)
	await _wait_for_turn_completion(game, initial_turn_count)
	if game.turn_controller.action_started.is_connected(on_action_started):
		game.turn_controller.action_started.disconnect(on_action_started)
	return captured_dirs


func _wait_for_turn_completion(game, initial_turn_count: int) -> void:
	for _step in range(30):
		if game == null or game.state == null:
			return
		if (game.state.phase == "planning" or game.state.phase == "finished") and game.state.turn_count > initial_turn_count:
			return
		await process_frame


func _vector2i_array_equals(values: Array, expected: Array) -> bool:
	if values.size() != expected.size():
		return false

	for index in range(values.size()):
		if Vector2i(values[index]) != Vector2i(expected[index]):
			return false

	return true

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
