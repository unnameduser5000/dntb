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
	main_menu.settings_requested.connect(_show_settings)
	main_menu.quit_requested.connect(_quit_game)
	settings_menu.back_requested.connect(_on_settings_back_requested)
	settings_menu.continue_requested.connect(_on_settings_continue_requested)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.settings_requested.connect(_show_settings_from_pause)
	pause_menu.menu_requested.connect(_show_main_menu)
	game.pause_menu_requested.connect(_show_pause_menu)
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
	game.set_game_visible(true)
	game.set_shell_overlay_active(false)
	game.start_run()


func _show_main_menu() -> void:
	_game_is_active = false
	_settings_return_to_pause = false
	game.set_game_visible(false)
	game.set_shell_overlay_active(true)
	_hide_all_shell_panels()
	main_menu.visible = true


func _show_settings() -> void:
	_settings_return_to_pause = false
	_hide_all_shell_panels()
	game.set_shell_overlay_active(true)
	settings_menu.refresh_controls()
	settings_menu.visible = true


func _show_pause_menu() -> void:
	_hide_all_shell_panels()
	game.set_game_visible(true)
	game.set_shell_overlay_active(true)
	pause_menu.visible = true


func _resume_game() -> void:
	_settings_return_to_pause = false
	_hide_all_shell_panels()
	game.set_shell_overlay_active(false)


func _show_settings_from_pause() -> void:
	_settings_return_to_pause = true
	_hide_all_shell_panels()
	game.set_game_visible(true)
	game.set_shell_overlay_active(true)
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


func _quit_game() -> void:
	get_tree().quit()
