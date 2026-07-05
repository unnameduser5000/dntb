class_name BattleEffectController
extends RefCounted

const ActionStartedEffectScene := preload("res://scenes/effects/BattleActionStartedEffect.tscn")
const ActorDamagedEffectScene := preload("res://scenes/effects/BattleHitEffect.tscn")
const AttackMissedEffectScene := preload("res://scenes/effects/BattleMissEffect.tscn")
const MoveCollisionEffectScene := preload("res://scenes/effects/BattleImpactEffect.tscn")
const ActorDiedEffectScene := preload("res://scenes/effects/BattleDeathEffect.tscn")
const ComboTriggeredEffectScene := preload("res://scenes/effects/BattleComboEffect.tscn")
const TeleportEffectScene := preload("res://scenes/effects/BattleTeleportEffect.tscn")
const SwapEffectScene := preload("res://scenes/effects/BattleSwapEffect.tscn")
const SlimeBurstEffectScene := preload("res://scenes/effects/BattleSlimeBurstEffect.tscn")
const SlimeBindEffectScene := preload("res://scenes/effects/BattleSlimeBindEffect.tscn")

var board_view = null
var effect_root: Node = null
var effect_duration_scale: float = 1.0
var effect_scenes: Dictionary = {
	"action_started": ActionStartedEffectScene,
	"actor_damaged": ActorDamagedEffectScene,
	"attack_missed": AttackMissedEffectScene,
	"move_collision": MoveCollisionEffectScene,
	"actor_died": ActorDiedEffectScene,
	"combo_triggered": ComboTriggeredEffectScene,
	"teleport": TeleportEffectScene,
	"swap": SwapEffectScene,
	"slime_burst": SlimeBurstEffectScene,
	"slime_bind_hit": SlimeBindEffectScene,
}


func setup(board, root: Node) -> void:
	board_view = board
	effect_root = root


func clear_effects() -> void:
	if effect_root == null:
		return
	for child in effect_root.get_children():
		child.queue_free()


func set_effect_duration_scale(value: float) -> void:
	effect_duration_scale = maxf(0.1, value)


func play_action_started(action) -> void:
	if action == null or action.actor == null:
		return
	spawn_effect_world("action_started", _world_for_actor(action.actor), {
		"direction": action.actor.facing,
		"intensity": maxf(1.0, float(action.momentum_speed) * 0.2 + 1.0),
		"tint": _actor_color(action.actor),
	})


func play_frame(frame: Dictionary) -> void:
	if frame == null:
		return

	match String(frame.get("kind", "")):
		"actor_damaged":
			var damaged_actor = frame.get("actor")
			spawn_effect_world("actor_damaged", _world_for_actor(damaged_actor), {
				"direction": _actor_facing(damaged_actor),
				"intensity": 1.0 + float(frame.get("amount", 0)) * 0.12,
				"tint": _actor_color(damaged_actor),
			})
		"attack_missed":
			var miss_cell: Vector2i = frame.get("target_cell", Vector2i.ZERO)
			spawn_effect_world("attack_missed", _world_for_cell(miss_cell), {
				"direction": frame.get("direction", Vector2i.RIGHT),
				"intensity": 1.0 + float(frame.get("speed", 1)) * 0.08,
			})
		"move_collision":
			var collision_cell: Vector2i = frame.get("target_cell", Vector2i.ZERO)
			var collision_source = frame.get("source")
			spawn_effect_world("move_collision", _world_for_cell(collision_cell), {
				"direction": frame.get("direction", Vector2i.RIGHT),
				"intensity": 1.1 + float(frame.get("speed", 1)) * 0.14,
				"tint": _actor_color(collision_source),
			})
		"actor_died":
			var dead_actor = frame.get("actor")
			spawn_effect_world("actor_died", _world_for_actor(dead_actor), {
				"direction": _actor_facing(dead_actor),
				"intensity": 1.15,
				"tint": _actor_color(dead_actor),
			})
		"combo_triggered":
			var combo_actor = frame.get("actor")
			spawn_effect_world("combo_triggered", _world_for_actor(combo_actor), {
				"direction": frame.get("direction", _actor_facing(combo_actor)),
				"intensity": 1.15,
				"tint": _actor_color(combo_actor),
			})
		"teleport":
			var teleport_actor = frame.get("actor")
			spawn_effect_world("teleport", _world_for_actor(teleport_actor), {
				"direction": frame.get("direction", _actor_facing(teleport_actor)),
				"intensity": 1.0,
				"tint": _actor_color(teleport_actor),
			})
		"swap":
			var swap_actor = frame.get("actor")
			spawn_effect_world("swap", _world_for_actor(swap_actor), {
				"direction": frame.get("direction", _actor_facing(swap_actor)),
				"intensity": 1.1,
				"tint": _actor_color(swap_actor),
			})
		"slime_bind_hit":
			var bind_actor = frame.get("actor")
			var bind_target_cell: Vector2i = frame.get("target_cell", Vector2i.ZERO)
			spawn_effect_world("slime_bind_hit", _world_for_cell(bind_target_cell), {
				"direction": frame.get("direction", _actor_facing(bind_actor)),
				"intensity": 1.1,
				"tint": _actor_color(bind_actor),
				"source_world": _world_for_actor(bind_actor),
			})
		_:
			pass


func spawn_effect_world(effect_id: String, world_pos: Vector2, meta: Dictionary = {}) -> Node2D:
	if effect_root == null:
		return null

	var scene = effect_scenes.get(effect_id)
	if not (scene is PackedScene):
		return null

	var instance = scene.instantiate()
	if not (instance is Node2D):
		if instance is Node:
			instance.queue_free()
		return null

	var effect: Node2D = instance
	effect.position = world_pos
	effect_root.add_child(effect)
	if effect.has_method("set_duration_scale"):
		effect.call("set_duration_scale", effect_duration_scale)
	if effect.has_method("play"):
		effect.call("play", meta)
	return effect


func _world_for_actor(actor) -> Vector2:
	if actor == null:
		return Vector2.ZERO
	return _world_for_cell(actor.grid_pos)


func _world_for_cell(cell: Vector2i) -> Vector2:
	if board_view != null and board_view.has_method("grid_to_world"):
		var cell_size: float = float(board_view.cell_size)
		return board_view.grid_to_world(cell) + Vector2(cell_size * 0.5, cell_size * 0.5)
	return Vector2.ZERO


func _actor_facing(actor) -> Vector2i:
	if actor == null:
		return Vector2i.RIGHT
	return actor.facing


func _actor_color(actor) -> Color:
	if actor == null or actor.def == null:
		return Color.WHITE
	return actor.def.color
