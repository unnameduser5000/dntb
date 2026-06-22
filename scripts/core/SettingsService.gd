extends Node

## Application-wide preferences that must survive restarts.
## Keep gameplay preferences out of this service so the project can grow without
## turning this into a grab bag of unrelated state.

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTION_OPTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var resolution_index := 0
var is_fullscreen := false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error == OK:
		resolution_index = clampi(int(config.get_value("display", "resolution_index", 0)), 0, RESOLUTION_OPTIONS.size() - 1)
		is_fullscreen = bool(config.get_value("display", "fullscreen", false))
	else:
		resolution_index = _closest_resolution_index(DisplayServer.window_get_size())
		is_fullscreen = false

	apply_display_settings()


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
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var resolution: Vector2i = RESOLUTION_OPTIONS[resolution_index]
	DisplayServer.window_set_size(resolution)
	_center_window(resolution)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "fullscreen", is_fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Unable to save settings: %s" % error_string(error))


func _center_window(window_size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_usable_rect(screen).size
	var centered_position := (screen_size - window_size) / 2
	DisplayServer.window_set_position(Vector2i(maxi(0, centered_position.x), maxi(0, centered_position.y)))


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
