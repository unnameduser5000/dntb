class_name SettingsMenu
extends Control

signal back_requested

const UiButtonScene := preload("res://scenes/ui/components/UiButton.tscn")

@onready var resolution_option: OptionButton = $Panel/Margin/Content/ResolutionRow/Option
@onready var fullscreen_toggle: CheckButton = $Panel/Margin/Content/FullscreenRow/Toggle
@onready var controls_hint: Label = %ControlsHint
@onready var key_bindings_container: VBoxContainer = %KeyBindingsContainer
@onready var reset_bindings_button: Button = %ResetBindingsButton
@onready var back_button: Button = %BackButton

var _binding_buttons: Dictionary = {}
var _pending_rebind_action := ""


func _ready() -> void:
	for index in range(SettingsService.RESOLUTION_OPTIONS.size()):
		resolution_option.add_item(SettingsService.get_resolution_label(index), index)

	resolution_option.item_selected.connect(_on_resolution_selected)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	reset_bindings_button.pressed.connect(_reset_bindings)
	back_button.pressed.connect(back_requested.emit)
	_build_key_binding_rows()
	refresh_controls()


func _unhandled_input(event: InputEvent) -> void:
	if _pending_rebind_action.is_empty():
		return
	if not visible:
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_pending_rebind_action = ""
		refresh_controls()
		get_viewport().set_input_as_handled()
		return

	PlayerInputService.rebind_key(_pending_rebind_action, key_event.keycode)
	_pending_rebind_action = ""
	refresh_controls()
	get_viewport().set_input_as_handled()


func refresh_controls() -> void:
	resolution_option.select(SettingsService.resolution_index)
	fullscreen_toggle.set_pressed_no_signal(SettingsService.is_fullscreen)
	_refresh_key_binding_rows()


func _on_resolution_selected(index: int) -> void:
	SettingsService.set_resolution(index)


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsService.set_fullscreen(enabled)


func _build_key_binding_rows() -> void:
	for child in key_bindings_container.get_children():
		child.queue_free()
	_binding_buttons.clear()

	var labels := {
		PlayerInputService.ACTION_UP: "上 / Up",
		PlayerInputService.ACTION_DOWN: "下 / Down",
		PlayerInputService.ACTION_LEFT: "左 / Left",
		PlayerInputService.ACTION_RIGHT: "右 / Right",
	}

	for action_name in PlayerInputService.MOVE_ACTIONS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = labels[action_name]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.theme_type_variation = &"FieldLabel"
		row.add_child(label)

		var button := UiButtonScene.instantiate() as Button
		button.custom_minimum_size = Vector2(140, 40)
		button.pressed.connect(_begin_rebind.bind(action_name))
		row.add_child(button)

		_binding_buttons[action_name] = button
		key_bindings_container.add_child(row)


func _refresh_key_binding_rows() -> void:
	if not is_node_ready():
		return

	if _pending_rebind_action.is_empty():
		controls_hint.text = "WASD 默认控制上下左右。点击方向按钮后按下新按键即可改键。"
	else:
		controls_hint.text = "请按下新的按键；按 Esc 取消。"

	for action_name in _binding_buttons.keys():
		var button: Button = _binding_buttons[action_name]
		if action_name == _pending_rebind_action:
			button.text = "按新键..."
		else:
			button.text = PlayerInputService.get_binding_label(action_name)


func _begin_rebind(action_name: String) -> void:
	_pending_rebind_action = action_name
	refresh_controls()


func _reset_bindings() -> void:
	_pending_rebind_action = ""
	PlayerInputService.reset_bindings()
	refresh_controls()
