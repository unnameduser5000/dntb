extends Node2D

const BattleEffectControllerScript := preload("res://scripts/core/BattleEffectController.gd")
const DefaultActorViewScene := preload("res://scenes/actors/ActorView.tscn")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")
const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const BOSS_DEF := preload("res://data/actors/boss.tres")
const ACTION_ATTACK := preload("res://data/actions/attack.tres")

@export var cell_size: float = 56.0
@export var cell_gap: float = 14.0
@export var board_origin: Vector2 = Vector2(120, 128)
@export var board_width: int = 5
@export var board_height: int = 3
@export var demo_enabled := true
@export var demo_step_duration: float = 1.0

@onready var actor_root: Node2D = $ActorRoot
@onready var effect_root: Node2D = $EffectRoot
@onready var demo_timer: Timer = $DemoTimer
@onready var info_label: Label = $CanvasLayer/Overlay/InfoLabel
@onready var caption_root: Control = $CanvasLayer/Overlay/CaptionRoot

var _effect_controller = BattleEffectControllerScript.new()
var _entries: Array = []
var _entry_by_id: Dictionary = {}
var _demo_step: int = 0


func _ready() -> void:
	_effect_controller.setup(self, effect_root)
	_spawn_entries()
	_configure_overlay()
	_configure_demo_timer()
	queue_redraw()
	if demo_enabled:
		call_deferred("play_demo_step")


func grid_to_world(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x * (cell_size + cell_gap), cell.y * (cell_size + cell_gap))


func play_demo_step() -> void:
	_effect_controller.clear_effects()
	_reset_all_views()

	var variant_index: int = _demo_step % 2
	var action_direction: Vector2i = Vector2i.RIGHT if variant_index == 0 else Vector2i.DOWN
	var miss_cell: Vector2i = Vector2i(4, 0) if variant_index == 0 else Vector2i(4, 1)
	var collision_direction: Vector2i = Vector2i.RIGHT if variant_index == 0 else Vector2i.LEFT
	var action_speed: int = 2 + variant_index

	var player_entry: Dictionary = _entry_by_id.get("player", {})
	var slime_entry: Dictionary = _entry_by_id.get("slime", {})
	var brute_entry: Dictionary = _entry_by_id.get("brute", {})
	var boss_entry: Dictionary = _entry_by_id.get("boss", {})
	if player_entry.is_empty() or slime_entry.is_empty() or brute_entry.is_empty() or boss_entry.is_empty():
		return

	var player = player_entry["state"]
	var slime = slime_entry["state"]
	var brute = brute_entry["state"]
	var boss = boss_entry["state"]

	player.facing = action_direction
	slime.facing = Vector2i.LEFT if variant_index == 0 else Vector2i.UP
	brute.facing = collision_direction
	boss.facing = Vector2i.LEFT
	_rebind_all_views()

	var action = ActionInstanceScript.new()
	action.actor = player
	action.def = ACTION_ATTACK
	action.chosen_dir = action_direction
	action.momentum_dir = action_direction
	action.momentum_speed = action_speed
	action.chain_speed = action_speed

	_play_entry_view(player_entry, "play_action_start")
	_effect_controller.play_action_started(action)

	_play_entry_view(slime_entry, "play_hit")
	_effect_controller.play_frame({
		"kind": "actor_damaged",
		"actor": slime,
		"amount": 2 + variant_index,
	})

	_effect_controller.play_frame({
		"kind": "attack_missed",
		"target_cell": miss_cell,
		"direction": action_direction,
		"speed": action_speed,
	})

	_play_entry_view(brute_entry, "play_hit")
	_effect_controller.play_frame({
		"kind": "move_collision",
		"source": player,
		"target": brute,
		"target_cell": brute.grid_pos,
		"direction": collision_direction,
		"speed": action_speed,
	})

	_play_entry_view(boss_entry, "play_die")
	_effect_controller.play_frame({
		"kind": "actor_died",
		"actor": boss,
	})

	_demo_step += 1


func _draw() -> void:
	for y in range(board_height):
		for x in range(board_width):
			var cell := Vector2i(x, y)
			var top_left: Vector2 = grid_to_world(cell)
			var rect := Rect2(top_left, Vector2(cell_size, cell_size))
			draw_rect(rect, Color(0.24, 0.31, 0.39, 0.92), false, 2.0)
			var center: Vector2 = top_left + Vector2(cell_size * 0.5, cell_size * 0.5)
			draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), Color(0.5, 0.86, 0.95, 0.92), 2.0)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 7), Color(0.5, 0.86, 0.95, 0.92), 2.0)


