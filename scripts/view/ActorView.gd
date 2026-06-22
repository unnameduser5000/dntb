class_name ActorView
extends Node2D

var actor_state
var glyph: Label

func _ready() -> void:
	glyph = Label.new()
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.custom_minimum_size = Vector2(24, 24)
	add_child(glyph)

func bind(state) -> void:
	actor_state = state
	update_visual()

func update_visual() -> void:
	if actor_state == null or glyph == null:
		return
	glyph.text = actor_state.map_char()

func play_move(to_pos: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", to_pos, 0.12)

func play_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.35, 0.35), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)
