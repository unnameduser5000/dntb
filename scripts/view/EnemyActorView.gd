class_name EnemyActorView
extends "res://scripts/view/ActorView.gd"

var _installed_actor_def_id := ""
static var _debug_enemy_frames_cache: Dictionary = {}


func _ready() -> void:
	super()
	_ensure_visual_nodes()


func bind(state) -> void:
	_ensure_visual_nodes()
	_install_frames_for_state(state)
	super.bind(state)


func _install_frames_for_state(state) -> void:
	if sprite == null or state == null or state.def == null:
		return

	var actor_def_id := String(state.def.id)
	if actor_def_id == _installed_actor_def_id and _has_sprite_visual():
		return

	var cached_frames: SpriteFrames = _debug_enemy_frames_cache.get(actor_def_id)
	if cached_frames == null:
		cached_frames = _build_debug_enemy_frames(actor_def_id)
		_debug_enemy_frames_cache[actor_def_id] = cached_frames

	sprite.sprite_frames = cached_frames
	_installed_actor_def_id = actor_def_id


func _build_debug_enemy_frames(actor_def_id: String) -> SpriteFrames:
	var frames := SpriteFrames.new()

	match actor_def_id:
		"brute":
			_add_animation(frames, &"idle", [
				_make_brute_frame(0),
				_make_brute_frame(1),
			], true, 4.0)
			_add_animation(frames, &"move", [
				_make_brute_frame(2),
				_make_brute_frame(3),
			], true, 7.0)
			_add_animation(frames, &"action_start", [
				_make_brute_frame(4),
				_make_brute_frame(5),
			], false, 10.0)
			_add_animation(frames, &"hit", [
				_make_brute_frame(6),
			], false, 12.0)
			_add_animation(frames, &"die", [
				_make_brute_frame(7),
				_make_brute_frame(8),
			], false, 8.0)
		"boss":
			_add_animation(frames, &"idle", [
				_make_boss_frame(0),
				_make_boss_frame(1),
			], true, 4.0)
			_add_animation(frames, &"move", [
				_make_boss_frame(2),
				_make_boss_frame(3),
			], true, 7.0)
			_add_animation(frames, &"action_start", [
				_make_boss_frame(4),
				_make_boss_frame(5),
			], false, 10.0)
			_add_animation(frames, &"hit", [
				_make_boss_frame(6),
			], false, 12.0)
			_add_animation(frames, &"die", [
				_make_boss_frame(7),
				_make_boss_frame(8),
			], false, 8.0)
		_:
			_add_animation(frames, &"idle", [
				_make_slime_frame(0),
				_make_slime_frame(1),
			], true, 5.0)
			_add_animation(frames, &"move", [
				_make_slime_frame(2),
				_make_slime_frame(3),
			], true, 8.0)
			_add_animation(frames, &"action_start", [
				_make_slime_frame(4),
				_make_slime_frame(5),
			], false, 10.0)
			_add_animation(frames, &"hit", [
				_make_slime_frame(6),
			], false, 12.0)
			_add_animation(frames, &"die", [
				_make_slime_frame(7),
				_make_slime_frame(8),
			], false, 8.0)

	return frames


