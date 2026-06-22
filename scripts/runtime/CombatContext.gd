class_name CombatContext
extends RefCounted

var state
var action
var source
var target
var source_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var direction: Vector2i = Vector2i.ZERO
var speed: int = 1
var damage: int = 0
var chain_actions: Array = []
var tags: Array[String] = []


func setup_move_collision(new_state, new_action, new_source, new_target, new_direction: Vector2i, new_speed: int) -> void:
	state = new_state
	action = new_action
	source = new_source
	target = new_target
	source_cell = new_source.grid_pos
	target_cell = new_target.grid_pos
	direction = new_direction
	speed = maxi(1, new_speed)
	damage = 0
	chain_actions.clear()
	tags = ["move_collision"]


func setup_attack_hit(new_state, new_action, new_source, new_target, new_target_cell: Vector2i, new_direction: Vector2i, new_damage: int, new_speed: int) -> void:
	state = new_state
	action = new_action
	source = new_source
	target = new_target
	source_cell = new_source.grid_pos
	target_cell = new_target_cell
	direction = new_direction
	speed = maxi(1, new_speed)
	damage = maxi(0, new_damage)
	chain_actions.clear()
	tags = ["attack", "hit"]


func setup_attack_miss(new_state, new_action, new_source, new_target_cell: Vector2i, new_direction: Vector2i, new_speed: int) -> void:
	state = new_state
	action = new_action
	source = new_source
	target = null
	source_cell = new_source.grid_pos
	target_cell = new_target_cell
	direction = new_direction
	speed = maxi(1, new_speed)
	damage = 0
	chain_actions.clear()
	tags = ["attack", "miss"]


func setup_action_chain_finished(new_state, new_source, new_actions: Array) -> void:
	state = new_state
	source = new_source
	target = null
	source_cell = new_source.grid_pos
	target_cell = source_cell
	chain_actions = new_actions.duplicate()
	action = null
	direction = Vector2i.ZERO
	speed = 1
	damage = 0
	for chain_action in chain_actions:
		if chain_action == null:
			continue
		action = chain_action
		direction = chain_action.momentum_dir
		speed = maxi(1, int(chain_action.momentum_speed))
	tags = ["action_chain", "finished"]
