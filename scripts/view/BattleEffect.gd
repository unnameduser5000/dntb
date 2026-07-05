class_name BattleEffect
extends Node2D

@export_enum("action_started", "actor_damaged", "attack_missed", "move_collision", "actor_died", "combo_triggered", "teleport", "swap", "slime_burst", "slime_bind_hit") var effect_kind := "actor_damaged"
@export var duration: float = 0.2
@export var radius: float = 18.0
@export var line_width: float = 2.0
@export var primary_color: Color = Color(1.0, 0.82, 0.3, 1.0)
@export var secondary_color: Color = Color(1.0, 0.35, 0.3, 1.0)
@export var align_to_direction := false
@export var auto_play_on_ready := false
@export var use_particle_burst := false
@export var particle_amount: int = 10

var _progress: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _intensity: float = 1.0
var _tint: Color = Color.WHITE
var _particle_burst: GPUParticles2D = null
var duration_scale: float = 1.0
static var _slime_effect_texture: Texture2D = null
var _source_world: Vector2 = Vector2.ZERO


func _ready() -> void:
	_ensure_particle_burst()
	if auto_play_on_ready:
		play({})


func play(meta: Dictionary = {}) -> void:
	_direction = _extract_direction(meta.get("direction", Vector2.RIGHT))
	_intensity = maxf(0.5, float(meta.get("intensity", 1.0)))
	var tint_value = meta.get("tint", Color.WHITE)
	_tint = tint_value if tint_value is Color else Color.WHITE
	var source_world_value = meta.get("source_world", Vector2.ZERO)
	_source_world = source_world_value if source_world_value is Vector2 else Vector2.ZERO
	visible = true
	scale = Vector2.ONE
	rotation = _direction.angle() if align_to_direction else 0.0
	_set_progress(0.0)
	_trigger_particle_burst()

	var tween: Tween = create_tween()
	var effective_duration: float = maxf(0.01, duration * duration_scale * float(meta.get("duration_scale", 1.0)))
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
		"combo_triggered":
			_draw_combo_triggered(main, accent, scale_factor)
		"teleport":
			_draw_teleport(main, accent, scale_factor)
		"swap":
			_draw_swap(main, accent, scale_factor)
		"slime_burst":
			_draw_slime_burst(main, accent, scale_factor)
		"slime_bind_hit":
			_draw_slime_bind_hit(main, accent, scale_factor)
		_:
			_draw_actor_damaged(main, accent, scale_factor)


