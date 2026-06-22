@tool
class_name AppBackground
extends Control

## A code-drawn background keeps the shell readable before the art direction is
## chosen. It can later be replaced by a texture, a shader, or a level backdrop
## without changing menu or settings layout.

@export var base_color := Color("10151e")
@export var grid_color := Color(0.42, 0.67, 0.79, 0.06)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), base_color)

	# Soft color fields give the temporary shell a little atmosphere while
	# remaining neutral enough for future themes.
	draw_circle(size * Vector2(0.16, 0.18), maxf(size.x, size.y) * 0.34, Color(0.10, 0.33, 0.43, 0.24))
	draw_circle(size * Vector2(0.82, 0.78), maxf(size.x, size.y) * 0.28, Color(0.34, 0.15, 0.36, 0.19))

	var spacing := 48.0
	for x in range(0, int(size.x) + int(spacing), int(spacing)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y) + int(spacing), int(spacing)):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)

	draw_line(Vector2(0, size.y * 0.74), Vector2(size.x, size.y * 0.42), Color(0.62, 0.86, 0.95, 0.10), 2.0)
