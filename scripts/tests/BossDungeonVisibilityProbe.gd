extends SceneTree

const GameScene := preload("res://scenes/game/Game.tscn")

func _init() -> void:
	var game = GameScene.instantiate()
	root.add_child(game)
	await process_frame

	# Reach the boss node via rest-continue like SmokeTest does.
	await _start_run_at_first_combat(game)
	game._on_battle_finished(true)
	await process_frame
	game._on_reward_chosen(0)
	await process_frame
	game._on_rest_continue_requested()
	await process_frame

	print("=== Boss Dungeon Visibility Probe ===")
	print("map_node_kind: %s" % game.state.map_node_kind)
	print("is_world_slice: %s" % game.state.is_world_slice)
	print("player pos: %s" % game.state.player.grid_pos)
	print("fov_radius: %s" % game.state.fov_radius)
	print("visible_cell_set size: %s" % game.state.visible_cell_set.size())
	print("explored_cell_set size: %s" % game.state.explored_cell_set.size())

	var boss_actor = null
	for actor in game.state.actors:
		if actor != null and actor.team == "enemy" and String(actor.def.id) == "boss":
			boss_actor = actor
			break

	print("boss actor found: %s" % (boss_actor != null))
	if boss_actor != null:
		print("boss pos: %s" % boss_actor.grid_pos)
		print("boss revealed: %s" % boss_actor.revealed)
		print("boss in visible_cell_set: %s" % game.state.visible_cell_set.has(boss_actor.grid_pos))
		print("boss in explored_cell_set: %s" % game.state.explored_cell_set.has(boss_actor.grid_pos))
		print("boss dist to player: %s" % boss_actor.grid_pos.distance_to(game.state.player.grid_pos))

	if game._battle_presentation != null:
		print("actor_views count: %s" % game._battle_presentation.actor_views.size())
		for actor_id in game._battle_presentation.actor_views.keys():
			var view = game._battle_presentation.actor_views[actor_id]
			print("view %s visible=%s position=%s modulate=%s scale=%s" % [actor_id, view.visible, view.position, view.modulate, view.scale])
			var sprite = view.get_node_or_null("AnimatedSprite2D")
			if sprite != null:
				print("  sprite visible=%s self_modulate=%s modulate=%s scale=%s sprite_frames=%s current=%s" % [sprite.visible, sprite.self_modulate, sprite.modulate, sprite.scale, sprite.sprite_frames != null, sprite.animation])
				if sprite.sprite_frames != null:
					print("  animation names: %s" % sprite.sprite_frames.get_animation_names())

	if game.board_view != null:
		print("board_view position: %s" % game.board_view.position)
		print("board_view scale: %s" % game.board_view.scale)
		print("board_view render window origin: %s" % game.board_view.get_render_window_origin())
		print("board_view render window size: %s" % game.board_view.get_render_window_size())
		if boss_actor != null:
			print("boss in render window: %s" % game.board_view.is_cell_in_render_window(boss_actor.grid_pos))

	print("=== Done ===")
	quit()


func _start_run_at_first_combat(game) -> void:
	game._run_seed = "boss_visibility_test"
	game._run_player_max_hp = 20
	game._run_player_hp = 20
	game._run_player_max_san = 20
	game._run_player_san = 20
	game._run_player_atk = 3
	game.start_run()
	await process_frame
	while game.state == null or String(game.state.map_node_kind) != "combat":
		await process_frame
