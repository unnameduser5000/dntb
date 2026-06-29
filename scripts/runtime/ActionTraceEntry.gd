class_name ActionTraceEntry
extends RefCounted

var actor_id: int = -1
var action_id: String = ""
var input_token_id: String = ""
var symbol: StringName = &""
var chain_index: int = 0
var chain_id: int = -1
var from_cell: Vector2i = Vector2i.ZERO
var to_cell: Vector2i = Vector2i.ZERO
var move_delta: Vector2i = Vector2i.ZERO
var move_dir: Vector2i = Vector2i.ZERO
var moved: bool = false
var facing_before: Vector2i = Vector2i.ZERO
var facing_after: Vector2i = Vector2i.ZERO
var tags: Array[StringName] = []


func to_debug_string() -> String:
	return "%s(%s)" % [String(symbol), action_id]
