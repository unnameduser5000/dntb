class_name ActionNode
extends Resource

const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

@export var action: ActionDef
@export var chosen_dir: Vector2i = Vector2i.ZERO
@export var target_cell: Vector2i = Vector2i.ZERO
@export var key_id: String = ""


func build_instance(actor):
	if action == null:
		return null

	var instance = ActionInstanceScript.new()
	instance.actor = actor
	instance.def = action
	instance.chosen_dir = chosen_dir
	instance.target_cell = target_cell
	instance.key_id = key_id
	return instance


func get_display_name() -> String:
	if action == null:
		return "空行动"
	if not action.short_name.is_empty():
		return action.short_name
	return action.display_name
