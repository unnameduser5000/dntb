@tool
class_name UiToggleRow
extends VBoxContainer

@export var label_text := "选项":
	set(value):
		label_text = value
		_refresh_label()


func _ready() -> void:
	_refresh_label()


func _refresh_label() -> void:
	if not is_node_ready():
		return
	$Label.text = label_text
