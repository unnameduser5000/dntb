@tool
class_name UiStatRow
extends HBoxContainer

@export var label_text := "数值":
	set(value):
		label_text = value
		_refresh_label()


func _ready() -> void:
	_refresh_label()


func _refresh_label() -> void:
	if not is_node_ready():
		return
	$Label.text = label_text
