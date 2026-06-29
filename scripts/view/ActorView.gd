class_name ActorView
extends Node2D

@export_node_path("AnimatedSprite2D") var sprite_node_path: NodePath
@export_node_path("Label") var glyph_node_path: NodePath

var actor_state
var glyph: Label
var sprite: AnimatedSprite2D
var _rest_scale: Vector2 = Vector2.ONE
var _rest_modulate: Color = Color.WHITE
var _rest_pose_captured := false
var _visual_defaults_captured := false
var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_glyph_position: Vector2 = Vector2.ZERO
var _base_glyph_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_capture_rest_pose()
	_ensure_visual_nodes()
	update_visual()

func bind(state) -> void:
	_capture_rest_pose()
	_ensure_visual_nodes()
	actor_state = state
	update_visual()

func update_visual() -> void:
	_ensure_visual_nodes()
	_apply_visual_layout()
	if actor_state == null:
		visible = false
		if sprite != null:
			sprite.visible = false
		if glyph != null:
			glyph.visible = true
			glyph.text = "?"
		return

	visible = bool(actor_state.revealed)
	if not visible:
		if sprite != null:
			sprite.visible = false
		if glyph != null:
			glyph.visible = false
		return

	var actor_color := _actor_color()
	var has_sprite_visual := _has_sprite_visual()

	if sprite != null:
		sprite.visible = has_sprite_visual
		sprite.self_modulate = _sprite_tint(actor_color)
		if has_sprite_visual:
			_play_idle_animation()

	if glyph != null:
		glyph.visible = not has_sprite_visual
		glyph.modulate = _glyph_tint(actor_color)
		glyph.text = _display_char()

func play_move(to_pos: Vector2) -> Tween:
	_play_first_available_animation([&"move"])
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", to_pos, 0.12)
	tween.finished.connect(func() -> void:
		_play_idle_animation()
	)
	return tween

func play_hit() -> Tween:
	_capture_rest_pose()
	_play_first_available_animation([&"hit", &"hurt"])
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.35, 0.35), 0.05)
	tween.tween_property(self, "modulate", _rest_modulate, 0.08)
	tween.finished.connect(func() -> void:
		_play_idle_animation()
	)
	return tween

func play_die() -> Tween:
	_capture_rest_pose()
	_play_first_available_animation([&"die", &"dead"])
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", _rest_scale * Vector2(1.12, 0.88), 0.04)
	tween.tween_property(self, "modulate", Color(_rest_modulate.r, _rest_modulate.g, _rest_modulate.b, 0), 0.12)
	return tween

func play_action_start() -> Tween:
	_capture_rest_pose()
	_play_first_available_animation([&"action_start", &"act", &"windup", &"attack"])
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", _rest_scale * Vector2(1.08, 1.08), 0.04)
	tween.tween_property(self, "scale", _rest_scale, 0.05)
	tween.finished.connect(func() -> void:
		_play_idle_animation()
	)
	return tween

func _display_char() -> String:
	if actor_state == null:
		return "?"
	if actor_state.team == "player":
		if actor_state.facing == Vector2i.UP:
			return "^"
		if actor_state.facing == Vector2i.DOWN:
			return "v"
		if actor_state.facing == Vector2i.LEFT:
			return "<"
		return ">"
	return actor_state.map_char()

func _ensure_visual_nodes() -> void:
	if sprite == null:
		sprite = _resolve_sprite()
	if glyph == null:
		glyph = _resolve_glyph()
	_capture_visual_defaults()

func _resolve_sprite() -> AnimatedSprite2D:
	var resolved = _node_from_path(sprite_node_path)
	if resolved is AnimatedSprite2D:
		return resolved

	var named_child = get_node_or_null("AnimatedSprite2D")
	if named_child is AnimatedSprite2D:
		return named_child

	var created := AnimatedSprite2D.new()
	created.name = "AnimatedSprite2D"
	created.centered = true
	add_child(created)
	return created

func _resolve_glyph() -> Label:
	var resolved = _node_from_path(glyph_node_path)
	if resolved is Label:
		return resolved

	var named_child = get_node_or_null("Glyph")
	if named_child is Label:
		return named_child

	var created := Label.new()
	created.name = "Glyph"
	created.mouse_filter = Control.MOUSE_FILTER_IGNORE
	created.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	created.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	created.size = Vector2(24, 24)
	created.custom_minimum_size = Vector2(24, 24)
	created.position = Vector2(-12, -12)
	add_child(created)
	return created

