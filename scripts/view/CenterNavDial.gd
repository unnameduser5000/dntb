class_name CenterNavDial
extends Control

var direction: Vector2 = Vector2.UP


func set_direction(new_direction: Vector2) -> void:
	if new_direction.length_squared() <= 0.001:
		direction = Vector2.UP
	else:
		direction = new_direction.normalized()
	queue_redraw()


func _draw() -> void:
	var rect := get_rect()
	var center := rect.size * 0.5
	var radius: float = minf(rect.size.x, rect.size.y) * 0.46
	var arrow_color := Color(1.0, 0.95, 0.68, 1.0)
	var arrow_shadow := Color(0.24, 0.18, 0.04, 0.85)

	var arrow_tip := center + direction * (radius * 0.72)
	var arrow_tail := center - direction * (radius * 0.18)
	var tangent := Vector2(-direction.y, direction.x)
	var head_left := arrow_tip - direction * (radius * 0.24) + tangent * (radius * 0.18)
	var head_right := arrow_tip - direction * (radius * 0.24) - tangent * (radius * 0.18)

	draw_line(arrow_tail + Vector2(0, 1), arrow_tip + Vector2(0, 1), arrow_shadow, 4.0, true)
	draw_colored_polygon(PackedVector2Array([arrow_tip + Vector2(0, 1), head_left + Vector2(0, 1), head_right + Vector2(0, 1)]), arrow_shadow)
	draw_line(arrow_tail, arrow_tip, arrow_color, 3.0, true)
	draw_colored_polygon(PackedVector2Array([arrow_tip, head_left, head_right]), arrow_color)
