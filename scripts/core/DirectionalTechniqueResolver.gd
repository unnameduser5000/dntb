class_name DirectionalTechniqueResolver
extends RefCounted

## DirectionalTechniqueResolver is the thin bridge from editable input tokens
## to executable base actions.
##
## Current responsibility:
## - convert absolute direction tokens into move_key actions
## - convert control tokens such as F / turn into their base ActionDef
##
## Important boundary:
## - it does not recognize weapon techniques from KeyProgram
## - battle-time weapon-technique triggering happens later from ActionTrace,
##   after terrain/collision/effect changes have already shaped the real result

const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

const KEY_DIRECTIONS := {
	"U": Vector2i.UP,
	"D": Vector2i.DOWN,
	"L": Vector2i.LEFT,
	"R": Vector2i.RIGHT,
}
const TOKEN_ACTION_IDS := {
	"F": "move_forward",
	"TL": "turn_left",
	"TR": "turn_right",
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


## Input tokens remain absolute/user-facing here.
## Relative combo semantics are introduced later by ActionTrace, which records
## the executed result as F / B / SL / SR / TL / TR / J.
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
		action_def = move_key_action if action_id == "move_key" else action_by_id.get(action_id)
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
