class_name UiKeyToken
extends Button

signal drop_requested(target_slot_id: String, drag_data: Dictionary)
signal interaction_blocked(source_slot_id: String)

var key_id: String = ""
var source_slot_id: String = ""
var source_index: int = -1
var editable: bool = true
var adhesive := false
var permanently_disabled := false


func setup(
	new_key_id: String,
	new_source_slot_id: String,
	new_source_index: int,
	label: String,
	is_editable: bool = true,
	custom_tooltip: String = "",
	cell_size: Vector2 = Vector2(54, 36),
	is_adhesive: bool = false,
	is_permanently_disabled: bool = false
) -> void:
	key_id = new_key_id
	source_slot_id = new_source_slot_id
	source_index = new_source_index
	editable = is_editable
	adhesive = is_adhesive
	permanently_disabled = is_permanently_disabled
	text = label
	tooltip_text = custom_tooltip if not custom_tooltip.is_empty() else ("拖拽到按键槽里编排行动" if editable else "行动编码已锁定：只能在休息处调整")
	custom_minimum_size = cell_size
	theme_type_variation = &"ActionCard"
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if permanently_disabled:
		add_theme_stylebox_override("normal", _make_disabled_style(false))
		add_theme_stylebox_override("hover", _make_disabled_style(true))
		add_theme_stylebox_override("pressed", _make_disabled_style(true))
		add_theme_stylebox_override("focus", _make_disabled_style(true))
		add_theme_color_override("font_color", Color(1.0, 0.88, 0.9, 1.0))
	elif adhesive:
		add_theme_stylebox_override("normal", _make_adhesive_style(false))
		add_theme_stylebox_override("hover", _make_adhesive_style(true))
		add_theme_stylebox_override("pressed", _make_adhesive_style(true))
		add_theme_stylebox_override("focus", _make_adhesive_style(true))
		add_theme_color_override("font_color", Color(0.96, 0.9, 1.0, 1.0))
	else:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		remove_theme_stylebox_override("focus")
		remove_theme_color_override("font_color")
	_ensure_lock_badge()


func _get_drag_data(_at_position: Vector2):
	if not editable:
		interaction_blocked.emit(source_slot_id)
		return null
	if key_id.is_empty():
		return null

	var preview := Label.new()
	preview.text = text
	preview.theme = theme
	preview.theme_type_variation = &"QueueSlot"
	preview.custom_minimum_size = Vector2(54, 36)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	set_drag_preview(preview)

	return {
		"key_id": key_id,
		"source_slot_id": source_slot_id,
		"source_index": source_index,
	}


func _make_adhesive_style(is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.34, 0.16, 0.4, 0.98) if not is_hovered else Color(0.42, 0.2, 0.5, 0.98)
	style.border_color = Color(0.85, 0.46, 0.98, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.22, 0.06, 0.24, 0.62)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_disabled_style(is_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.08, 0.12, 0.99) if not is_hovered else Color(0.34, 0.1, 0.14, 0.99)
	style.border_color = Color(1.0, 0.32, 0.46, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.26, 0.04, 0.08, 0.78)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style


func _ensure_lock_badge() -> void:
	var existing := get_node_or_null("LockBadge") as Label
	if permanently_disabled:
		if existing == null:
			existing = Label.new()
			existing.name = "LockBadge"
			existing.position = Vector2(34, -4)
			existing.custom_minimum_size = Vector2(16, 16)
			existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			existing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
			existing.add_theme_font_size_override("font_size", 12)
			existing.add_theme_color_override("font_color", Color(1.0, 0.92, 0.96, 1.0))
			existing.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.05, 0.96))
			existing.add_theme_constant_override("outline_size", 2)
			add_child(existing)
		existing.text = "锁"
		existing.visible = true
	elif existing != null:
		existing.visible = false


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not editable:
		return false
	return typeof(data) == TYPE_DICTIONARY and data.has("key_id") and data.has("source_slot_id") and data.has("source_index")


func _drop_data(_at_position: Vector2, data) -> void:
	if not _can_drop_data(_at_position, data):
		return
	drop_requested.emit(source_slot_id, data)


func _gui_input(event: InputEvent) -> void:
	if editable:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			interaction_blocked.emit(source_slot_id)
