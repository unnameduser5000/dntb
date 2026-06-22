class_name ActionChain
extends Resource

const ActionNodeScript := preload("res://scripts/data/ActionNode.gd")

@export var id: String = ""
@export var display_name: String = ""
@export var nodes: Array = []


func build_plan(actor) -> Array:
	var plan: Array = []
	for node in nodes:
		if node == null:
			continue
		var instance = node.build_instance(actor)
		if instance != null:
			plan.append(instance)
	return plan


func action_ids() -> Array[String]:
	var result: Array[String] = []
	for node in nodes:
		if node != null and node.action != null:
			result.append(node.action.id)
	return result


func append_action(action: Resource, chosen_dir: Vector2i = Vector2i.ZERO, key_id: String = ""):
	var node = ActionNodeScript.new()
	node.action = action
	node.chosen_dir = chosen_dir
	node.key_id = key_id
	nodes.append(node)
	return node
