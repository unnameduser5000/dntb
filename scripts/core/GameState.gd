class_name GameState
extends RefCounted

const KEY_NAMES := {
	"U": "上",
	"D": "下",
	"L": "左",
	"R": "右",
}

var grid
var actors: Array = []
var player
var turn_count: int = 0
var phase: String = "planning"
var items_at: Dictionary = {}
var exit_cell: Vector2i = Vector2i.ZERO
var messages: Array[String] = []
var battle_finished: bool = false
var victory: bool = false
var room_index: int = 0
var room_name: String = ""
var map_node_index: int = 0
var map_node_kind: String = "combat"
var map_node_label: String = ""
var danger_cells: Array = []
var enemy_intents: Array = []
var preview_move_cells: Array = []
var preview_attack_cells: Array = []
var effect_modifiers: Array = []
var is_safe_training: bool = false

func add_actor(actor) -> void:
	actors.append(actor)
	if actor.team == "player":
		player = actor

func get_alive_enemies() -> Array:
	var result: Array = []
	for actor in actors:
		if actor.team == "enemy" and not actor.is_dead():
			result.append(actor)
	return result

func key_name(key_id: String) -> String:
	return String(KEY_NAMES.get(key_id, key_id))

func drop_key_at(cell: Vector2i, key_id: String) -> void:
	if key_id.is_empty():
		return
	items_at[cell] = key_id

func pickup_key_at(cell: Vector2i) -> String:
	if not items_at.has(cell):
		return ""

	var key_id := String(items_at[cell])
	items_at.erase(cell)
	return key_id

func add_message(message: String) -> void:
	messages.push_front(message)
	if messages.size() > 9:
		messages.resize(9)

func clear_temporary_flags() -> void:
	for actor in actors:
		actor.guarded = false
