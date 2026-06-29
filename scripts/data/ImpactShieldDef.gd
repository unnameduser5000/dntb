class_name ImpactShieldDef
extends "res://scripts/data/WeaponDef.gd"

## ImpactShield converts move collisions into a weapon-specific impact package:
## 1. compute damage and knockback from chain speed
## 2. deal impact damage
## 3. if the target survives, apply knockback
## 4. if knockback fails, optionally apply wall-slam damage
## 5. optionally move the attacker into the collision cell
##
## This means chain speed is currently a shared bridge between:
## - base movement sequencing in TurnController
## - weapon-side collision payoff here

@export var damage_per_speed: int = 1
@export var base_damage: int = 0
@export var knockback_per_speed: int = 1
@export var max_knockback: int = 2
@export var wall_slam_damage: int = 1
@export var attacker_enters_target_cell: bool = true


func resolve_move_collision(context, resolver) -> bool:
	if context == null or context.source == null or context.target == null:
		return false

	# speed comes from TurnController chain preparation and currently measures
	# repeated executable world-space movement direction.
	var damage := maxi(1, base_damage + context.speed * damage_per_speed)
	var knockback_distance := mini(max_knockback, maxi(0, context.speed * knockback_per_speed))

	resolver.add_state_message(context.state, "%s用%s冲撞%s，速度 %d。" % [
		context.source.def.display_name,
		display_name,
		context.target.def.display_name,
		context.speed,
	])

	resolver.apply_effect_damage(context.source, context.target, damage, context.state, context.action, [&"impact", &"move_collision"])
	if context.target.is_dead():
		if attacker_enters_target_cell:
			resolver.apply_effect_move_to_cell(context.source, context.target_cell, context.state, context.action, [&"impact_enter"])
		return true

	var knockback_packets: Array = resolver.apply_effect_knockback(context.source, context.target, context.direction, knockback_distance, context.state, context.action, [&"impact", &"knockback"])
	var pushed: int = resolver.get_total_knockback_moved(knockback_packets)
	if pushed <= 0 and wall_slam_damage > 0:
		resolver.add_state_message(context.state, "%s被撞在障碍上。" % context.target.def.display_name)
		resolver.apply_effect_damage(context.source, context.target, wall_slam_damage, context.state, context.action, [&"impact", &"wall_slam"])

	if attacker_enters_target_cell and context.state.grid.can_enter(context.target_cell):
		resolver.apply_effect_move_to_cell(context.source, context.target_cell, context.state, context.action, [&"impact_enter"])

	return true