func _node_from_path(node_path: NodePath):
	if node_path.is_empty():
		return null
	return get_node_or_null(node_path)

func _capture_rest_pose() -> void:
	if _rest_pose_captured:
		return
	_rest_scale = scale
	_rest_modulate = modulate
	_rest_pose_captured = true

func _capture_visual_defaults() -> void:
	if _visual_defaults_captured:
		return
	if sprite != null:
		_base_sprite_position = sprite.position
		_base_sprite_scale = sprite.scale
	if glyph != null:
		_base_glyph_position = glyph.position
		_base_glyph_scale = glyph.scale
	_visual_defaults_captured = true

func _apply_visual_layout() -> void:
	var layout_offset := _actor_view_offset()
	var layout_scale := _actor_view_scale()
	if sprite != null:
		sprite.position = _base_sprite_position + layout_offset
		sprite.scale = Vector2(_base_sprite_scale.x * layout_scale.x, _base_sprite_scale.y * layout_scale.y)
	if glyph != null:
		glyph.position = _base_glyph_position + layout_offset
		glyph.scale = Vector2(_base_glyph_scale.x * layout_scale.x, _base_glyph_scale.y * layout_scale.y)

func _actor_color() -> Color:
	if actor_state == null or actor_state.def == null:
		return Color.WHITE
	return actor_state.def.color

func _actor_view_offset() -> Vector2:
	if actor_state == null or actor_state.def == null:
		return Vector2.ZERO
	return actor_state.def.view_offset

func _actor_view_scale() -> Vector2:
	if actor_state == null or actor_state.def == null:
		return Vector2.ONE
	return actor_state.def.view_scale

func _sprite_tint(actor_color: Color) -> Color:
	return actor_color

func _glyph_tint(actor_color: Color) -> Color:
	return actor_color

func _has_sprite_visual() -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.get_animation_names().size() > 0

func _play_idle_animation() -> void:
	if sprite == null or not _has_sprite_visual():
		return

	var idle_animation := _preferred_animation_name(&"idle")
	if idle_animation == &"":
		return

	sprite.play(idle_animation)
	_apply_sprite_facing(idle_animation)

func _play_first_available_animation(candidates: Array) -> bool:
	if sprite == null or not _has_sprite_visual():
		return false

	for candidate in candidates:
		var animation_name := _preferred_animation_name(StringName(candidate))
		if animation_name == &"":
			continue
		sprite.play(animation_name)
		_apply_sprite_facing(animation_name)
		return true

	return false

func _preferred_animation_name(base_name: StringName) -> StringName:
	if sprite == null or sprite.sprite_frames == null:
		return &""

	var directional_name := _directional_animation_name(base_name)
	if not directional_name.is_empty() and sprite.sprite_frames.has_animation(directional_name):
		return directional_name

	if sprite.sprite_frames.has_animation(base_name):
		return base_name

	if base_name == &"idle":
		var animation_names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if not animation_names.is_empty():
			return StringName(animation_names[0])

	return &""

func _directional_animation_name(base_name: StringName) -> StringName:
	if actor_state == null:
		return &""

	if actor_state.facing == Vector2i.UP:
		return StringName("%s_up" % String(base_name))
	if actor_state.facing == Vector2i.DOWN:
		return StringName("%s_down" % String(base_name))
	if actor_state.facing == Vector2i.LEFT:
		return StringName("%s_left" % String(base_name))
	if actor_state.facing == Vector2i.RIGHT:
		return StringName("%s_right" % String(base_name))
	return &""

func _apply_sprite_facing(animation_name: StringName) -> void:
	if sprite == null:
		return

	var animation_label := String(animation_name)
	var uses_directional_animation := animation_label.ends_with("_up") or animation_label.ends_with("_down") or animation_label.ends_with("_left") or animation_label.ends_with("_right")
	if uses_directional_animation:
		sprite.flip_h = false
		sprite.flip_v = false
		return

	sprite.flip_v = false
	if actor_state != null and actor_state.facing == Vector2i.LEFT:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
