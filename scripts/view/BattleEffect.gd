class_name BattleEffect
extends Node2D

@export_enum("action_started", "actor_damaged", "attack_missed", "move_collision", "actor_died") var effect_kind := "actor_damaged"
@export var duration: float = 0.2
@export var radius: float = 18.0
@export var line_width: float = 2.0
@export var primary_color: Color = Color(1.0, 0.82, 0.3, 1.0)
@export var secondary_color: Color = Color(1.0, 0.35, 0.3, 1.0)
@export var align_to_direction := false
@export var auto_play_on_ready := false

var _progress: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _intensity: float = 1.0
var _tint: Color = Color.WHITE


func _ready() -> void:
	if auto_play_on_ready:
		play({})


func play(meta: Dictionary = {}) -> void:
	_direction = _extract_direction(meta.get("direction", Vector2.RIGHT))
	_intensity = maxf(0.5, float(meta.get("intensity", 1.0)))
	var tint_value = meta.get("tint", Color.WHITE)
	_tint = tint_value if tint_value is Color else Color.WHITE
	visible = true
	scale = Vector2.ONE
	rotation = _direction.angle() if align_to_direction else 0.0
	_set_progress(0.0)

	var tween: Tween = create_tween()
	var effective_duration: float = maxf(0.01, duration * float(meta.get("duration_scale", 1.0)))
	tween.tween_method(_set_progress, 0.0, 1.0, effective_duration)
	tween.finished.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var main: Color = _tinted(primary_color, 1.0 - _progress)
	var accent: Color = _tinted(secondary_color, 1.0 - _progress * 0.9)
	var scale_factor: float = _intensity

	match effect_kind:
		"action_started":
			_draw_action_started(main, accent, scale_factor)
		"attack_missed":
			_draw_attack_missed(main, accent, scale_factor)
		"move_collision":
			_draw_move_collision(main, accent, scale_factor)
		"actor_died":
			_draw_actor_died(main, accent, scale_factor)
		_:
			_draw_actor_damaged(main, accent, scale_factor)


func _draw_action_started(main: Color, accent: Color, scale_factor: float) -> void:
	var pulse: float = lerpf(0.45, 1.05, _progress)
	var local_radius: float = radius * scale_factor * pulse
	draw_arc(Vector2.ZERO, local_radius * 0.68, -0.65, 0.65, 16, _with_alpha(accent, accent.a * 0.9), line_width)

	var tip := Vector2(local_radius, 0)
	var upper := tip + Vector2(-local_radius * 0.34, -local_radius * 0.28)
	var lower := tip + Vector2(-local_radius * 0.34, local_radius * 0.28)
	draw_line(upper, tip, main, line_width)
	draw_line(lower, tip, main, line_width)

	for index in range(2):
		var trail_x: float = -local_radius * (0.2 + index * 0.23)
		var trail_half: float = local_radius * (0.12 - index * 0.02)
		draw_line(Vector2(trail_x, -trail_half), Vector2(trail_x, trail_half), _with_alpha(main, main.a * (0.75 - index * 0.2)), maxf(1.0, line_width - index))


func _draw_actor_damaged(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.5, 1.25, _progress)
	draw_arc(Vector2.ZERO, local_radius * 0.75, 0.0, TAU, 24, main, line_width)

	for index in range(6):
		var angle: float = TAU * float(index) / 6.0 + _progress * 0.35
		var direction := Vector2.from_angle(angle)
		var inner: Vector2 = direction * (local_radius * 0.15)
		var outer: Vector2 = direction * (local_radius * (0.78 + (0.12 if index % 2 == 0 else 0.0)))
		draw_line(inner, outer, _with_alpha(accent, accent.a * (0.95 - float(index % 2) * 0.15)), line_width)

	draw_circle(Vector2.ZERO, local_radius * 0.16, _with_alpha(accent, accent.a * 0.65))


func _draw_attack_missed(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.55, 1.1, _progress)
	draw_arc(Vector2.ZERO, local_radius * 0.72, PI * 0.2, PI * 1.8, 18, _with_alpha(accent, accent.a * 0.8), line_width)

	var x_extent: float = local_radius * 0.5
	draw_line(Vector2(-x_extent, -x_extent), Vector2(x_extent, x_extent), main, line_width)
	draw_line(Vector2(-x_extent, x_extent), Vector2(x_extent, -x_extent), main, line_width)

	for index in range(2):
		var offset := Vector2(-local_radius * (0.2 + index * 0.25), 0)
		draw_line(offset + Vector2(0, -local_radius * 0.18), offset + Vector2(0, local_radius * 0.18), _with_alpha(accent, accent.a * (0.7 - index * 0.2)), maxf(1.0, line_width - index))


func _draw_move_collision(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.55, 1.35, _progress)
	draw_arc(Vector2.ZERO, local_radius * 0.8, 0.0, TAU, 24, main, line_width)

	for index in range(8):
		var angle: float = TAU * float(index) / 8.0
		var direction := Vector2.from_angle(angle)
		var inner: Vector2 = direction * (local_radius * 0.18)
		var outer: Vector2 = direction * (local_radius * (0.82 + (0.18 if index % 2 == 0 else 0.0)))
		draw_line(inner, outer, _with_alpha(accent, accent.a * (0.9 - float(index % 2) * 0.15)), maxf(1.0, line_width + (1.0 if index % 2 == 0 else 0.0)))

	draw_circle(Vector2.ZERO, local_radius * 0.2, _with_alpha(main, main.a * 0.75))


func _draw_actor_died(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.45, 1.15, _progress)
	var points: Array[Vector2] = [
		Vector2(0, -local_radius),
		Vector2(local_radius * 0.82, 0),
		Vector2(0, local_radius),
		Vector2(-local_radius * 0.82, 0),
	]
	for index in range(points.size()):
		var next_index: int = (index + 1) % points.size()
		draw_line(points[index], points[next_index], main, line_width)

	for index in range(4):
		var angle: float = PI * 0.25 + TAU * float(index) / 4.0
		var direction := Vector2.from_angle(angle)
		var shard_center: Vector2 = direction * local_radius * 0.72
		draw_circle(shard_center, local_radius * 0.12, _with_alpha(accent, accent.a * (0.95 - index * 0.12)))


func _extract_direction(raw_direction) -> Vector2:
	if raw_direction is Vector2:
		var direction_2d: Vector2 = raw_direction
		return direction_2d.normalized() if direction_2d.length_squared() > 0.0 else Vector2.RIGHT
	if raw_direction is Vector2i:
		var direction_2i: Vector2i = raw_direction
		var converted := Vector2(direction_2i.x, direction_2i.y)
		return converted.normalized() if converted.length_squared() > 0.0 else Vector2.RIGHT
	return Vector2.RIGHT


func _tinted(base_color: Color, alpha_scale: float) -> Color:
	var mixed: Color = base_color.lerp(_tint, 0.35)
	return _with_alpha(mixed, mixed.a * alpha_scale)


func _with_alpha(color_value: Color, alpha_value: float) -> Color:
	return Color(color_value.r, color_value.g, color_value.b, clampf(alpha_value, 0.0, 1.0))
