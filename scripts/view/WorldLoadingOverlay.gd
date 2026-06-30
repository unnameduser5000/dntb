class_name WorldLoadingOverlay
extends Control

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _progress_text: Label = %ProgressText


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide_loading()


func show_loading(title_text: String, body_text: String, progress_ratio: float = 0.0) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = title_text
	_body.text = body_text
	set_progress(progress_ratio)


func set_progress(progress_ratio: float, body_text: String = "") -> void:
	var normalized: float = clampf(progress_ratio, 0.0, 1.0)
	_progress_bar.value = normalized * 100.0
	_progress_text.text = "%d%%" % int(round(normalized * 100.0))
	if not body_text.is_empty():
		_body.text = body_text


func hide_loading() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.value = 0.0
	_progress_text.text = "0%"
