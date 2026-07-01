extends Node

## Player programmable-key input and rebinding.
## Uses Godot InputMap instead of hard-coded key checks.

signal binding_changed(action_name: String, keycode: int)

const ACTION_Q := "player_key_q"
const ACTION_W := "player_key_w"
const ACTION_E := "player_key_e"
const ACTION_R := "player_key_r"
const ACTION_A := "player_key_a"
const ACTION_S := "player_key_s"
const ACTION_D := "player_key_d"
const ACTION_F := "player_key_f"
const ACTION_Z := "player_key_z"
const ACTION_X := "player_key_x"
const ACTION_C := "player_key_c"
const ACTION_V := "player_key_v"
const ACTION_UP := ACTION_W
const ACTION_DOWN := ACTION_S
const ACTION_LEFT := ACTION_A
const ACTION_RIGHT := ACTION_D
const CONFIG_PATH := "user://input_bindings.cfg"

const PROGRAM_ACTIONS := [
	ACTION_Q,
	ACTION_W,
	ACTION_E,
	ACTION_R,
	ACTION_A,
	ACTION_S,
	ACTION_D,
	ACTION_F,
	ACTION_Z,
	ACTION_X,
	ACTION_C,
	ACTION_V,
]

const DEFAULT_KEYCODES := {
	ACTION_Q: KEY_Q,
	ACTION_W: KEY_W,
	ACTION_E: KEY_E,
	ACTION_R: KEY_R,
	ACTION_A: KEY_A,
	ACTION_S: KEY_S,
	ACTION_D: KEY_D,
	ACTION_F: KEY_F,
	ACTION_Z: KEY_Z,
	ACTION_X: KEY_X,
	ACTION_C: KEY_C,
	ACTION_V: KEY_V,
}

const KEY_IDS := {
	ACTION_Q: "Q",
	ACTION_W: "W",
	ACTION_E: "E",
	ACTION_R: "R",
	ACTION_A: "A",
	ACTION_S: "S",
	ACTION_D: "D",
	ACTION_F: "F",
	ACTION_Z: "Z",
	ACTION_X: "X",
	ACTION_C: "C",
	ACTION_V: "V",
}

const DIRECTIONS := {
	ACTION_W: Vector2i.UP,
	ACTION_S: Vector2i.DOWN,
	ACTION_A: Vector2i.LEFT,
	ACTION_D: Vector2i.RIGHT,
}

var _keycodes: Dictionary = {}


func _ready() -> void:
	load_bindings()
	_apply_bindings()


func load_bindings() -> void:
	_keycodes.clear()
	var config := ConfigFile.new()
	var error := config.load(CONFIG_PATH)
	for action_name in PROGRAM_ACTIONS:
		_keycodes[action_name] = int(DEFAULT_KEYCODES[action_name])

	if error != OK:
		return

	for action_name in PROGRAM_ACTIONS:
		_keycodes[action_name] = int(config.get_value("bindings", action_name, _keycodes[action_name]))


func save_bindings() -> void:
	var config := ConfigFile.new()
	for action_name in PROGRAM_ACTIONS:
		config.set_value("bindings", action_name, int(_keycodes[action_name]))
	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_warning("Unable to save input bindings: %s" % error_string(error))


func rebind_key(action_name: String, keycode: int) -> void:
	if not PROGRAM_ACTIONS.has(action_name):
		return

	_keycodes[action_name] = int(keycode)
	_apply_action_binding(action_name, keycode)
	save_bindings()
	binding_changed.emit(action_name, keycode)


func reset_bindings() -> void:
	for action_name in PROGRAM_ACTIONS:
		_keycodes[action_name] = int(DEFAULT_KEYCODES[action_name])
	_apply_bindings()
	save_bindings()


func get_binding_label(action_name: String) -> String:
	return OS.get_keycode_string(int(_keycodes.get(action_name, 0)))


func get_pressed_program_action(event: InputEvent) -> String:
	for action_name in PROGRAM_ACTIONS:
		if event.is_action_pressed(action_name):
			return action_name
	return ""


func is_program_action(action_name: String) -> bool:
	return PROGRAM_ACTIONS.has(action_name)


func get_program_actions() -> Array[String]:
	return PROGRAM_ACTIONS.duplicate()


func is_move_action(action_name: String) -> bool:
	return DIRECTIONS.has(action_name)


func get_key_id_for_action(action_name: String) -> String:
	return String(KEY_IDS.get(action_name, ""))


func get_direction_for_action(action_name: String) -> Vector2i:
	var direction: Vector2i = DIRECTIONS.get(action_name, Vector2i.ZERO)
	return direction


func get_action_for_key_id(key_id: String) -> String:
	for action_name in KEY_IDS.keys():
		if KEY_IDS[action_name] == key_id:
			return action_name
	return ""


func _apply_bindings() -> void:
	for action_name in PROGRAM_ACTIONS:
		_apply_action_binding(action_name, int(_keycodes[action_name]))


func _apply_action_binding(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)
