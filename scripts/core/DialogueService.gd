extends Node

## DialogueManager plugin adapter.
## Keep story/tutorial triggers in game code; let the plugin handle dialogue runtime.

signal dialogue_started(resource_path: String, cue: String)
signal dialogue_failed(resource_path: String, reason: String)

const DEFAULT_BALLOON_SCENE_PATH := "res://addons/dialogue_manager/example_balloon/example_balloon.tscn"

var active_balloon: Node


func start_dialogue(resource_or_path, cue: String = "", extra_game_states: Array = [], balloon_scene: PackedScene = null) -> Node:
	if not is_plugin_available():
		dialogue_failed.emit(_resource_path(resource_or_path, null), "DialogueManager plugin autoload is not available. Enable the Dialogue Manager plugin in the editor.")
		return null

	var resource = _resolve_dialogue_resource(resource_or_path)
	var resource_path := _resource_path(resource_or_path, resource)
	if resource == null:
		dialogue_failed.emit(resource_path, "Dialogue resource not found.")
		return null

	var scene := balloon_scene
	if scene == null:
		scene = load(DEFAULT_BALLOON_SCENE_PATH) as PackedScene
	if scene == null:
		dialogue_failed.emit(resource_path, "Dialogue balloon scene not found.")
		return null

	var balloon := scene.instantiate()
	active_balloon = balloon

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(balloon)

	if balloon.has_method("start"):
		balloon.call("start", resource, cue, extra_game_states)
	else:
		dialogue_failed.emit(resource_path, "Balloon scene does not expose start().")
		balloon.queue_free()
		return null

	dialogue_started.emit(resource_path, cue)
	return balloon


func is_plugin_available() -> bool:
	return get_node_or_null("/root/DialogueManager") != null


func _resolve_dialogue_resource(resource_or_path):
	if resource_or_path is Resource:
		return resource_or_path
	if resource_or_path is String and not resource_or_path.is_empty():
		return load(resource_or_path)
	return null


func _resource_path(resource_or_path, resource) -> String:
	if resource_or_path is String:
		return resource_or_path
	if resource is Resource:
		return resource.resource_path
	return ""
