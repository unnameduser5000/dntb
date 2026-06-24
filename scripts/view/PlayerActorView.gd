class_name PlayerActorView
extends ActorView

@export var install_debug_frames_on_ready := true
static var _debug_player_frames_cache: SpriteFrames


func _ready() -> void:
	super()
	_ensure_visual_nodes()
	if install_debug_frames_on_ready and not _has_sprite_visual() and sprite != null:
		if _debug_player_frames_cache == null:
			_debug_player_frames_cache = _build_debug_player_frames()
		sprite.sprite_frames = _debug_player_frames_cache
		update_visual()


func _sprite_tint(_actor_color: Color) -> Color:
	return Color.WHITE


func _build_debug_player_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_animation(frames, &"idle", [
		_make_player_frame(Color(0.98, 0.99, 1.0, 1.0), Color(0.2, 0.85, 0.95, 1.0), 0),
		_make_player_frame(Color(0.98, 0.99, 1.0, 1.0), Color(0.2, 0.85, 0.95, 1.0), 1),
	], true, 5.0)
	_add_animation(frames, &"move", [
		_make_player_frame(Color(0.98, 0.99, 1.0, 1.0), Color(0.35, 0.95, 1.0, 1.0), 0),
		_make_player_frame(Color(0.98, 0.99, 1.0, 1.0), Color(0.35, 0.95, 1.0, 1.0), 2),
	], true, 10.0)
	_add_animation(frames, &"action_start", [
		_make_player_frame(Color(1.0, 0.98, 0.9, 1.0), Color(1.0, 0.82, 0.32, 1.0), 3),
		_make_player_frame(Color(1.0, 0.98, 0.9, 1.0), Color(1.0, 0.74, 0.18, 1.0), 4),
	], false, 12.0)
	_add_animation(frames, &"hit", [
		_make_player_frame(Color(1.0, 0.88, 0.88, 1.0), Color(1.0, 0.36, 0.3, 1.0), 5),
	], false, 12.0)
	_add_animation(frames, &"die", [
		_make_player_frame(Color(0.8, 0.82, 0.88, 1.0), Color(0.36, 0.48, 0.72, 1.0), 6),
		_make_player_frame(Color(0.62, 0.66, 0.75, 1.0), Color(0.18, 0.24, 0.4, 1.0), 7),
	], false, 8.0)
	return frames


func _add_animation(frames: SpriteFrames, animation_name: StringName, textures: Array[Texture2D], loop: bool, fps: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for texture in textures:
		if texture != null:
			frames.add_frame(animation_name, texture)


func _make_player_frame(primary: Color, accent: Color, variant: int) -> Texture2D:
	var width := 24
	var height := 24
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var center := Vector2i(10, 12)
	var bob_offset := -1 if variant in [1, 2, 4] else 0
	var body_top := center.y - 4 + bob_offset
	var body_bottom := center.y + 4 + bob_offset

	for y in range(body_top, body_bottom + 1):
		for x in range(center.x - 3, center.x + 2):
			image.set_pixel(x, y, primary)

	for y in range(body_top + 1, body_bottom):
		image.set_pixel(center.x - 4, y, accent.darkened(0.35))
		image.set_pixel(center.x + 2, y, accent.darkened(0.35))

	for y in range(center.y - 2 + bob_offset, center.y + 3 + bob_offset):
		for x in range(center.x + 1, center.x + 7):
			if abs(y - (center.y + bob_offset)) <= 1:
				image.set_pixel(x, y, accent)

	image.set_pixel(center.x + 7, center.y + bob_offset, accent.lightened(0.15))
	image.set_pixel(center.x + 8, center.y + bob_offset, Color.WHITE)
	image.set_pixel(center.x + 6, center.y - 1 + bob_offset, accent.lightened(0.15))
	image.set_pixel(center.x + 6, center.y + 1 + bob_offset, accent.lightened(0.15))

	image.set_pixel(center.x - 1, body_top - 2, accent)
	image.set_pixel(center.x, body_top - 3, accent.lightened(0.1))
	image.set_pixel(center.x + 1, body_top - 2, accent)

	var left_leg_x := center.x - 2
	var right_leg_x := center.x + 1
	if variant == 2:
		left_leg_x -= 1
		right_leg_x += 1
	elif variant == 6:
		left_leg_x += 1
		right_leg_x -= 1
	elif variant == 7:
		left_leg_x += 2
		right_leg_x += 1

	for y in range(body_bottom + 1, body_bottom + 5):
		image.set_pixel(left_leg_x, y, primary.darkened(0.15))
		image.set_pixel(right_leg_x, y, primary.darkened(0.15))

	if variant == 3:
		for x in range(center.x + 3, center.x + 9):
			image.set_pixel(x, center.y - 3 + bob_offset, accent.lightened(0.2))
	if variant == 4:
		for y in range(center.y - 4 + bob_offset, center.y + 1 + bob_offset):
			image.set_pixel(center.x + 5, y, accent.lightened(0.25))
	if variant == 5:
		for y in range(body_top - 1, body_bottom + 2):
			image.set_pixel(center.x - 5, y, Color(1, 0.4, 0.4, 0.55))
			image.set_pixel(center.x + 4, y, Color(1, 0.4, 0.4, 0.55))
	if variant >= 6:
		for x in range(center.x - 3, center.x + 7):
			image.set_pixel(x, body_bottom + 4, accent.darkened(0.45))

	return ImageTexture.create_from_image(image)
