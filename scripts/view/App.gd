extends Node

## Application shell: navigation belongs here, while every visible layout lives
## in its own editable .tscn scene.

@onready var game = $Game
@onready var main_menu = $MenuLayer/MainMenu
@onready var settings_menu = $MenuLayer/SettingsMenu
@onready var pause_menu = $MenuLayer/PauseMenu

var _game_is_active := false


func _ready() -> void:
	main_menu.start_requested.connect(_start_new_game)
	main_menu.settings_requested.connect(_show_settings)
	main_menu.quit_requested.connect(_quit_game)
	settings_menu.back_requested.connect(_show_main_menu)
	pause_menu.resume_requested.connect(_resume_game)
	pause_menu.menu_requested.connect(_show_main_menu)
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if settings_menu.visible:
		_show_main_menu()
	elif pause_menu.visible:
		_resume_game()
	elif _game_is_active:
		_show_pause_menu()


func _start_new_game() -> void:
	_game_is_active = true
	_hide_all_shell_panels()
	game.set_game_visible(true)
	game.start_run()


func _show_main_menu() -> void:
	_game_is_active = false
	game.set_game_visible(false)
	_hide_all_shell_panels()
	main_menu.visible = true


func _show_settings() -> void:
	_hide_all_shell_panels()
	settings_menu.refresh_controls()
	settings_menu.visible = true


func _show_pause_menu() -> void:
	_hide_all_shell_panels()
	pause_menu.visible = true


func _resume_game() -> void:
	_hide_all_shell_panels()


func _hide_all_shell_panels() -> void:
	main_menu.visible = false
	settings_menu.visible = false
	pause_menu.visible = false


func _quit_game() -> void:
	get_tree().quit()
