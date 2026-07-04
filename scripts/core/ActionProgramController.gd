class_name ActionProgramController
extends RefCounted

## Thin wrapper around KeyProgram.
## This controller owns the editable key-program layer:
## - slot existence
## - slot token order
## - spare/pool token management
##
## Current design:
## - there are twelve physical keyboard slots: QWER / ASDF / ZXCV
## - slots can hold both movement tokens and concrete action tokens
## - reset_default_slots() builds the absolute starter preset
## - reset_starter_slots(preset_id) applies a specific starter preset

const STARTER_PRESET_ABSOLUTE := "absolute"
const STARTER_PRESET_RELATIVE := "relative"

const SLOT_ORDER: Array[String] = ["Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V"]
const TOKEN_NAMES := {
	"U": "上",
	"D": "下",
	"L": "左",
	"R": "右",
	"F": "前进",
	"B": "后退",
	"SL": "左侧移",
	"SR": "右侧移",
	"DS": "冲刺",
	"HK": "钩拽",
	"SB": "盾击",
	"HM": "锤击",
	"RA": "旋斧",
	"PI": "穿刺",
	"TH": "贯刺",
	"SW": "横扫",
	"BW": "弓射",
	"CA": "十字刃",
	"TL": "左转",
	"TR": "右转",
	"A": "斩击",
	"I": "交互",
	"G": "防御",
	"W": "等待",
	"J": "跳跃",
}
const KEY_DIRECTIONS := {
	"U": Vector2i.UP,
	"D": Vector2i.DOWN,
	"L": Vector2i.LEFT,
	"R": Vector2i.RIGHT,
}
const ACTION_TOKENS: Array[String] = ["F", "B", "SL", "SR", "DS", "HK", "SB", "HM", "RA", "PI", "TH", "SW", "BW", "CA", "TL", "TR", "A", "I", "G", "W", "J"]
## Shared token-drop pool for future room / reward sources.
## This keeps mixed drops aligned with the same legal token set as the
## program editor and save/load layer.
const TOKEN_DROP_POOL: Array[String] = ["U", "D", "L", "R", "F", "B", "SL", "SR", "DS", "HK", "SB", "HM", "RA", "PI", "TH", "SW", "BW", "CA", "TL", "TR", "A", "I", "G", "W", "J"]
const KeyProgramScript := preload("res://scripts/runtime/KeyProgram.gd")

var key_program = null


func setup() -> void:
	if key_program == null:
		key_program = KeyProgramScript.new()
	reset_default_slots()


func reset_default_slots() -> void:
	_apply_starter_preset(STARTER_PRESET_ABSOLUTE)


func reset_starter_slots(preset_id: String) -> void:
	_apply_starter_preset(preset_id)


func has_slot(slot_id: String) -> bool:
	return key_program != null and key_program.has_slot(slot_id)


func get_slot(slot_id: String) -> Array:
	return [] if key_program == null else key_program.get_chain_for_key(slot_id)


func move_token(source_slot_id: String, source_index: int, target_slot_id: String) -> Dictionary:
	if key_program == null:
		return {"moved": false, "token_id": ""}
	return key_program.move_token(source_slot_id, source_index, target_slot_id)


func add_token_to_pool(token_id: String, allow_duplicates: bool = false) -> bool:
	if token_id.is_empty():
		return false
	if not is_program_token(token_id):
		return false
	if key_program == null:
		return false
	return key_program.add_pool_token(token_id, allow_duplicates)


func has_token(token_id: String) -> bool:
	return key_program != null and key_program.has_token(token_id)


func token_display_name(token_id: String, state = null) -> String:
	if is_direction_token(token_id):
		var token_name := String(TOKEN_NAMES.get(token_id, token_id))
		if state != null and state.has_method("key_name"):
			token_name = state.key_name(token_id)
		return "%s键" % token_name
	return String(TOKEN_NAMES.get(token_id, token_id))


func get_save_data() -> Dictionary:
	return {} if key_program == null else key_program.get_save_data()


func load_save_data(data: Dictionary) -> void:
	if key_program == null:
		key_program = KeyProgramScript.new()
	key_program.load_save_data(data, all_program_tokens(), SLOT_ORDER)


func is_direction_token(token_id: String) -> bool:
	return KEY_DIRECTIONS.has(token_id)


func is_program_token(token_id: String) -> bool:
	return is_direction_token(token_id) or ACTION_TOKENS.has(token_id)


func all_program_tokens() -> Array[String]:
	return TOKEN_DROP_POOL.duplicate()


func get_key_slots() -> Dictionary:
	return {} if key_program == null else key_program.slots.duplicate(true)


func get_pool_tokens() -> Array[String]:
	return [] if key_program == null else key_program.pool_tokens.duplicate()


func get_pool_token_stacks() -> Array[Dictionary]:
	var stacks: Array[Dictionary] = []
	if key_program == null:
		return stacks
	var stack_index_by_token: Dictionary = {}
	for index in range(key_program.pool_tokens.size()):
		var token_id := String(key_program.pool_tokens[index])
		if stack_index_by_token.has(token_id):
			var stack_index: int = int(stack_index_by_token[token_id])
			stacks[stack_index]["count"] = int(stacks[stack_index].get("count", 0)) + 1
			continue
		stack_index_by_token[token_id] = stacks.size()
		stacks.append({
			"token_id": token_id,
			"count": 1,
			"source_index": index,
		})
	return stacks


func get_token_drop_pool() -> Array[String]:
	return TOKEN_DROP_POOL.duplicate()


func _apply_starter_preset(preset_id: String) -> void:
	_ensure_key_program()
	key_program.setup_default(SLOT_ORDER)
	for slot_id in SLOT_ORDER:
		key_program.slots[slot_id] = []
	match preset_id:
		STARTER_PRESET_RELATIVE:
			key_program.slots["W"] = ["F"]
			key_program.slots["S"] = ["B"]
			key_program.slots["A"] = ["SL"]
			key_program.slots["D"] = ["SR"]
			key_program.slots["F"] = ["I"]
		_:
			key_program.slots["W"] = ["U"]
			key_program.slots["S"] = ["D"]
			key_program.slots["A"] = ["L"]
			key_program.slots["D"] = ["R"]
			key_program.slots["F"] = ["I"]


func _ensure_key_program() -> void:
	if key_program == null:
		key_program = KeyProgramScript.new()
