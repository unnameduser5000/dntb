class_name UiKeyToken
extends Button

signal drop_requested(target_slot_id: String, drag_data: Dictionary)
signal interaction_blocked(source_slot_id: String)

var key_id: String = ""
var source_slot_id: String = ""
var source_index: int = -1
var editable: bool = true


func setup(
	new_key_id: String,
	new_source_slot_id: String,
	new_source_index: int,
	label: String,
	is_editable: bool = true,
	custom_tooltip: String = "",
	cell_size: Vector2 = Vector2(54, 36)
) -> void:
	key_id = new_key_id
	source_slot_id = new_source_slot_id
	source_index = new_source_index
	editable = is_editable
	text = label
	tooltip_text = custom_tooltip if not custom_tooltip.is_empty() else ("拖拽到按键槽里编排行动" if editable else "行动编码已锁定：只能在休息处调整")
	custom_minimum_size = cell_size
	theme_type_variation = &"ActionCard"
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


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
