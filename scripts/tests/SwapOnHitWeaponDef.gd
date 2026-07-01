class_name SwapOnHitWeaponDef
extends "res://scripts/data/WeaponDef.gd"

var after_hit_calls: int = 0
var swapped_count: int = 0


func after_attack_hit(context, resolver) -> void:
	after_hit_calls += 1
	if context == null or context.source == null or context.target == null:
		return
	var packets: Array = resolver.apply_effect_swap(context.source, context.target, context.state, context.action, [&"after_hit_swap"])
	for packet in packets:
		if packet != null and bool(packet.metadata.get("swapped", false)):
			swapped_count += 1
