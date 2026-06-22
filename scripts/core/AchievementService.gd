extends Node

signal achievement_unlocked(id: String, meta: Dictionary)
signal achievement_progressed(id: String, value: int, target: int)
signal achievement_event_recorded(event_id: String, meta: Dictionary)
signal achievement_registered(id: String)

const DEFAULT_ACHIEVEMENTS := [
	preload("res://data/achievements/rooms_cleared.tres"),
	preload("res://data/achievements/first_clear.tres"),
	preload("res://data/achievements/first_key.tres"),
	preload("res://data/achievements/first_modifier.tres"),
	preload("res://data/achievements/first_action_reward.tres"),
]

var _definitions: Dictionary = {}
var _unlocked: Dictionary = {}
var _progress: Dictionary = {}
var _event_counts: Dictionary = {}


func _ready() -> void:
	register_definitions(DEFAULT_ACHIEVEMENTS)
	var save_service = get_node_or_null("/root/SaveService")
	if save_service != null:
		save_service.register_provider("achievements", self)


func register_definitions(definitions: Array) -> void:
	for definition in definitions:
		register_definition(definition)


func register_definition(definition) -> void:
	if definition == null:
		return

	var achievement_id := String(definition.id)
	if achievement_id.is_empty():
		return

	_definitions[achievement_id] = definition
	achievement_registered.emit(achievement_id)


func record_event(event_id: String, meta: Dictionary = {}) -> Array[String]:
	var unlocked_ids: Array[String] = []
	if event_id.is_empty():
		return unlocked_ids

	_event_counts[event_id] = int(_event_counts.get(event_id, 0)) + 1
	achievement_event_recorded.emit(event_id, meta)

	for definition in _definitions.values():
		if definition == null or String(definition.trigger_event) != event_id:
			continue

		var achievement_id := String(definition.id)
		var unlocked := false
		if int(definition.target) <= 1:
			unlocked = unlock(achievement_id, meta)
		else:
			unlocked = add_progress(achievement_id, int(definition.progress_per_event), int(definition.target), meta)
		if unlocked:
			unlocked_ids.append(achievement_id)

	return unlocked_ids


func unlock(id: String, meta: Dictionary = {}) -> bool:
	if id.is_empty() or _unlocked.has(id):
		return false

	var definition = get_definition(id)
	var target := _target_for(id, 1)
	if definition != null:
		_progress[id] = target

	_unlocked[id] = {
		"unlocked_at_unix": Time.get_unix_time_from_system(),
		"meta": meta,
	}
	achievement_unlocked.emit(id, meta)
	return true


func add_progress(id: String, amount: int, target: int, meta: Dictionary = {}) -> bool:
	if is_unlocked(id):
		return false

	var resolved_target := _target_for(id, target)
	var value := int(_progress.get(id, 0)) + maxi(0, amount)
	_progress[id] = value
	achievement_progressed.emit(id, value, resolved_target)
	if value >= resolved_target:
		return unlock(id, meta)
	return false


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func get_definition(id: String):
	return _definitions.get(id)


func has_definition(id: String) -> bool:
	return _definitions.has(id)


func get_progress(id: String) -> int:
	return int(_progress.get(id, 0))


func get_target(id: String) -> int:
	return _target_for(id, 1)


func get_event_count(event_id: String) -> int:
	return int(_event_counts.get(event_id, 0))


func get_unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _unlocked.keys():
		result.append(String(id))
	return result


func get_achievement_status(id: String) -> Dictionary:
	var definition = get_definition(id)
	return {
		"id": id,
		"display_name": definition.display_name if definition != null else id,
		"description": definition.description if definition != null else "",
		"category": definition.category if definition != null else "general",
		"hidden": bool(definition.hidden) if definition != null else false,
		"points": int(definition.points) if definition != null else 0,
		"progress": get_progress(id),
		"target": get_target(id),
		"unlocked": is_unlocked(id),
		"unlock_data": _unlocked.get(id, {}),
	}


func get_all_status(include_hidden: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _definitions.keys():
		var status := get_achievement_status(String(id))
		if include_hidden or not bool(status.get("hidden", false)) or bool(status.get("unlocked", false)):
			result.append(status)
	return result


func reset_all() -> void:
	_unlocked.clear()
	_progress.clear()
	_event_counts.clear()


func get_save_data() -> Dictionary:
	return {
		"unlocked": _unlocked.duplicate(true),
		"progress": _progress.duplicate(true),
		"event_counts": _event_counts.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	var unlocked = data.get("unlocked", {})
	var progress = data.get("progress", {})
	var event_counts = data.get("event_counts", {})
	_unlocked = unlocked.duplicate(true) if typeof(unlocked) == TYPE_DICTIONARY else {}
	_progress = progress.duplicate(true) if typeof(progress) == TYPE_DICTIONARY else {}
	_event_counts = event_counts.duplicate(true) if typeof(event_counts) == TYPE_DICTIONARY else {}


func _target_for(id: String, fallback: int) -> int:
	var target := fallback
	var definition = get_definition(id)
	if definition != null:
		target = int(definition.target)
	return maxi(1, target)
