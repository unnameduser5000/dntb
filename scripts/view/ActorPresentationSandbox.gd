extends Node2D

const DefaultActorViewScene := preload("res://scenes/actors/ActorView.tscn")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")

const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const BOSS_DEF := preload("res://data/actors/boss.tres")

@export var cell_size: float = 64.0
@export var slot_spacing: float = 144.0
@export var start_position: Vector2 = Vector2(140, 170)
@export var demo_enabled := true
@export var demo_step_duration: float = 0.85

@onready var preview_root: Node2D = $PreviewRoot
@onready var demo_timer: Timer = $DemoTimer
@onready var info_label: Label = $CanvasLayer/Overlay/InfoLabel
@onready var caption_root: Control = $CanvasLayer/Overlay/CaptionRoot

var _entries: Array = []
var _demo_step := 0


func _ready() -> void:
	_spawn_previews()
	_configure_overlay()
	_configure_demo_timer()
	queue_redraw()


func _draw() -> void:
	for entry in _entries:
		var anchor: Vector2 = entry["anchor"]
		var rect := Rect2(anchor - Vector2(cell_size * 0.5, cell_size * 0.5), Vector2(cell_size, cell_size))
		draw_rect(rect, Color(0.28, 0.34, 0.42, 0.85), false, 2.0)
		draw_line(anchor + Vector2(-8, 0), anchor + Vector2(8, 0), Color(0.5, 0.86, 0.95, 0.9), 2.0)
		draw_line(anchor + Vector2(0, -8), anchor + Vector2(0, 8), Color(0.5, 0.86, 0.95, 0.9), 2.0)
		draw_arc(anchor, cell_size * 0.24, 0.0, TAU, 24, Color(0.16, 0.22, 0.28, 0.9), 2.0)


func _spawn_previews() -> void:
	_clear_preview_children()
	_entries.clear()

	var actor_defs: Array = [PLAYER_DEF, SLIME_DEF, BRUTE_DEF, BOSS_DEF]
	for index in range(actor_defs.size()):
		var actor_def = actor_defs[index]
		var actor_state = ActorStateScript.new()
		actor_state.setup(index, actor_def, Vector2i(index, 0))
		actor_state.facing = Vector2i.RIGHT if actor_def.team == "player" else Vector2i.LEFT

		var actor_scene: PackedScene = actor_def.view_scene if actor_def.view_scene != null else DefaultActorViewScene
		var instance = actor_scene.instantiate()
		if not (instance is Node2D):
			if instance is Node:
				instance.free()
			continue

		var anchor := start_position + Vector2(slot_spacing * index, 0)
		var view: Node2D = instance
		view.position = anchor
		preview_root.add_child(view)
		if view.has_method("bind"):
			view.call("bind", actor_state)

		_entries.append({
			"id": String(actor_def.id),
			"def": actor_def,
			"state": actor_state,
			"view": view,
			"anchor": anchor,
			"base_scale": view.scale,
			"base_modulate": view.modulate,
		})
		_add_caption(actor_def, anchor)


func _clear_preview_children() -> void:
	if preview_root != null:
		for child in preview_root.get_children():
			child.queue_free()
	if caption_root != null:
		for child in caption_root.get_children():
			child.queue_free()


func _configure_overlay() -> void:
	if info_label == null:
		return
	info_label.text = "Actor presentation sandbox\nCell cross = logic anchor / board center.\nUse negative Y view_offset to lift tall sprites while keeping their gameplay anchor centered.\nBoss now demonstrates a non-default offset/scale sample."


func _configure_demo_timer() -> void:
	if demo_timer == null:
		return
	demo_timer.stop()
	demo_timer.wait_time = demo_step_duration
	demo_timer.one_shot = false
	if not demo_timer.timeout.is_connected(_on_demo_timer_timeout):
		demo_timer.timeout.connect(_on_demo_timer_timeout)
	if demo_enabled:
		demo_timer.start()


func _add_caption(actor_def, anchor: Vector2) -> void:
	if caption_root == null or actor_def == null:
		return

	var caption := Label.new()
	caption.position = anchor + Vector2(-58, cell_size * 0.62)
	caption.size = Vector2(116, 78)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = "%s\nscale %.2f, %.2f\noffset %.0f, %.0f" % [
		String(actor_def.id),
		actor_def.view_scale.x,
		actor_def.view_scale.y,
		actor_def.view_offset.x,
		actor_def.view_offset.y,
	]
	caption_root.add_child(caption)


func _on_demo_timer_timeout() -> void:
	for entry in _entries:
		_reset_entry_view(entry)

	match _demo_step:
		0:
			pass
		1:
			_play_step("play_action_start")
		2:
			_play_step("play_hit")
		3:
			_play_move_step()
		4:
			_play_step("play_die")
		_:
			pass

	_demo_step = (_demo_step + 1) % 5


func _reset_entry_view(entry: Dictionary) -> void:
	var view: Node2D = entry["view"]
	if not is_instance_valid(view):
		return
	view.position = entry["anchor"]
	view.scale = entry["base_scale"]
	view.modulate = entry["base_modulate"]
	view.visible = true
	if view.has_method("bind"):
		view.call("bind", entry["state"])


func _play_step(method_name: String) -> void:
	for entry in _entries:
		var view: Node2D = entry["view"]
		if is_instance_valid(view) and view.has_method(method_name):
			view.call(method_name)


func _play_move_step() -> void:
	for entry in _entries:
		var view: Node2D = entry["view"]
		if not is_instance_valid(view):
			continue
		var anchor: Vector2 = entry["anchor"]
		var target := anchor + Vector2(14 if String(entry["id"]) == "player" else -14, 0)
		if view.has_method("play_move"):
			view.call("play_move", target)
		else:
			view.position = target
