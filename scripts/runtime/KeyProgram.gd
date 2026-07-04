class_name KeyProgram
extends RefCounted

## Player-edited key program model.
## This layer stores user-facing programmable token sequences:
## - per-key slot token chains
## - spare/pool tokens not assigned to a slot
##
## In the current architecture this is the stable storage layer for the
## player's programmable input layout. Tokens may represent either absolute
## directions or explicit base actions. Action translation, relative trace
## semantics, weapon patterns, and interference rules are built on top of it.
##
## Current token identity stays intentionally simple:
## - each stored value is a semantic token id String such as "U"
## - it is not a unique per-token instance id
## - duplicate tokens are distinguished only by container + index

const POOL_SLOT_ID := "POOL"
const DEFAULT_KEY_ORDER: Array[String] = ["U", "D", "L", "R"]

var key_order: Array[String] = []
var slots: Dictionary = {}
## Tokens that exist in the run but are not currently assigned to a slot.
var pool_tokens: Array[String] = []


func setup_default(new_key_order: Array[String] = DEFAULT_KEY_ORDER) -> void:
	key_order = new_key_order.duplicate()
	slots.clear()
	for key_id in key_order:
		slots[key_id] = [key_id]
	pool_tokens.clear()


func has_slot(slot_id: String) -> bool:
	return slots.has(slot_id)


func get_chain_for_key(key_id: String) -> Array:
	return slots.get(key_id, []).duplicate()


func move_token(source_slot_id: String, source_index: int, target_slot_id: String) -> Dictionary:
	var source = _get_container(source_slot_id)
	var target = _get_container(target_slot_id)
	if source == null or target == null:
		return {"moved": false, "token_id": ""}
	if source_index < 0 or source_index >= source.size():
		return {"moved": false, "token_id": ""}
	if target_slot_id != POOL_SLOT_ID and target.size() >= 2:
		return {"moved": false, "token_id": ""}

	var token_id := String(source[source_index])
	source.remove_at(source_index)
	target.append(token_id)
	return {"moved": true, "token_id": token_id}


## Adds a token to the spare-token pool.
## When duplicates are disallowed, uniqueness is checked by semantic token id.
func add_pool_token(token_id: String, allow_duplicates: bool = false) -> bool:
	if token_id.is_empty():
		return false
	if not allow_duplicates and has_token(token_id):
		return false
	pool_tokens.append(token_id)
	return true


func has_token(token_id: String) -> bool:
	for key_id in key_order:
		for existing_token_id in slots.get(key_id, []):
			if String(existing_token_id) == token_id:
				return true
	for existing_token_id in pool_tokens:
		if String(existing_token_id) == token_id:
			return true
	return false


func get_save_data() -> Dictionary:
	return {
		"key_slots": slots.duplicate(true),
		"pool_tokens": pool_tokens.duplicate(),
	}


func load_save_data(data: Dictionary, allowed_token_ids: Array[String], default_keys: Array[String] = DEFAULT_KEY_ORDER) -> void:
	key_order = default_keys.duplicate()
	slots.clear()
	var raw_slots = data.get("key_slots", {})
	for key_id in key_order:
		slots[key_id] = []
		var source_keys = raw_slots.get(key_id, [key_id]) if typeof(raw_slots) == TYPE_DICTIONARY else [key_id]
		for raw_token_id in source_keys:
			var token_id := String(raw_token_id)
			if allowed_token_ids.has(token_id):
				slots[key_id].append(token_id)

	pool_tokens.clear()
	for raw_token_id in data.get("pool_tokens", []):
		var token_id := String(raw_token_id)
		if allowed_token_ids.has(token_id):
			pool_tokens.append(token_id)


func _get_container(slot_id: String):
	if slot_id == POOL_SLOT_ID:
		return pool_tokens
	if not slots.has(slot_id):
		return null
	return slots[slot_id]
