class_name ActionTrace
extends RefCounted

var entries: Array = []
var max_entries: int = 24


func clear() -> void:
	entries.clear()


func append_entry(entry) -> void:
	if entry == null:
		return
	entries.append(entry)
	if max_entries > 0 and entries.size() > max_entries:
		entries = entries.slice(entries.size() - max_entries, entries.size())


func get_recent_entries(count: int = -1) -> Array:
	if count <= 0 or count >= entries.size():
		return entries.duplicate()
	return entries.slice(entries.size() - count, entries.size())


func get_recent_entries_for_actor(actor_id: int, count: int = -1) -> Array:
	var filtered: Array = []
	for entry in entries:
		if entry != null and int(entry.actor_id) == actor_id:
			filtered.append(entry)
	if count <= 0 or count >= filtered.size():
		return filtered
	return filtered.slice(filtered.size() - count, filtered.size())


func get_recent_symbols(count: int = -1) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in get_recent_entries(count):
		if entry == null:
			continue
		result.append(StringName(entry.symbol))
	return result


func get_recent_symbols_for_actor(actor_id: int, count: int = -1) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in get_recent_entries_for_actor(actor_id, count):
		if entry == null:
			continue
		result.append(StringName(entry.symbol))
	return result


func debug_string(count: int = -1) -> String:
	var parts: Array[String] = []
	for symbol in get_recent_symbols(count):
		parts.append(String(symbol))
	return " -> ".join(parts)


func debug_string_for_actor(actor_id: int, count: int = -1) -> String:
	var parts: Array[String] = []
	for symbol in get_recent_symbols_for_actor(actor_id, count):
		parts.append(String(symbol))
	return " -> ".join(parts)
