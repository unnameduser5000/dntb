extends Node

## Autoload scene transition service.
## Godot nodes are scenes; this keeps scene flow out of gameplay scripts.

signal scene_changing(from_path: String, to_path: String)
signal scene_changed(scene_path: String)
signal scene_change_failed(scene_path: String, error: Error)

var current_scene_path: String = ""


func change_scene(scene_path: String) -> Error:
	if scene_path.is_empty():
		scene_change_failed.emit(scene_path, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER

	scene_changing.emit(current_scene_path, scene_path)
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		scene_change_failed.emit(scene_path, error)
		return error

	current_scene_path = scene_path
	scene_changed.emit(scene_path)
	return OK


func reload_current_scene() -> Error:
	if current_scene_path.is_empty() and get_tree().current_scene != null:
		current_scene_path = get_tree().current_scene.scene_file_path

	if current_scene_path.is_empty():
		return ERR_UNCONFIGURED

	return change_scene(current_scene_path)


func quit_game() -> void:
	get_tree().quit()
