class_name UiKeySlot
extends PanelContainer

signal key_dropped(target_slot_id: String, drag_data: Dictionary)
signal preview_requested(slot_id: String)
signal preview_cleared(slot_id: String)

var slot_id: String = ""
var editable: bool = true


func setup(new_slot_id: String, is_editable: bool = true) -> void:
	slot_id = new_slot_id
	editable = is_editable
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = &"ScreenPanel"
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not editable:
		return false
	return typeof(data) == TYPE_DICTIONARY and data.has("key_id") and data.has("source_slot_id") and data.has("source_index")


func _drop_data(_at_position: Vector2, data) -> void:
	if _can_drop_data(_at_position, data):
		key_dropped.emit(slot_id, data)


func _on_mouse_entered() -> void:
	preview_requested.emit(slot_id)


func _on_mouse_exited() -> void:
	preview_cleared.emit(slot_id)
