class_name ActionProgramController
extends RefCounted

const ActionInstanceScript := preload("res://scripts/runtime/ActionInstance.gd")

const POOL_SLOT_ID := "POOL"
const KEY_ORDER := ["U", "D", "L", "R"]
const KEY_NAMES := {
	"U": "上",
	"D": "下",
	"L": "左",
	"R": "右",
}
const KEY_DIRECTIONS := {
	"U": Vector2i.UP,
	"D": Vector2i.DOWN,
	"L": Vector2i.LEFT,
	"R": Vector2i.RIGHT,
}

var action_by_id: Dictionary = {}
var move_key_action: Resource
var key_slots: Dictionary = {}
var loose_key_tokens: Array[String] = []


func setup(actions: Dictionary, direction_move_action: Resource) -> void:
	action_by_id = actions
	move_key_action = direction_move_action
	reset_default_slots()


# 按键编程模型：
# - 实体按键槽固定为 U/D/L/R，由玩家的键盘映射触发。
# - 槽内保存的是行动 token；U/D/L/R token 是最基础的方向移动。
# - 突刺、横扫等奖励行动也作为 token 进入备用池，再拖入按键槽。
func reset_default_slots() -> void:
	key_slots.clear()
	for key_id in KEY_ORDER:
		key_slots[key_id] = [key_id]
	loose_key_tokens.clear()


func has_slot(slot_id: String) -> bool:
	return key_slots.has(slot_id)


func get_slot(slot_id: String) -> Array:
	return key_slots.get(slot_id, [])


func build_plan(token_ids: Array, actor) -> Array:
	var plan: Array = []
	for raw_token_id in token_ids:
		var token_id := String(raw_token_id)
		var action = make_action_from_token(token_id, actor)
		if action != null:
			plan.append(action)
	return plan


func make_action_from_token(token_id: String, actor):
	if is_direction_token(token_id):
		if move_key_action == null:
			return null
		var direction: Vector2i = KEY_DIRECTIONS.get(token_id, Vector2i.ZERO)
		var move_action = ActionInstanceScript.new()
		move_action.actor = actor
		move_action.def = move_key_action
		move_action.chosen_dir = direction
		move_action.key_id = token_id
		return move_action

	var action_def = action_by_id.get(token_id)
	if action_def == null:
		return null

	var action = ActionInstanceScript.new()
	action.actor = actor
	action.def = action_def
	action.key_id = token_id
	return action


func move_token(source_slot_id: String, source_index: int, target_slot_id: String) -> Dictionary:
	var source = _get_token_container(source_slot_id)
	var target = _get_token_container(target_slot_id)
	if source == null or target == null:
		return {"moved": false, "token_id": ""}
	if source_index < 0 or source_index >= source.size():
		return {"moved": false, "token_id": ""}

	var token_id := String(source[source_index])
	source.remove_at(source_index)
	target.append(token_id)
	return {"moved": true, "token_id": token_id}


func add_token_to_pool(token_id: String, allow_duplicates: bool = false) -> bool:
	if token_id.is_empty():
		return false
	if not allow_duplicates and has_token(token_id):
		return false
	loose_key_tokens.append(token_id)
	return true


func has_token(token_id: String) -> bool:
	for slot_id in KEY_ORDER:
		for existing_token_id in key_slots.get(slot_id, []):
			if String(existing_token_id) == token_id:
				return true
	for existing_token_id in loose_key_tokens:
		if String(existing_token_id) == token_id:
			return true
	return false


func token_display_name(token_id: String, state = null) -> String:
	if is_direction_token(token_id):
		var key_name := String(KEY_NAMES.get(token_id, token_id))
		if state != null and state.has_method("key_name"):
			key_name = state.key_name(token_id)
		return "%s移动" % key_name

	var action = action_by_id.get(token_id)
	if action != null:
		return String(action.display_name)
	return token_id


func get_save_data() -> Dictionary:
	return {
		"key_slots": key_slots.duplicate(true),
		"loose_key_tokens": loose_key_tokens.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	key_slots.clear()
	var raw_slots = data.get("key_slots", {})
	for key_id in KEY_ORDER:
		key_slots[key_id] = []
		var source_keys = raw_slots.get(key_id, [key_id]) if typeof(raw_slots) == TYPE_DICTIONARY else [key_id]
		for raw_token_id in source_keys:
			key_slots[key_id].append(String(raw_token_id))

	loose_key_tokens.clear()
	for raw_token_id in data.get("loose_key_tokens", []):
		loose_key_tokens.append(String(raw_token_id))


func is_direction_token(token_id: String) -> bool:
	return KEY_DIRECTIONS.has(token_id)


func _get_token_container(slot_id: String):
	if slot_id == POOL_SLOT_ID:
		return loose_key_tokens
	if not key_slots.has(slot_id):
		return null
	return key_slots[slot_id]
