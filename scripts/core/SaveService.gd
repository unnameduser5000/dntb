extends Node

## Unified save entry point for gameplay systems.
## Systems register as providers and expose get_save_data()/load_save_data().

signal saved(slot: String, path: String, data: Dictionary)
signal loaded(slot: String, path: String, data: Dictionary)
signal save_failed(slot: String, error: Error)
signal load_failed(slot: String, error: Error)

const DEFAULT_SLOT := "default"
const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1

var _providers: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func register_provider(provider_id: String, provider: Object) -> void:
	if provider_id.is_empty() or provider == null:
		return
	_providers[provider_id] = provider


func unregister_provider(provider_id: String) -> void:
	_providers.erase(provider_id)


func Save(slot: String = DEFAULT_SLOT) -> Error:
	return save_slot(slot)


func Load(slot: String = DEFAULT_SLOT) -> Dictionary:
	return load_slot(slot)


func save_slot(slot: String = DEFAULT_SLOT) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var data := collect_save_data()
	var path := _slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var error := FileAccess.get_open_error()
		save_failed.emit(slot, error)
		return error

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	saved.emit(slot, path, data)
	return OK


func load_slot(slot: String = DEFAULT_SLOT) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		load_failed.emit(slot, ERR_FILE_NOT_FOUND)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		load_failed.emit(slot, error)
		return {}

	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_failed.emit(slot, ERR_PARSE_ERROR)
		return {}

	var data: Dictionary = parsed
	apply_save_data(data)
	loaded.emit(slot, path, data)
	return data


func collect_save_data() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"providers": {},
	}

	var providers: Dictionary = data["providers"]
	for provider_id in _providers.keys():
		var provider = _providers[provider_id]
		if not is_instance_valid(provider):
			continue
		if provider.has_method("get_save_data"):
			providers[provider_id] = provider.get_save_data()

	return data


func apply_save_data(data: Dictionary) -> void:
	var providers: Dictionary = {}
	var raw_providers = data.get("providers", {})
	if typeof(raw_providers) == TYPE_DICTIONARY:
		for provider_id in raw_providers.keys():
			providers[provider_id] = raw_providers[provider_id]
	for provider_id in providers.keys():
		var provider = _providers.get(provider_id)
		if not is_instance_valid(provider):
			continue
		if provider.has_method("load_save_data"):
			provider.load_save_data(providers[provider_id])


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: String = DEFAULT_SLOT) -> Error:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return OK

	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _slot_path(slot: String) -> String:
	var safe_slot := slot.strip_edges()
	if safe_slot.is_empty():
		safe_slot = DEFAULT_SLOT
	safe_slot = safe_slot.replace("/", "_").replace("\\", "_").replace(":", "_")
	return "%s/%s.json" % [SAVE_DIR, safe_slot]