func _add_animation(frames: SpriteFrames, animation_name: StringName, textures: Array[Texture2D], loop: bool, fps: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for texture in textures:
		if texture != null:
			frames.add_frame(animation_name, texture)


func _make_slime_frame(variant: int) -> Texture2D:
	var image := _create_canvas()
	var center_x := 12
	var center_y := 14 + (-1 if variant in [1, 2, 4] else 0)
	var width_radius := 6 + (1 if variant == 3 else 0)
	var top_y := center_y - 5
	var bottom_y := center_y + 4
	var edge_color := Color(0.62, 0.62, 0.62, 1.0)
	var fill_color := Color(1, 1, 1, 1)
	var accent := Color(0.82, 0.82, 0.82, 1.0)

	for y in range(top_y, bottom_y + 1):
		var normalized: float = float(y - top_y) / maxf(float(bottom_y - top_y), 1.0)
		var inset: int = int(absf(0.5 - normalized) * 4.0)
		for x in range(center_x - width_radius + inset, center_x + width_radius - inset + 1):
			image.set_pixel(x, y, fill_color)
		image.set_pixel(center_x - width_radius + inset - 1, y, edge_color)
		image.set_pixel(center_x + width_radius - inset + 1, y, edge_color)

	for x in range(center_x - 3, center_x + 4):
		image.set_pixel(x, top_y - 1, accent)

	image.set_pixel(center_x - 2, center_y - 1, edge_color)
	image.set_pixel(center_x + 2, center_y - 1, edge_color)
	image.set_pixel(center_x - 2, center_y, Color.BLACK)
	image.set_pixel(center_x + 2, center_y, Color.BLACK)

	if variant in [4, 5]:
		for x in range(center_x + 2, center_x + 8):
			image.set_pixel(x, center_y - 3, accent)
	if variant == 6:
		for x in range(center_x - 7, center_x + 8):
			image.set_pixel(x, center_y + 1, Color(1, 0.5, 0.5, 0.55))
	if variant >= 7:
		for y in range(center_y + 4, center_y + 7):
			for x in range(center_x - 6, center_x + 7):
				if (x + y) % 2 == 0:
					image.set_pixel(x, y, edge_color.darkened(0.2))

	return ImageTexture.create_from_image(image)


func _make_brute_frame(variant: int) -> Texture2D:
	var image := _create_canvas()
	var body_color := Color(1, 1, 1, 1)
	var edge_color := Color(0.52, 0.52, 0.52, 1.0)
	var accent := Color(0.78, 0.78, 0.78, 1.0)
	var bob := -1 if variant in [1, 3, 5] else 0

	for y in range(7 + bob, 18 + bob):
		for x in range(7, 17):
			image.set_pixel(x, y, body_color)

	for y in range(6 + bob, 9 + bob):
		for x in range(9, 15):
			image.set_pixel(x, y, accent)

	for y in range(8 + bob, 17 + bob):
		image.set_pixel(6, y, edge_color)
		image.set_pixel(17, y, edge_color)

	for x in range(8, 16):
		image.set_pixel(x, 18 + bob, edge_color)

	image.set_pixel(10, 11 + bob, Color.BLACK)
	image.set_pixel(13, 11 + bob, Color.BLACK)

	var arm_shift := 0
	if variant in [4, 5]:
		arm_shift = 2
	for y in range(11 + bob, 16 + bob):
		image.set_pixel(5 + arm_shift, y, accent)
		image.set_pixel(18 + arm_shift, y, accent)

	var left_leg_x := 9
	var right_leg_x := 14
	if variant == 2:
		left_leg_x -= 1
		right_leg_x += 1
	elif variant == 7:
		left_leg_x += 1
		right_leg_x -= 1
	elif variant == 8:
		left_leg_x += 2
		right_leg_x += 1

	for y in range(19 + bob, 23):
		image.set_pixel(left_leg_x, y, edge_color)
		image.set_pixel(right_leg_x, y, edge_color)

	if variant == 6:
		for y in range(7 + bob, 18 + bob):
			image.set_pixel(4, y, Color(1, 0.5, 0.5, 0.55))
			image.set_pixel(19, y, Color(1, 0.5, 0.5, 0.55))
	if variant >= 7:
		for x in range(7, 17):
			image.set_pixel(x, 22, edge_color.darkened(0.25))

	return ImageTexture.create_from_image(image)


func _make_boss_frame(variant: int) -> Texture2D:
	var image := _create_canvas()
	var fill_color := Color(1, 1, 1, 1)
	var edge_color := Color(0.44, 0.44, 0.44, 1.0)
	var accent := Color(0.76, 0.76, 0.76, 1.0)
	var bob := -1 if variant in [1, 3, 5] else 0

	for y in range(7 + bob, 18 + bob):
		for x in range(8, 17):
			image.set_pixel(x, y, fill_color)

	for x in range(9, 16):
		image.set_pixel(x, 6 + bob, accent)
	image.set_pixel(10, 5 + bob, accent)
	image.set_pixel(12, 4 + bob, accent.lightened(0.1))
	image.set_pixel(14, 5 + bob, accent)

	for y in range(8 + bob, 17 + bob):
		image.set_pixel(7, y, edge_color)
		image.set_pixel(17, y, edge_color)

	image.set_pixel(10, 10 + bob, Color.BLACK)
	image.set_pixel(14, 10 + bob, Color.BLACK)
	for x in range(10, 15):
		image.set_pixel(x, 13 + bob, accent)

	var wing_offset := 0
	if variant in [4, 5]:
		wing_offset = 2
	for y in range(9 + bob, 15 + bob):
		image.set_pixel(5 + wing_offset, y, accent)
		image.set_pixel(19 + wing_offset, y, accent)
		if y % 2 == 0:
			image.set_pixel(4 + wing_offset, y, accent.lightened(0.1))
			image.set_pixel(20 + wing_offset, y, accent.lightened(0.1))

	var left_leg_x := 10
	var right_leg_x := 14
	if variant == 2:
		left_leg_x -= 1
		right_leg_x += 1
	elif variant == 7:
		left_leg_x += 1
		right_leg_x -= 1
	elif variant == 8:
		left_leg_x += 2
		right_leg_x += 1

	for y in range(18 + bob, 23):
		image.set_pixel(left_leg_x, y, edge_color)
		image.set_pixel(right_leg_x, y, edge_color)

	if variant == 6:
		for x in range(5, 21):
			image.set_pixel(x, 11 + bob, Color(1, 0.5, 0.5, 0.5))
	if variant >= 7:
		for x in range(8, 17):
			image.set_pixel(x, 22, edge_color.darkened(0.25))

	return ImageTexture.create_from_image(image)


func _create_canvas() -> Image:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image
