class_name ProbeWeaponDef
extends "res://scripts/data/WeaponDef.gd"

var hit_calls: int = 0
var miss_calls: int = 0
var chain_finished_calls: int = 0
var last_hit_speed: int = 0
var last_hit_damage: int = 0
var last_chain_speed: int = 0
var damage_bonus: int = 3


func resolve_attack_hit(context, resolver) -> bool:
	hit_calls += 1
	last_hit_speed = context.speed
	last_hit_damage = context.damage
	resolver.apply_damage(context.source, context.target, context.damage + damage_bonus, context.state)
	return true


func resolve_attack_miss(context, resolver) -> bool:
	miss_calls += 1
	resolver.add_state_message(context.state, "Probe weapon handled a miss at %s." % context.target_cell)
	return true


func resolve_action_chain_finished(context, resolver) -> void:
	chain_finished_calls += 1
	last_chain_speed = context.speed
	resolver.add_state_message(context.state, "Probe weapon observed chain speed %d." % context.speed)
