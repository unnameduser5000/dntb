extends SceneTree

const GameScene := preload("res://scenes/game/Game.tscn")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")
const ProbeWeaponScript := preload("res://scripts/tests/ProbeWeaponDef.gd")
const DuplicateDamageModifierScript := preload("res://scripts/tests/DuplicateDamageModifierDef.gd")
const AmplifyTagDamageModifierScript := preload("res://scripts/tests/AmplifyTagDamageModifierDef.gd")
const DuplicateMoveModifierScript := preload("res://scripts/tests/DuplicateMoveModifierDef.gd")
const AmplifyKnockbackModifierScript := preload("res://scripts/tests/AmplifyKnockbackModifierDef.gd")
const OnHitBonusDamageModifierScript := preload("res://scripts/tests/OnHitBonusDamageModifierDef.gd")
const OnMoveZapAheadModifierScript := preload("res://scripts/tests/OnMoveZapAheadModifierDef.gd")

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
	game._on_plan_submitted(["wait"])
	await process_frame

	_require(game.state.player.hp == 7, "adjacent enemy attacks after player plan")

	await _start_run_at_first_combat(game)
	game._on_plan_submitted(["move_forward", "attack", "wait"])
	await process_frame

	_require(game.state.turn_count == 1, "submitted plan executes one turn")
	_require(game.state.get_alive_enemies().size() == 1, "move + attack kills first slime")

	game._on_battle_finished(true)
	await process_frame
	_require(game._current_rewards.size() == 3, "victory offers three rewards")

	game._on_reward_chosen(0)
	await process_frame
	_require(game.state.map_node_kind == "rest", "first reward advances to post-practice rest")
	_require(game._player_has_action("lunge"), "first reward adds lunge action")
	_require(game._loose_key_tokens.has("lunge"), "action reward enters loose action token pool")
	_require(game._key_program_editable, "post-practice rest unlocks key slot editing")
	game._on_key_token_move_requested("POOL", game._loose_key_tokens.find("lunge"), "U")
	await process_frame
	_require(_array_equals(game._key_slots["U"], ["U", "lunge"]), "rest editing can add lunge token to a key slot")
	var lunge_plan: Array = game._build_key_slot_plan(["lunge"])
	_require(lunge_plan.size() == 1 and lunge_plan[0].def.id == "lunge", "lunge token builds a lunge action")
	game._on_key_slot_preview_requested("U")
	await process_frame
	_require(game.state.preview_move_cells.has(Vector2i(3, 2)), "key slot preview shows chained movement")
	_require(game.state.preview_attack_cells.has(Vector2i(3, 1)), "key slot preview shows lunge attack range")
	game._on_key_slot_preview_cleared("U")
	await process_frame
	_require(game.state.preview_move_cells.is_empty(), "key slot preview clears movement cells")
	_require(game.state.preview_attack_cells.is_empty(), "key slot preview clears attack cells")
	var sweep_preview: Dictionary = game._build_key_slot_preview(["sweep"])
	_require(sweep_preview["attack_cells"].has(Vector2i(3, 2)), "sweep preview includes left arc cell")
	_require(sweep_preview["attack_cells"].has(Vector2i(4, 3)), "sweep preview includes forward arc cell")
	_require(sweep_preview["attack_cells"].has(Vector2i(3, 4)), "sweep preview includes right arc cell")
	game._on_rest_continue_requested()
	await process_frame
	_require(game.state.room_index == 1, "post-practice rest continues to second room")

	game.start_seeded_run("key-programming-test")
	await process_frame
	_require(game.state.map_node_kind == "rest", "run starts at camp")
	_require(game._key_program_editable, "camp unlocks key slot editing")
	_require(game.state.is_safe_training, "camp is a safe training sandbox")
	_require(_array_equals(game._key_slots["U"], ["U"]), "up key starts with up token")
	_require(_array_equals(game._key_slots["R"], ["R"]), "right key starts with right token")

	game._on_key_token_move_requested("R", 0, "U")
	await process_frame
	_require(game._key_slots["R"].is_empty(), "camp editing can empty right key slot")
	_require(_array_equals(game._key_slots["U"], ["U", "R"]), "camp editing can chain up then right")
	_move_player_to(game, Vector2i(3, 3))
	game._submit_key_chain("R")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(3, 3), "empty right key slot has no mapped movement in camp")
	game._submit_key_chain("U")
	await process_frame
	_require(game.state.player.grid_pos == Vector2i(4, 2), "camp sandbox can test chained up then right movement")

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
	_require(game._key_slots["R"].is_empty(), "combat keeps right key slot unchanged")
	_require(_array_equals(game._key_slots["U"], ["U", "R"]), "combat keeps up key slot unchanged")

	game.start_seeded_run("mid-rest-key-programming-test")
	await process_frame
	game._start_map_node(4)
	await process_frame
	_require(game.state.map_node_kind == "rest", "route has a rest node")
	_require(game._key_program_editable, "rest node unlocks key slot editing")

	game._on_key_token_move_requested("R", 0, "U")
	await process_frame
	_require(game._key_slots["R"].is_empty(), "rest editing can empty right key slot")
	_require(_array_equals(game._key_slots["U"], ["U", "R"]), "rest editing can chain up then right")

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

	await _start_seeded_combat_run(game, "impact-shield-single")
	var single_enemy = _prepare_single_enemy_room(game, Vector2i(2, 1), 10)
	var single_plan: Array = game._build_key_slot_plan(["R"])
	game.turn_controller.submit_player_plan(single_plan)
	await process_frame
	_require(single_plan[0].chain_speed == 1, "single movement collision has speed 1")
	_require(single_enemy.hp == 9, "speed 1 impact shield deals 1 damage")
	_require(single_enemy.grid_pos == Vector2i(3, 1), "speed 1 impact shield knocks enemy back 1 cell")
	_require(game.state.player.grid_pos == Vector2i(2, 1), "attacker enters collision cell after speed 1 impact")

	await _start_seeded_combat_run(game, "impact-shield-double")
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
	_require(achievement_service.is_unlocked("first_action_reward"), "action reward triggers achievement event")

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

func _start_run_at_first_combat(game) -> void:
	game.start_run()
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

func _prepare_single_enemy_room(game, enemy_cell: Vector2i, enemy_hp: int):
	game.enemy_planner.enemies_are_static = true
	_move_player_to(game, Vector2i(1, 1))

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

func _actor_has_modifier(actor, modifier_id: String) -> bool:
	if actor == null:
		return false
	for modifier in actor.effect_modifiers:
		if modifier != null and String(modifier.id) == modifier_id:
			return true
	return false
