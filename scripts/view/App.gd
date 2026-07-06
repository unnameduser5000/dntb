extends Node

## Application shell: navigation belongs here, while every visible layout lives
## in its own editable .tscn scene.

@onready var game = $Game
@onready var main_menu = $MenuLayer/MainMenu
@onready var settings_menu = $MenuLayer/SettingsMenu
@onready var pause_menu = $MenuLayer/PauseMenu

var _game_is_active := false
var _settings_return_to_pause := false


func _ready() -> void:
	main_menu.start_requested.connect(_start_new_game)
	main_menu.continue_requested.connect(_continue_saved_game)
	main_menu.settings_requested.connect(_show_settings)
	main_menu.quit_requested.connect(_quit_game)
	settings_menu.back_requested.connect(_on_settings_back_requested)
	settings_menu.continue_requested.connect(_on_settings_continue_requested)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.save_requested.connect(_save_game)
	pause_menu.save_and_menu_requested.connect(_save_game_and_return_to_menu)
	pause_menu.settings_requested.connect(_show_settings_from_pause)
	pause_menu.menu_requested.connect(_show_main_menu)
	game.pause_menu_requested.connect(_show_pause_menu)
	var save_service = get_node_or_null("/root/SaveService")
	if save_service != null:
		save_service.saved.connect(func(_slot: String, _path: String, _data: Dictionary) -> void:
			_refresh_main_menu_continue_state()
		)
		save_service.loaded.connect(func(_slot: String, _path: String, _data: Dictionary) -> void:
			_refresh_main_menu_continue_state()
		)
	_show_main_menu()


func _on_settings_continue_requested() -> void:
	if _settings_return_to_pause and _game_is_active:
		_resume_game()
		return
	if _game_is_active:
		_resume_game()
		return
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if settings_menu.visible:
		_on_settings_back_requested()
	elif pause_menu.visible:
		_resume_game()
	elif _game_is_active:
		_show_pause_menu()


func _start_new_game() -> void:
	_game_is_active = true
	_settings_return_to_pause = false
	_hide_all_shell_panels()
	game.set_game_visible(false)
	game.set_shell_overlay_active(false)
	game.start_run()


func _continue_saved_game() -> void:
	var save_service = get_node_or_null("/root/SaveService")
	if save_service == null or not save_service.has_save():
		_refresh_main_menu_continue_state()
		return
	_game_is_active = true
	_settings_return_to_pause = false
	_hide_all_shell_panels()
	game.set_game_visible(false)
	game.set_shell_overlay_active(false)
	var loaded: Dictionary = save_service.load_slot()
	if loaded.is_empty():
		_show_main_menu()
		return
	game.set_game_visible(true)
	game.set_shell_overlay_active(false)


func _show_main_menu() -> void:
	_game_is_active = false
	_settings_return_to_pause = false
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_duck_active(false)
	game.return_to_title()
	game.set_shell_overlay_active(true)
	_hide_all_shell_panels()
	_refresh_main_menu_continue_state()
	main_menu.visible = true


func _show_settings() -> void:
	_settings_return_to_pause = false
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_duck_active(true)
	_hide_all_shell_panels()
	game.set_shell_overlay_active(true)
	settings_menu.set_continue_button_visible(false)
	settings_menu.refresh_controls()
	settings_menu.visible = true


func _show_pause_menu() -> void:
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_duck_active(true)
	_hide_all_shell_panels()
	game.set_game_visible(true)
	game.set_shell_overlay_active(true)
	pause_menu.visible = true


func _resume_game() -> void:
	_settings_return_to_pause = false
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_duck_active(false)
	_hide_all_shell_panels()
	game.set_shell_overlay_active(false)


func _show_settings_from_pause() -> void:
	_settings_return_to_pause = true
	var audio_service = get_node_or_null("/root/AudioService")
	if audio_service != null:
		audio_service.set_duck_active(true)
	_hide_all_shell_panels()
	game.set_game_visible(true)
	game.set_shell_overlay_active(true)
	settings_menu.set_continue_button_visible(true)
	settings_menu.refresh_controls()
	settings_menu.visible = true


func _on_settings_back_requested() -> void:
	if _settings_return_to_pause and _game_is_active:
		_show_pause_menu()
		return
	_show_main_menu()


func _hide_all_shell_panels() -> void:
	main_menu.visible = false
	settings_menu.visible = false
	pause_menu.visible = false


func _refresh_main_menu_continue_state() -> void:
	var save_service = get_node_or_null("/root/SaveService")
	main_menu.set_continue_available(save_service != null and save_service.has_save())


func _save_game() -> void:
	_save_game_internal()


func _save_game_and_return_to_menu() -> void:
	if _save_game_internal():
		_show_main_menu()


func _save_game_internal() -> bool:
	if not _game_is_active:
		return false
	var save_service = get_node_or_null("/root/SaveService")
	if save_service == null:
		return false
	var error: Error = save_service.save_slot()
	return error == OK


func _quit_game() -> void:
	get_tree().quit()
