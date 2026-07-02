class_name GameState
extends RefCounted

const KEY_NAMES := {
	"U": "上",
	"D": "下",
	"L": "左",
	"R": "右",
}

var grid
var map_data = null
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
var visible_cells: Array[Vector2i] = []
var explored_cells: Array[Vector2i] = []
var visible_cell_set: Dictionary = {}
var explored_cell_set: Dictionary = {}
var reveal_all_debug: bool = false
var last_visibility_recompute_reason: String = ""
var fov_radius: int = 6
var render_window_rect: Rect2i = Rect2i()
var active_window_tile_count: int = 0
var board_refresh_count: int = 0
var fov_recompute_count: int = 0
var hud_refresh_count: int = 0
var entity_visual_count: int = 0
var last_board_refresh_ms: float = 0.0
var last_fov_ms: float = 0.0
var last_generation_ms: float = 0.0
var generation_breakdown_ms: Dictionary = {}
var world_enemy_stream_refresh_count: int = 0
var world_enemy_stream_target: int = 0
var world_enemy_stream_last_spawned: int = 0
var world_enemy_stream_last_despawned: int = 0
var world_enemy_stream_spawn_total: int = 0
var world_enemy_stream_despawn_total: int = 0
var world_enemy_stream_last_reason: String = ""
var effect_modifiers: Array = []
var is_safe_training: bool = false
var is_world_slice: bool = false
var action_trace = null

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
	match key_id:
		"TL":
			return "宸﹁浆"
		"TR":
			return "鍙宠浆"
		"J":
			return "璺宠穬"
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


func clear_visibility() -> void:
	visible_cells.clear()
	explored_cells.clear()
	visible_cell_set.clear()
	explored_cell_set.clear()
	last_visibility_recompute_reason = ""
