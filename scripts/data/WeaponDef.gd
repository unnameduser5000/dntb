class_name WeaponDef
extends Resource

## WeaponDef is the weapon-side rules surface for combat resolution.
## The combat flow resolves a base action first, then offers weapon hooks the
## corresponding CombatContext so the weapon can replace or extend that result.
##
## Current hook timing:
## - resolve_move_collision(): when a movement step collides with an enemy
## - resolve_attack_hit(): when an attack is about to deal direct hit damage
## - after_attack_hit(): after the attack hit is resolved, whether via weapon
##   replacement or base damage packets
## - resolve_attack_miss(): when an attack would otherwise miss
## - resolve_action_chain_finished(): after one actor finishes its whole chain
##
## weapon_technique_ids is the weapon-owned support list.
## Current combo availability is determined by the equipped weapon supporting a
## technique id. Future systems may add extra mastery / seal gates on top.
##
## combo_techniques is the ActionTrace pattern list for this weapon.
## WeaponComboResolver reads recent execution semantics from ActionTrace, picks
## the best-matching technique, and can then fire the technique's follow-up
## action without asking KeyProgram to contain "lunge" / "sweep" directly.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var weapon_technique_ids: Array[String] = []
@export var combo_techniques: Array = []


func resolve_move_collision(_context, _resolver) -> bool:
	return false


func resolve_attack_hit(_context, _resolver) -> bool:
	return false


func after_attack_hit(_context, _resolver) -> void:
	pass


func resolve_attack_miss(_context, _resolver) -> bool:
	return false


func resolve_action_chain_finished(_context, _resolver) -> void:
	pass


func supports_technique(technique_id: String) -> bool:
	return weapon_technique_ids.has(technique_id)
