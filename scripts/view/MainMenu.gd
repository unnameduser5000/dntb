class_name MainMenu
extends Control

signal start_requested
signal settings_requested
signal quit_requested

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var title_texture: TextureRect = $Panel/Margin/Content/TitleCenter/Title

const REFERENCE_VIEWPORT_HEIGHT: float = 1080.0
const TITLE_SCALE_AT_REFERENCE: float = 0.5


func _ready() -> void:
	start_button.pressed.connect(start_requested.emit)
	settings_button.pressed.connect(settings_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)

	get_tree().root.size_changed.connect(_update_title_scale)
	_update_title_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_title_scale.call_deferred()


func _update_title_scale() -> void:
	if title_texture == null or title_texture.texture == null:
		return
	var viewport_height: float = get_viewport_rect().size.y
	var scale_factor: float = (viewport_height / REFERENCE_VIEWPORT_HEIGHT) * TITLE_SCALE_AT_REFERENCE
	var source_size: Vector2 = title_texture.texture.get_size()
	var target_size: Vector2 = source_size * scale_factor
	title_texture.custom_minimum_size = target_size
	title_texture.size = target_size
