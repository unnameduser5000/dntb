class_name ActorState
extends "res://scripts/runtime/GridItemState.gd"

var def
var facing: Vector2i = Vector2i.RIGHT
var hp: int = 1
var max_hp: int = 1
var san: int = 0
var max_san: int = 0
var atk: int = 1
var team: String = "enemy"
var drop_key: String = ""
var guarded: bool = false
var revealed: bool = true
var active_weapon: Resource
var effect_modifiers: Array = []

func setup(new_id: int, actor_def, start_cell: Vector2i) -> void:
	def = actor_def
	var item_kind := GridItemKind.ENEMY
	if actor_def.team == "player":
		item_kind = GridItemKind.PLAYER
	setup_grid_item(new_id, actor_def.id, item_kind, start_cell, true)
	display_name = actor_def.display_name
	max_hp = actor_def.max_hp
	hp = max_hp
	max_san = actor_def.max_san
	san = max_san
	atk = actor_def.atk
	team = actor_def.team
	drop_key = actor_def.default_drop_key
	active_weapon = actor_def.default_weapon
	effect_modifiers.clear()
	for modifier in actor_def.default_effect_modifiers:
		if modifier != null:
			effect_modifiers.append(modifier)
	tags.clear()
	tags.append(team)
	tags.append("actor")

func is_dead() -> bool:
	return hp <= 0

func map_char() -> String:
	if def == null:
		return "?"
	return def.map_char
