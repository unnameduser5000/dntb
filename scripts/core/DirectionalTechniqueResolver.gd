class_name DirectionalTechniqueResolver
extends RefCounted

## DirectionalTechniqueResolver is the thin bridge from editable input tokens
## to executable base actions.
##
## Current responsibility:
## - convert absolute direction tokens into move_key actions
## - convert base-action tokens such as move / turn / attack / guard / wait /
##   jump into their base ActionDef
## - convert direct weapon tokens into their fixed attack ActionDef
##
## Important boundary:
## - the generic A token still resolves through the actor's equipped weapon
## - weapon tokens such as KNIFE resolve directly and do not depend on active
##   weapon state

const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

const KEY_DIRECTIONS := {
	"U": Vector2i.UP,
	"D": Vector2i.DOWN,
	"L": Vector2i.LEFT,
	"R": Vector2i.RIGHT,
}
const TOKEN_ACTION_IDS := {
	"F": "move_forward",
	"B": "move_back",
	"TL": "turn_left",
	"TR": "turn_right",
	"A": "attack",
	"KNIFE": "knife_attack",
	"IMPACT_SHIELD": "attack",
	"IRON_SPEAR": "charge_thrust",
	"GREATBLADE": "great_sweep",
	"I": "interact",
	"G": "guard",
	"W": "wait",
	"J": "jump",
}

var action_by_id: Dictionary = {}
var move_key_action: Resource


func setup(actions: Dictionary, direction_move_action: Resource) -> void:
	action_by_id = actions
	move_key_action = direction_move_action


func build_plan(token_ids: Array, actor) -> Array:
	var plan: Array = []
	for raw_token_id in token_ids:
		var spec: Dictionary = _build_spec(String(raw_token_id))
		if spec.is_empty():
			continue

		var action = _build_action_from_spec(spec, actor)
		if action != null:
			plan.append(action)
	return plan


func is_direction_token(token_id: String) -> bool:
	return KEY_DIRECTIONS.has(token_id)


func is_action_token(token_id: String) -> bool:
	return TOKEN_ACTION_IDS.has(token_id)


## Input tokens remain user-facing here.
## - U / D / L / R are absolute map directions
## - F / B / TL / TR / A / G / W / J are explicit base-action inputs
## - KNIFE / IMPACT_SHIELD / IRON_SPEAR / GREATBLADE are direct weapon inputs
## Relative trace semantics are introduced later by ActionTrace, which records
## the executed result as F / B / SL / SR / TL / TR / J / A / G / W.
func _build_spec(token_id: String) -> Dictionary:
	if is_direction_token(token_id):
		return {
			"action_id": "move_key",
			"chosen_dir": KEY_DIRECTIONS.get(token_id, Vector2i.ZERO),
			"token_id": token_id,
			"source": "direction_token",
		}

	if is_action_token(token_id):
		return {
			"action_id": String(TOKEN_ACTION_IDS.get(token_id, "")),
			"chosen_dir": Vector2i.ZERO,
			"token_id": token_id,
			"source": "action_token",
		}

	return {}


func _build_action_from_spec(spec: Dictionary, actor):
	var action_id := String(spec.get("action_id", ""))
	if action_id.is_empty():
		return null

	var action_def = spec.get("action_def")
	if action_def == null:
		action_def = _resolve_action_def(action_id, actor, String(spec.get("token_id", "")))
	if action_def == null:
		return null

	var action = ActionInstanceScript.new()
	action.actor = actor
	action.def = action_def
	# chosen_dir stays in world space here because U/D/L/R are absolute map
	# directions. Turn/jump tokens leave chosen_dir empty and rely on the action
	# definition plus current facing at resolve time.
	action.chosen_dir = spec.get("chosen_dir", Vector2i.ZERO)
	action.key_id = String(spec.get("token_id", action_id))
	return action


func _resolve_action_def(action_id: String, actor, token_id: String = ""):
	if action_id == "move_key":
		return move_key_action
	if token_id == "IMPACT_SHIELD":
		return action_by_id.get("attack")
	if action_id == "attack" and actor != null:
		var active_weapon = actor.get("active_weapon")
		if active_weapon != null:
			var weapon_attack = active_weapon.get("attack_action")
			if weapon_attack != null:
				return weapon_attack
	return action_by_id.get(action_id)
