class_name SettingsMenu
extends Control

signal back_requested
signal continue_requested

const UiButtonScene := preload("res://scenes/ui/components/UiButton.tscn")

@onready var panel: Control = $Panel
@onready var scroll: ScrollContainer = %Scroll
@onready var resolution_option: OptionButton = %ResolutionRow.get_node("Option")
@onready var fullscreen_toggle: CheckButton = %FullscreenRow.get_node("Toggle")
@onready var zoom_option: OptionButton = %ZoomRow.get_node("Option")
@onready var controls_hint: Label = %ControlsHint
@onready var key_bindings_container: VBoxContainer = %KeyBindingsContainer
@onready var reset_bindings_button: Button = %ResetBindingsButton
@onready var continue_button: Button = %ContinueButton
@onready var back_button: Button = %BackButton

var _binding_buttons: Dictionary = {}
var _pending_rebind_action := ""


func _ready() -> void:
	for index in range(SettingsService.RESOLUTION_OPTIONS.size()):
		resolution_option.add_item(SettingsService.get_resolution_label(index), index)

	resolution_option.item_selected.connect(_on_resolution_selected)

	for index in range(SettingsService.WORLD_SLICE_ZOOM_OPTIONS.size()):
		zoom_option.add_item(SettingsService.get_world_slice_zoom_label(index), index)

	zoom_option.item_selected.connect(_on_zoom_selected)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	reset_bindings_button.pressed.connect(_reset_bindings)
	continue_button.pressed.connect(continue_requested.emit)
	back_button.pressed.connect(back_requested.emit)
	get_viewport().size_changed.connect(_update_layout)
	_build_key_binding_rows()
	_update_layout()
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
	zoom_option.select(SettingsService.world_slice_zoom_index)
	_refresh_key_binding_rows()
	scroll.scroll_vertical = 0


func set_continue_button_visible(visible: bool) -> void:
	continue_button.visible = visible


func _on_resolution_selected(index: int) -> void:
	SettingsService.set_resolution(index)


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsService.set_fullscreen(enabled)


func _on_zoom_selected(index: int) -> void:
	SettingsService.set_world_slice_zoom_index(index)


func _build_key_binding_rows() -> void:
	for child in key_bindings_container.get_children():
		child.queue_free()
	_binding_buttons.clear()

	var labels := {
		PlayerInputService.ACTION_Q: "Q 键 / Key Q",
		PlayerInputService.ACTION_W: "上 / Move Up",
		PlayerInputService.ACTION_E: "E 键 / Key E",
		PlayerInputService.ACTION_R: "R 键 / Key R",
		PlayerInputService.ACTION_A: "左 / Move Left",
		PlayerInputService.ACTION_S: "下 / Move Down",
		PlayerInputService.ACTION_D: "右 / Move Right",
		PlayerInputService.ACTION_F: "F 键 / Key F",
		PlayerInputService.ACTION_Z: "Z 键 / Key Z",
		PlayerInputService.ACTION_X: "X 键 / Key X",
		PlayerInputService.ACTION_C: "C 键 / Key C",
		PlayerInputService.ACTION_V: "V 键 / Key V",
	}

	for action_name in PlayerInputService.get_program_actions():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = labels.get(action_name, action_name)
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
		controls_hint.text = "默认布局为 QWER / ASDF / ZXCV，其中 WASD 默认控制上下左右。点击任意键位后再按新键即可改键。"
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


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var target_width := minf(500.0, viewport_size.x - 48.0)
	var target_height := minf(600.0, viewport_size.y - 48.0)
	var panel_size := Vector2(maxf(320.0, target_width), maxf(360.0, target_height))
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	scroll.custom_minimum_size = Vector2(0.0, maxf(180.0, panel_size.y - 240.0))
