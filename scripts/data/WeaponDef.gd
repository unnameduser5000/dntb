class_name WeaponDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""


func resolve_move_collision(_context, _resolver) -> bool:
	return false


func resolve_attack_hit(_context, _resolver) -> bool:
	return false


func resolve_attack_miss(_context, _resolver) -> bool:
	return false


func resolve_action_chain_finished(_context, _resolver) -> void:
	pass
