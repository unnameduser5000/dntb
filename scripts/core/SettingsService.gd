extends Node

## Application-wide preferences that must survive restarts.
## Display settings live here; selected gameplay preferences that affect the
## overall experience (such as world-slice map zoom) also live here when they
## need to persist across sessions.

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var resolution_index := 0
var is_fullscreen := false

const WORLD_SLICE_ZOOM_OPTIONS := [1.0, 1.5, 2.0, 4.0]

signal world_slice_zoom_changed(index: int)
signal music_volume_changed(value: float)
signal sfx_volume_changed(value: float)

var world_slice_zoom_index := 1
var music_volume := 1.0
var sfx_volume := 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error == OK:
		resolution_index = clampi(int(config.get_value("display", "resolution_index", 0)), 0, RESOLUTION_OPTIONS.size() - 1)
		is_fullscreen = bool(config.get_value("display", "fullscreen", false))
		world_slice_zoom_index = clampi(
			int(config.get_value("gameplay", "world_slice_zoom_index", 1)),
			0,
			WORLD_SLICE_ZOOM_OPTIONS.size() - 1
		)
		music_volume = clampf(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
	else:
		resolution_index = _closest_resolution_index(DisplayServer.window_get_size())
		is_fullscreen = false
		world_slice_zoom_index = 1
		music_volume = 1.0
		sfx_volume = 1.0

	apply_display_settings()
	apply_audio_settings()


func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTION_OPTIONS.size() - 1)
	apply_display_settings()
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	apply_display_settings()
	save_settings()


func get_resolution_label(index: int) -> String:
	if index < 0 or index >= RESOLUTION_OPTIONS.size():
		return ""

	var resolution: Vector2i = RESOLUTION_OPTIONS[index]
	return "%d × %d" % [resolution.x, resolution.y]


func apply_display_settings() -> void:
	var resolution: Vector2i = RESOLUTION_OPTIONS[resolution_index]
	_apply_content_scale(resolution)

	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.window_set_size(resolution)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	_center_window(resolution)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.set_value("gameplay", "world_slice_zoom_index", world_slice_zoom_index)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Unable to save settings: %s" % error_string(error))


func apply_audio_settings() -> void:
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		if audio_service.has_method("set_bus_volume_linear"):
			audio_service.set_bus_volume_linear("Music", music_volume)
			audio_service.set_bus_volume_linear("SFX", sfx_volume)
	music_volume_changed.emit(music_volume)
	sfx_volume_changed.emit(sfx_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	save_settings()
	apply_audio_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()
	apply_audio_settings()


func get_music_volume() -> float:
	return music_volume


func get_sfx_volume() -> float:
	return sfx_volume


func _center_window(window_size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_usable_rect(screen).size
	var centered_position := (screen_size - window_size) / 2
	DisplayServer.window_set_position(Vector2i(maxi(0, centered_position.x), maxi(0, centered_position.y)))


func _apply_content_scale(resolution: Vector2i) -> void:
	var root := get_tree().root
	root.content_scale_size = resolution


func _closest_resolution_index(window_size: Vector2i) -> int:
	var best_index := 0
	var best_distance := INF
	for index in range(RESOLUTION_OPTIONS.size()):
		var candidate: Vector2i = RESOLUTION_OPTIONS[index]
		var distance := absf(candidate.x - window_size.x) + absf(candidate.y - window_size.y)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func set_world_slice_zoom_index(index: int) -> void:
	world_slice_zoom_index = clampi(index, 0, WORLD_SLICE_ZOOM_OPTIONS.size() - 1)
	save_settings()
	world_slice_zoom_changed.emit(world_slice_zoom_index)


func get_world_slice_zoom_label(index: int) -> String:
	if index < 0 or index >= WORLD_SLICE_ZOOM_OPTIONS.size():
		return ""
	return "%0.1fx" % WORLD_SLICE_ZOOM_OPTIONS[index]
