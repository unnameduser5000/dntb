class_name NeonLightColumns
extends Control

## Music-reactive neon light columns for the main menu.
## Sits between the background and the menu panel.

@export var column_width: float = 24.0
@export var column_gap: float = 12.0
@export var max_height_ratio: float = 0.55
@export var rise_speed: float = 18.0
@export var fall_speed: float = 8.0
@export var base_alpha: float = 0.22
@export var min_db: float = -80.0
@export var max_db: float = -12.0
@export var neon_colors: Array[Color] = [
	Color(0.18, 0.92, 1.0),
	Color(0.92, 0.25, 0.78),
	Color(1.0, 0.45, 0.18),
	Color(0.35, 0.75, 1.0),
]

var _columns: Array[ColorRect] = []
var _energies: Array[float] = []
var _spectrum: AudioEffectSpectrumAnalyzerInstance = null
var _shader_material: ShaderMaterial = null
var _column_count: int = 0


func _ready() -> void:
	layout_mode = 3
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0
	grow_horizontal = 2
	grow_vertical = 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = load("res://scenes/ui/shaders/NeonColumnGlow.gdshader")

	_setup_spectrum_analyzer()
	_update_column_count()
	resized.connect(_update_column_count)
	_layout_columns()


func _setup_spectrum_analyzer() -> void:
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index == -1:
		return

	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, i)
		if effect is AudioEffectSpectrumAnalyzer:
			_spectrum = AudioServer.get_bus_effect_instance(bus_index, i)
			return

	var analyzer := AudioEffectSpectrumAnalyzer.new()
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	AudioServer.add_bus_effect(bus_index, analyzer)
	var effect_index := AudioServer.get_bus_effect_count(bus_index) - 1
	_spectrum = AudioServer.get_bus_effect_instance(bus_index, effect_index)


func _create_columns() -> void:
	for child in get_children():
		child.queue_free()
	_columns.clear()
	_energies.clear()

	for i in range(_column_count):
		var column := ColorRect.new()
		column.name = "Column%d" % i
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.color = neon_colors[i % neon_colors.size()]
		column.material = _shader_material.duplicate()
		add_child(column)
		_columns.append(column)
		_energies.append(0.0)


func _update_column_count() -> void:
	var available_width := size.x
	var needed_for_one := column_width + column_gap
	var count := int(floorf((available_width + column_gap) / needed_for_one))
	count = maxi(count, 8)
	if count == _column_count:
		return
	_column_count = count
	_create_columns()
	_layout_columns()


func _layout_columns() -> void:
	if _columns.is_empty():
		return
	var total_width := _column_count * column_width + maxf(0, _column_count - 1) * column_gap
	var start_x := (size.x - total_width) * 0.5
	for i in range(_column_count):
		var column := _columns[i]
		column.position = Vector2(start_x + i * (column_width + column_gap), size.y)
		column.size = Vector2(column_width, 0.0)


func _process(delta: float) -> void:
	if _spectrum == null or _columns.is_empty():
		return

	var max_height := size.y * max_height_ratio
	var min_freq := 20.0
	var max_freq := 16000.0
	var log_min := log(min_freq)
	var log_max := log(max_freq)

	for i in range(_column_count):
		var t0 := float(i) / _column_count
		var t1 := float(i + 1) / _column_count
		var f0 := exp(log_min + (log_max - log_min) * t0)
		var f1 := exp(log_min + (log_max - log_min) * t1)
		var mag := _spectrum.get_magnitude_for_frequency_range(f0, f1)
		var energy := (mag.x + mag.y) * 0.5
		var db := linear_to_db(energy + 1e-10)
		var target := clampf((db - min_db) / (max_db - min_db), 0.0, 1.0)

		var speed := rise_speed if target > _energies[i] else fall_speed
		_energies[i] = lerp(_energies[i], target, 1.0 - exp(-delta * speed))

		var column := _columns[i]
		var h := max_height * _energies[i]
		column.size = Vector2(column_width, h)
		column.position = Vector2(column.position.x, size.y - h)
		column.modulate.a = base_alpha + (1.0 - base_alpha) * _energies[i]


func set_intensity(min_db_value: float, max_db_value: float) -> void:
	min_db = min_db_value
	max_db = max_db_value