func _spawn_entries() -> void:
	_clear_children(actor_root)
	_clear_children(caption_root)
	_entries.clear()
	_entry_by_id.clear()

	var specs: Array = [
		{
			"id": "player",
			"def": PLAYER_DEF,
			"cell": Vector2i(0, 0),
			"facing": Vector2i.RIGHT,
			"caption": "action_started / source",
		},
		{
			"id": "slime",
			"def": SLIME_DEF,
			"cell": Vector2i(2, 0),
			"facing": Vector2i.LEFT,
			"caption": "actor_damaged",
		},
		{
			"id": "brute",
			"def": BRUTE_DEF,
			"cell": Vector2i(1, 2),
			"facing": Vector2i.LEFT,
			"caption": "move_collision target",
		},
		{
			"id": "boss",
			"def": BOSS_DEF,
			"cell": Vector2i(3, 2),
			"facing": Vector2i.LEFT,
			"caption": "actor_died",
		},
	]

	for index in range(specs.size()):
		var spec: Dictionary = specs[index]
		var actor_state = ActorStateScript.new()
		actor_state.setup(index, spec["def"], spec["cell"])
		actor_state.facing = spec["facing"]

		var view: Node2D = _instantiate_actor_view(spec["def"])
		if view == null:
			continue

		var anchor: Vector2 = _cell_center(spec["cell"])
		view.position = anchor
		actor_root.add_child(view)
		if view.has_method("bind"):
			view.call("bind", actor_state)

		var entry := {
			"id": String(spec["id"]),
			"state": actor_state,
			"view": view,
			"cell": spec["cell"],
			"anchor": anchor,
			"base_scale": view.scale,
			"base_modulate": view.modulate,
		}
		_entries.append(entry)
		_entry_by_id[spec["id"]] = entry
		_add_caption_text("%s\n%s" % [String(spec["def"].id), String(spec["caption"])], anchor)

	_add_caption_text("attack_missed\nempty-cell anchor", _cell_center(Vector2i(4, 0)))


func _instantiate_actor_view(actor_def) -> Node2D:
	var actor_scene: PackedScene = DefaultActorViewScene
	if actor_def != null and actor_def.view_scene != null:
		actor_scene = actor_def.view_scene

	var instance = actor_scene.instantiate()
	if instance is Node2D:
		return instance

	if instance is Node:
		instance.free()

	if actor_scene != DefaultActorViewScene:
		var fallback = DefaultActorViewScene.instantiate()
		if fallback is Node2D:
			return fallback

	return null


func _configure_overlay() -> void:
	if info_label == null:
		return
	info_label.text = "Battle effect sandbox\nUses BattleEffectController + scenes/effects placeholder VFX on the same cell-anchor path as Game.\nCovers action_started / actor_damaged / attack_missed / move_collision / actor_died."


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


func _on_demo_timer_timeout() -> void:
	play_demo_step()


func _reset_all_views() -> void:
	for entry in _entries:
		var view: Node2D = entry["view"]
		if not is_instance_valid(view):
			continue
		view.position = entry["anchor"]
		view.scale = entry["base_scale"]
		view.modulate = entry["base_modulate"]
		view.visible = true
		if view.has_method("bind"):
			view.call("bind", entry["state"])


func _rebind_all_views() -> void:
	for entry in _entries:
		var view: Node2D = entry["view"]
		if is_instance_valid(view) and view.has_method("bind"):
			view.call("bind", entry["state"])


func _play_entry_view(entry: Dictionary, method_name: String) -> void:
	var view: Node2D = entry.get("view")
	if is_instance_valid(view) and view.has_method(method_name):
		view.call(method_name)


func _add_caption_text(text: String, anchor: Vector2) -> void:
	if caption_root == null:
		return

	var caption := Label.new()
	caption.position = anchor + Vector2(-64, cell_size * 0.68)
	caption.size = Vector2(128, 54)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = text
	caption_root.add_child(caption)


func _cell_center(cell: Vector2i) -> Vector2:
	return grid_to_world(cell) + Vector2(cell_size * 0.5, cell_size * 0.5)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
