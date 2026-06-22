class_name UiKeyToken
extends Button

var key_id: String = ""
var source_slot_id: String = ""
var source_index: int = -1
var editable: bool = true


func setup(new_key_id: String, new_source_slot_id: String, new_source_index: int, label: String, is_editable: bool = true) -> void:
	key_id = new_key_id
	source_slot_id = new_source_slot_id
	source_index = new_source_index
	editable = is_editable
	text = label
	tooltip_text = "拖拽到按键槽里编排行动" if editable else "行动编码已锁定：只能在休息处调整"
	custom_minimum_size = Vector2(54, 36)
	theme_type_variation = &"ActionCard"
	disabled = not editable


func _get_drag_data(_at_position: Vector2):
	if not editable:
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