func _ensure_particle_burst() -> void:
	if not use_particle_burst or _particle_burst != null:
		return
	var particles := GPUParticles2D.new()
	particles.name = "BurstParticles"
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.local_coords = false
	particles.amount = max(1, particle_amount)
	particles.lifetime = maxf(0.08, duration * duration_scale * 0.9)
	particles.visibility_rect = Rect2(-radius * 2.5, -radius * 2.5, radius * 5.0, radius * 5.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = maxf(1.0, radius * 0.12)
	process.direction = Vector3(0.0, 0.0, 1.0)
	process.spread = 180.0
	process.initial_velocity_min = maxf(14.0, radius * 0.9)
	process.initial_velocity_max = maxf(24.0, radius * 1.35)
	process.scale_min = 0.35
	process.scale_max = 0.8
	process.angular_velocity_min = -180.0
	process.angular_velocity_max = 180.0
	process.gravity = Vector3.ZERO
	process.linear_accel_min = -8.0
	process.linear_accel_max = 8.0
	process.damping_min = 8.0
	process.damping_max = 16.0
	process.color = secondary_color
	particles.process_material = process
	add_child(particles)
	_particle_burst = particles


func _trigger_particle_burst() -> void:
	if not use_particle_burst or _particle_burst == null:
		return
	_particle_burst.amount = max(1, int(round(float(particle_amount) * _intensity)))
	_particle_burst.modulate = _tinted(secondary_color, 0.95)
	_particle_burst.lifetime = maxf(0.05, duration * duration_scale * 0.9)
	_particle_burst.restart()
	_particle_burst.emitting = true


func set_duration_scale(value: float) -> void:
	duration_scale = maxf(0.1, value)
	if _particle_burst != null:
		_particle_burst.lifetime = maxf(0.05, duration * duration_scale * 0.9)


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


func _draw_combo_triggered(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.4, 1.2, _progress)
	draw_arc(Vector2.ZERO, local_radius * 0.9, -0.85, 0.85, 20, accent, line_width + 1.0)
	draw_arc(Vector2.ZERO, local_radius * 0.55, PI - 0.85, PI + 0.85, 20, main, line_width)
	var tip := Vector2(local_radius * 1.05, 0)
	draw_line(Vector2(-local_radius * 0.25, 0), tip, main, line_width)
	draw_line(tip + Vector2(-local_radius * 0.22, -local_radius * 0.18), tip, accent, line_width)
	draw_line(tip + Vector2(-local_radius * 0.22, local_radius * 0.18), tip, accent, line_width)


func _draw_teleport(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.35, 1.1, _progress)
	for index in range(3):
		var ring_alpha := 0.9 - float(index) * 0.2
		draw_arc(Vector2.ZERO, local_radius * (0.35 + float(index) * 0.22), 0.0, TAU, 24, _with_alpha(accent if index % 2 == 0 else main, ring_alpha), maxf(1.0, line_width - float(index) * 0.35))
	var slash_extent := local_radius * 0.7
	draw_line(Vector2(-slash_extent, -slash_extent), Vector2(slash_extent, slash_extent), main, line_width)
	draw_line(Vector2(-slash_extent * 0.4, slash_extent), Vector2(slash_extent, -slash_extent * 0.4), accent, line_width)


func _draw_swap(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.45, 1.15, _progress)
	var left_center := Vector2(-local_radius * 0.42, 0)
	var right_center := Vector2(local_radius * 0.42, 0)
	draw_circle(left_center, local_radius * 0.18, _with_alpha(main, main.a * 0.75))
	draw_circle(right_center, local_radius * 0.18, _with_alpha(accent, accent.a * 0.75))
	draw_arc(Vector2.ZERO, local_radius * 0.75, PI * 0.2, PI * 0.8, 18, main, line_width)
	draw_arc(Vector2.ZERO, local_radius * 0.75, PI * 1.2, PI * 1.8, 18, accent, line_width)
	var upper_tip := Vector2(local_radius * 0.3, -local_radius * 0.66)
	var lower_tip := Vector2(-local_radius * 0.3, local_radius * 0.66)
	draw_line(upper_tip + Vector2(-local_radius * 0.15, 0), upper_tip, main, line_width)
	draw_line(upper_tip + Vector2(0, local_radius * 0.15), upper_tip, main, line_width)
	draw_line(lower_tip + Vector2(local_radius * 0.15, 0), lower_tip, accent, line_width)
	draw_line(lower_tip + Vector2(0, -local_radius * 0.15), lower_tip, accent, line_width)


func _draw_slime_burst(main: Color, accent: Color, scale_factor: float) -> void:
	var local_radius: float = radius * scale_factor * lerpf(0.5, 1.2, _progress)
	var texture := _load_slime_effect_texture()
	if texture != null:
		var size: Vector2 = texture.get_size()
		var draw_scale: float = (local_radius * 2.0) / maxf(1.0, maxf(size.x, size.y))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * draw_scale)
		draw_texture(texture, -size * 0.5, _with_alpha(Color.WHITE, 1.0 - _progress * 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(Vector2.ZERO, local_radius * 0.82, 0.0, TAU, 20, _with_alpha(accent, 0.75 - _progress * 0.3), line_width)
	for index in range(5):
		var angle := TAU * float(index) / 5.0 + _progress * 0.45
		var direction := Vector2.from_angle(angle)
		draw_line(direction * (local_radius * 0.2), direction * local_radius, _with_alpha(main, 0.92 - float(index) * 0.1), line_width)


func _draw_slime_bind_hit(main: Color, accent: Color, scale_factor: float) -> void:
	var local_source: Vector2 = _source_world - global_position
	var pull_dir: Vector2 = local_source.normalized() if local_source.length_squared() > 0.001 else Vector2.LEFT
	var wave: float = sin(_progress * PI * 3.0) * radius * 0.12
	var tangent := Vector2(-pull_dir.y, pull_dir.x)
	var mid_point: Vector2 = local_source * 0.5 + tangent * wave
	draw_polyline(PackedVector2Array([local_source, mid_point, Vector2.ZERO]), _with_alpha(accent, 0.9), line_width + 2.0, true)
	draw_polyline(PackedVector2Array([local_source, mid_point, Vector2.ZERO]), _with_alpha(main, 0.95), line_width, true)
	draw_circle(Vector2.ZERO, radius * 0.18 * scale_factor, _with_alpha(main, 0.75))
	draw_circle(local_source, radius * 0.14 * scale_factor, _with_alpha(accent, 0.68))


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


func _load_slime_effect_texture() -> Texture2D:
	if _slime_effect_texture != null:
		return _slime_effect_texture
	var resource_path := "res://art/imported/characters/enemies/enemy_slime_effect.png"
	if not FileAccess.file_exists(resource_path):
		return null
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		return null
	_slime_effect_texture = ImageTexture.create_from_image(image)
	return _slime_effect_texture
