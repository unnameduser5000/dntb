class_name UiPoolDropCell
extends PanelContainer

signal drop_requested(target_slot_id: String, drag_data: Dictionary)

const KEY_POOL_ID := "POOL"

var editable: bool = true


func setup(is_editable: bool) -> void:
	editable = is_editable
	mouse_filter = Control.MOUSE_FILTER_STOP


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not editable:
		return false
	return typeof(data) == TYPE_DICTIONARY and data.has("key_id") and data.has("source_slot_id") and data.has("source_index")


func _drop_data(_at_position: Vector2, data) -> void:
	if not _can_drop_data(_at_position, data):
		return
	drop_requested.emit(KEY_POOL_ID, data)
