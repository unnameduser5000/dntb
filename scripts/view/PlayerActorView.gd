class_name PlayerActorView
extends "res://scripts/view/ActorView.gd"

@export var install_debug_frames_on_ready := true
static var _debug_player_frames_cache: SpriteFrames
static var _imported_player_clean_frames_cache: SpriteFrames
static var _imported_player_corrupted_frames_cache: SpriteFrames
@onready var facing_label: Label = $FacingLabel

const PLAYER_FRONT_01_PATH := "res://art/imported/characters/player/player_front_01.png"
const PLAYER_FRONT_02_PATH := "res://art/imported/characters/player/player_front_02.png"
const PLAYER_SIDE_01_PATH := "res://art/imported/characters/player/player_side_01.png"
const PLAYER_SIDE_02_PATH := "res://art/imported/characters/player/player_side_02.png"
const PLAYER_BACK_01_PATH := "res://art/imported/characters/player/player_back_01.png"
const PLAYER_BACK_02_PATH := "res://art/imported/characters/player/player_back_02.png"
const PLAYER_TEXTURE_BOX_SIZE := 40


func _ready() -> void:
	super()
	_ensure_visual_nodes()
	if install_debug_frames_on_ready and not _has_sprite_visual() and sprite != null:
		_ensure_imported_frames()
		sprite.sprite_frames = _imported_player_clean_frames_cache
		update_visual()


func update_visual() -> void:
	_ensure_imported_frames()
	if install_debug_frames_on_ready and sprite != null:
		sprite.sprite_frames = _imported_player_corrupted_frames_cache if _should_use_corrupted_visual() else _imported_player_clean_frames_cache
	super()
	if facing_label != null:
		facing_label.visible = false


func _sprite_tint(_actor_color: Color) -> Color:
	return Color.WHITE


func _apply_sprite_facing(animation_name: StringName) -> void:
	super._apply_sprite_facing(animation_name)
	if sprite == null:
		return
	var animation_label := String(animation_name)
	if animation_label.ends_with("_right"):
		sprite.flip_h = true
	elif animation_label.ends_with("_left"):
		sprite.flip_h = false


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


func _ensure_imported_frames() -> void:
	if _imported_player_clean_frames_cache == null:
		_imported_player_clean_frames_cache = _build_imported_player_frames(false)
	if _imported_player_corrupted_frames_cache == null:
		_imported_player_corrupted_frames_cache = _build_imported_player_frames(true)


func _build_imported_player_frames(use_corrupted_set: bool) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var front := _load_imported_texture(PLAYER_FRONT_02_PATH if use_corrupted_set else PLAYER_FRONT_01_PATH)
	var side := _load_imported_texture(PLAYER_SIDE_02_PATH if use_corrupted_set else PLAYER_SIDE_01_PATH)
	var back := _load_imported_texture(PLAYER_BACK_02_PATH if use_corrupted_set else PLAYER_BACK_01_PATH)
	_add_animation(frames, &"idle_down", [front], true, 4.0)
	_add_animation(frames, &"move_down", [front], true, 7.0)
	_add_animation(frames, &"action_start_down", [front], false, 10.0)
	_add_animation(frames, &"hit_down", [front], false, 10.0)
	_add_animation(frames, &"die_down", [front], false, 8.0)

	_add_animation(frames, &"idle_up", [back], true, 4.0)
	_add_animation(frames, &"move_up", [back], true, 7.0)
	_add_animation(frames, &"action_start_up", [back], false, 10.0)
	_add_animation(frames, &"hit_up", [back], false, 10.0)
	_add_animation(frames, &"die_up", [back], false, 8.0)

	_add_animation(frames, &"idle_right", [side], true, 4.0)
	_add_animation(frames, &"move_right", [side], true, 7.0)
	_add_animation(frames, &"action_start_right", [side], false, 10.0)
	_add_animation(frames, &"hit_right", [side], false, 10.0)
	_add_animation(frames, &"die_right", [side], false, 8.0)

	_add_animation(frames, &"idle_left", [side], true, 4.0)
	_add_animation(frames, &"move_left", [side], true, 7.0)
	_add_animation(frames, &"action_start_left", [side], false, 10.0)
	_add_animation(frames, &"hit_left", [side], false, 10.0)
	_add_animation(frames, &"die_left", [side], false, 8.0)
	return frames


func _should_use_corrupted_visual() -> bool:
	if actor_state == null:
		return false
	var max_san_value: int = maxi(1, int(actor_state.max_san))
	return int(actor_state.san) * 2 <= max_san_value


func _load_imported_texture(resource_path: String) -> Texture2D:
	if resource_path.is_empty():
		return null
	var texture: Texture2D = ResourceLoader.load(resource_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	return _texture_fitted_to_box(image, PLAYER_TEXTURE_BOX_SIZE)


func _texture_fitted_to_box(source_image: Image, box_size: int) -> Texture2D:
	if source_image == null or source_image.is_empty() or box_size <= 0:
		return null
	var working := source_image.duplicate()
	var max_dimension: int = maxi(working.get_width(), working.get_height())
	if max_dimension <= 0:
		return null
	var scale_ratio: float = minf(float(box_size) / float(max_dimension), 1.0)
	var scaled_size := Vector2i(
		maxi(1, int(round(float(working.get_width()) * scale_ratio))),
		maxi(1, int(round(float(working.get_height()) * scale_ratio)))
	)
	if scaled_size.x != working.get_width() or scaled_size.y != working.get_height():
		working.resize(scaled_size.x, scaled_size.y)
	var canvas := Image.create(box_size, box_size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var paste_position := Vector2i(
		int((box_size - scaled_size.x) / 2),
		int((box_size - scaled_size.y) / 2)
	)
	canvas.blit_rect(working, Rect2i(Vector2i.ZERO, scaled_size), paste_position)
	return ImageTexture.create_from_image(canvas)
