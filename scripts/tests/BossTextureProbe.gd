extends SceneTree

func _init() -> void:
	var boss_def = load("res://data/actors/boss.tres")
	print("boss def loaded: %s" % (boss_def != null))
	if boss_def != null:
		print("boss def id: %s" % boss_def.id)
		print("boss view_scene: %s" % boss_def.view_scene)

	var king_texture = ResourceLoader.load("res://art/imported/characters/enemies/enemy_king.png", "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	print("enemy_king texture loaded: %s" % (king_texture != null))
	if king_texture != null:
		var image: Image = king_texture.get_image()
		print("enemy_king image: %s, size: %s, empty: %s" % [image != null, image.get_size() if image != null else Vector2i.ZERO, image.is_empty() if image != null else true])

	var deity_texture = ResourceLoader.load("res://art/imported/characters/enemies/enemy_deity.png", "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	print("enemy_deity texture loaded: %s" % (deity_texture != null))

	var scene = load("res://scenes/actors/EnemyActorView.tscn")
	print("EnemyActorView scene loaded: %s" % (scene != null))
	if scene != null:
		var instance = scene.instantiate()
		print("instance Node2D: %s" % (instance is Node2D))
		if instance is Node2D and boss_def != null:
			var actor = load("res://scripts/runtime/ActorState.gd").new()
			actor.setup(1, boss_def, Vector2i.ZERO)
			if instance.has_method("bind"):
				instance.bind(actor)
				print("bind called")
				await create_timer(0.05).timeout
				var sprite = instance.get_node_or_null("AnimatedSprite2D")
				print("sprite: %s" % sprite)
				if sprite != null:
					print("sprite_frames: %s" % sprite.sprite_frames)
					if sprite.sprite_frames != null:
						print("animation names: %s" % sprite.sprite_frames.get_animation_names())
						print("current animation: %s" % sprite.animation)
						print("sprite visible: %s, modulate: %s" % [sprite.visible, sprite.modulate])
			instance.queue_free()

	print("BossTextureProbe done")
	quit()
