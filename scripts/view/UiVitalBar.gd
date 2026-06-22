@tool
class_name UiVitalBar
extends VBoxContainer

@export var label_text := "生命":
	set(value):
		label_text = value
		_refresh()

@export var current_value := 0:
	set(value):
		current_value = value
		_refresh()

@export var maximum_value := 100:
	set(value):
		maximum_value = maxi(1, value)
		_refresh()

@export var bar_theme_variant: StringName = &"VitalHealthBar":
	set(value):
		bar_theme_variant = value
		_refresh()


func _ready() -> void:
	_refresh()


func set_value(current: int, maximum: int) -> void:
	current_value = clampi(current, 0, maxi(1, maximum))
	maximum_value = maxi(1, maximum)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	$Header/Label.text = label_text
	$Header/Value.text = "%d / %d" % [current_value, maximum_value]
	$Bar.max_value = maximum_value
	$Bar.value = current_value
	$Bar.theme_type_variation = bar_theme_variant
