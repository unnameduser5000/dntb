extends Node

## "Don't press that key" rule service.
## Tracks bans, pressure and curse triggers; gameplay decides what the penalty means.

signal key_banned(key_id: String, reason: String)
signal key_released(key_id: String)
signal curse_triggered(key_id: String, context: Dictionary)
signal pressure_changed(key_id: String, value: int)

var banned_keys: Dictionary = {}
var pressure: Dictionary = {}
var trigger_counts: Dictionary = {}


func _ready() -> void:
	var save_service = get_node_or_null("/root/SaveService")
	if save_service != null:
		save_service.register_provider("curses", self)


func reset_run() -> void:
	banned_keys.clear()
	pressure.clear()
	trigger_counts.clear()


func ban_key(key_id: String, reason: String = "", turns: int = -1) -> void:
	if key_id.is_empty():
		return

	banned_keys[key_id] = {
		"reason": reason,
		"remaining_turns": turns,
	}
	key_banned.emit(key_id, reason)


func release_key(key_id: String) -> void:
	if not banned_keys.has(key_id):
		return
	banned_keys.erase(key_id)
	key_released.emit(key_id)


func is_key_banned(key_id: String) -> bool:
	return banned_keys.has(key_id)


func get_ban_reason(key_id: String) -> String:
	return String(banned_keys.get(key_id, {}).get("reason", ""))


func register_key_pressed(key_id: String, context: Dictionary = {}) -> bool:
	if key_id.is_empty():
		return true

	if is_key_banned(key_id):
		trigger_counts[key_id] = int(trigger_counts.get(key_id, 0)) + 1
		add_pressure(key_id, 1)
		curse_triggered.emit(key_id, context)
		return false

	return true


func add_pressure(key_id: String, amount: int) -> int:
	var value := maxi(0, int(pressure.get(key_id, 0)) + amount)
	pressure[key_id] = value
	pressure_changed.emit(key_id, value)
	return value


func tick_turn() -> void:
	var to_release: Array[String] = []
	for key_id in banned_keys.keys():
		var data: Dictionary = banned_keys[key_id]
		var remaining := int(data.get("remaining_turns", -1))
		if remaining < 0:
			continue
		remaining -= 1
		data["remaining_turns"] = remaining
		banned_keys[key_id] = data
		if remaining <= 0:
			to_release.append(key_id)

	for key_id in to_release:
		release_key(key_id)


func get_save_data() -> Dictionary:
	return {
		"banned_keys": banned_keys,
		"pressure": pressure,
		"trigger_counts": trigger_counts,
	}


func load_save_data(data: Dictionary) -> void:
	banned_keys = data.get("banned_keys", {})
	pressure = data.get("pressure", {})
	trigger_counts = data.get("trigger_counts", {})
