extends Node

## Deterministic random source for gameplay.
## Keep all procedural randomness here so runs can be saved and replayed.

const MODULUS := 2147483647
const MULTIPLIER := 48271

var seed_value: int = 1
var state_value: int = 1
var step_count: int = 0


func _ready() -> void:
	var save_service = get_node_or_null("/root/SaveService")
	if save_service != null:
		save_service.register_provider("random", self)


func set_seed(value) -> void:
	var normalized := _normalize_seed(value)
	seed_value = normalized
	state_value = normalized
	step_count = 0


func snapshot() -> Dictionary:
	return {
		"seed": seed_value,
		"state": state_value,
		"steps": step_count,
	}


func restore(data: Dictionary) -> void:
	seed_value = _normalize_seed(data.get("seed", 1))
	state_value = _normalize_seed(data.get("state", seed_value))
	step_count = maxi(0, int(data.get("steps", 0)))


func randi_value() -> int:
	state_value = int((int(state_value) * MULTIPLIER) % MODULUS)
	step_count += 1
	return state_value


func randf_value() -> float:
	return float(randi_value()) / float(MODULUS)


func randi_range_value(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		var swap := min_value
		min_value = max_value
		max_value = swap

	var span := max_value - min_value + 1
	return min_value + (randi_value() % span)


func pick(array: Array):
	if array.is_empty():
		return null
	return array[randi_range_value(0, array.size() - 1)]


func shuffle_copy(array: Array) -> Array:
	var copy := array.duplicate()
	for index in range(copy.size() - 1, 0, -1):
		var other := randi_range_value(0, index)
		var temp = copy[index]
		copy[index] = copy[other]
		copy[other] = temp
	return copy


func get_save_data() -> Dictionary:
	return snapshot()


func load_save_data(data: Dictionary) -> void:
	restore(data)


func _normalize_seed(value) -> int:
	var result: int
	if value is String:
		result = abs(hash(value))
	else:
		result = abs(int(value))

	result %= MODULUS
	if result == 0:
		result = 1
	return result
