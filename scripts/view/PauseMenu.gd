class_name PauseMenu
extends Control

signal resume_requested
signal settings_requested
signal menu_requested

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	resume_button.pressed.connect(resume_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	menu_button.pressed.connect(menu_requested.emit)
