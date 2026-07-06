class_name WorldSliceController
extends RefCounted

const GameStateScript := preload("res://scripts/core/GameState.gd")
const GridModelScript := preload("res://scripts/core/GridModel.gd")
const MapGenConfigScript := preload("res://scripts/core/MapGenConfig.gd")
const WorldGeneratorScript := preload("res://scripts/core/WorldGenerator.gd")
const ActorStateScript := preload("res://scripts/runtime/ActorState.gd")
const GridItemStateScript := preload("res://scripts/runtime/GridItemState.gd")
const VisibilityServiceScript := preload("res://scripts/core/VisibilityService.gd")
const PLAYER_DEF := preload("res://data/actors/player.tres")
const SLIME_DEF := preload("res://data/actors/monster.tres")
const WISP_DEF := preload("res://data/actors/wisp.tres")
const BRUTE_DEF := preload("res://data/actors/brute.tres")
const LINE_WARDEN_DEF := preload("res://data/actors/line_warden.tres")
const GOBLIN_SCOUT_DEF := preload("res://data/actors/goblin_scout.tres")
const GOBLIN_SLINGER_DEF := preload("res://data/actors/goblin_slinger.tres")
const AOE_SLIME_DEF := preload("res://data/actors/aoe_slime.tres")
const SPLIT_SLIME_DEF := preload("res://data/actors/split_slime.tres")
const TAVERN_KEEPER_DEF := preload("res://data/actors/tavern_keeper.tres")
const BOSS_GATEKEEPER_DEF := preload("res://data/actors/boss_gatekeeper.tres")
const RUIN_GUIDE_DEF := preload("res://data/actors/ruin_guide.tres")

const WORLD_GRID_SIZE := Vector2i(256, 256)
const DEFAULT_FOV_RADIUS := 8
const REQUIRED_ENEMY_COUNT := 4
const STREAM_DESIRED_ACTIVE_ENEMY_COUNT := 10
const STREAM_SPAWN_RADIUS_MIN := 10
const STREAM_SPAWN_RADIUS_MAX := 18
const STREAM_DESPAWN_DISTANCE := 28
const WORLD_ENEMY_DEFS_BY_TIER := {
	1: [WISP_DEF, SLIME_DEF, GOBLIN_SCOUT_DEF],
	2: [BRUTE_DEF, LINE_WARDEN_DEF, GOBLIN_SLINGER_DEF, AOE_SLIME_DEF, SPLIT_SLIME_DEF],
}
const WORLD_ENEMY_PROFILE_WEIGHTS := {
	"calm": {1: 18, 2: 6},
	"event_alert": {1: 6, 2: 18},
}
const NPC_DEF_BY_ID := {
	"tavern_keeper": TAVERN_KEEPER_DEF,
	"boss_gatekeeper": BOSS_GATEKEEPER_DEF,
	"ruin_guide": RUIN_GUIDE_DEF,
}

var _next_actor_id: int = 0
var _next_item_id: int = 1000
var _seed_counter: int = 0
var _visibility_service = VisibilityServiceScript.new()
var _world_generator = WorldGeneratorScript.new()
var _map_config = _build_default_map_config()


func create_demo_state(seed_value: String = ""):
	var state = GameStateScript.new()
	state.grid = GridModelScript.new()
	_prepare_state_shell(state)
	var initial_seed: String = seed_value if not seed_value.is_empty() else _make_random_seed()
	_rebuild_world_slice_state(state, initial_seed, "init")
	return state


func create_demo_state_with_progress(seed_value: String = "", progress_callback: Callable = Callable()):
	var state = GameStateScript.new()
	state.grid = GridModelScript.new()
	_prepare_state_shell(state)
	var initial_seed: String = seed_value if not seed_value.is_empty() else _make_random_seed()
	await rebuild_state_with_progress(state, initial_seed, "init", progress_callback)
	return state


func rebuild_state_with_progress(state, seed_value: String, visibility_reason: String, progress_callback: Callable = Callable()) -> void:
	await _rebuild_world_slice_state_with_progress(state, seed_value, visibility_reason, progress_callback)


func get_visible_cells(state) -> Array[Vector2i]:
	if state == null:
		return []
	return state.visible_cells.duplicate()


func get_explored_cells(state) -> Array[Vector2i]:
	if state == null:
		return []
	return state.explored_cells.duplicate()


func recompute_visibility(state, reason: String = "manual") -> void:
	if state == null or state.player == null or state.map_data == null:
		return

	var started_at: int = Time.get_ticks_msec()
	state.visible_cells.clear()
	state.visible_cell_set.clear()
	if state.reveal_all_debug:
		state.visible_cells = _visibility_service.reveal_all(state.map_data)
	else:
		state.visible_cells = _visibility_service.compute_visible_cells(state.map_data, state.player.grid_pos, int(state.fov_radius))

	for cell in state.visible_cells:
		state.visible_cell_set[cell] = true

	for cell in state.visible_cells:
		if not state.explored_cell_set.has(cell):
			state.explored_cells.append(cell)
			state.explored_cell_set[cell] = true
	state.last_visibility_recompute_reason = reason
	state.fov_recompute_count += 1
	state.last_fov_ms = float(Time.get_ticks_msec() - started_at)
	_update_actor_visibility(state)


func set_reveal_all_debug(state, enabled: bool, reason: String = "debug_toggle") -> void:
	if state == null:
		return
	state.reveal_all_debug = enabled
	recompute_visibility(state, reason)


func regenerate_same_seed(state) -> void:
	if state == null:
		return
	var seed_value: String = state.map_data.seed if state.map_data != null else _make_random_seed()
	_rebuild_world_slice_state(state, seed_value, "reset")


func regenerate_new_seed(state) -> void:
	if state == null:
		return
	_rebuild_world_slice_state(state, _make_random_seed(), "reset")


func reset_world_slice(state) -> void:
	regenerate_same_seed(state)


func print_map_summary(state) -> void:
	for line in get_map_summary_lines(state):
		print(line)
	if state != null and state.map_data != null:
		state.add_message("Printed map summary for seed %s" % state.map_data.seed)


func get_map_summary_lines(state) -> Array[String]:
	if state == null or state.map_data == null:
		return []
	var lines: Array[String] = state.map_data.get_debug_summary_lines()
	lines.append("Reveal all: %s" % ("on" if bool(state.reveal_all_debug) else "off"))
	return lines


func on_player_moved(state, _from_cell: Vector2i = Vector2i.ZERO, _to_cell: Vector2i = Vector2i.ZERO) -> void:
	recompute_visibility(state, "player_moved")
	_refresh_world_npc_tracking(state)
	refresh_streamed_enemies(state, "player_moved")


func on_actor_moved(state, actor, _from_cell: Vector2i = Vector2i.ZERO, _to_cell: Vector2i = Vector2i.ZERO) -> void:
	if state == null or not bool(state.is_world_slice):
		return
	if actor == state.player:
		recompute_visibility(state, "player_moved")
		_refresh_world_npc_tracking(state)
		refresh_streamed_enemies(state, "player_moved")


func _prepare_state_shell(state) -> void:
	_next_actor_id = 0
	_next_item_id = 1000
	state.room_index = 0
	state.room_name = "World Slice"
	state.map_node_index = 0
	state.map_node_kind = "world_slice"
	state.map_node_label = "World Slice"
	state.exit_cell = Vector2i(-99, -99)
	state.is_safe_training = false
	state.is_world_slice = true
	state.reveal_all_debug = false
	state.fov_radius = DEFAULT_FOV_RADIUS
	state.visible_cells.clear()
	state.visible_cell_set.clear()
	state.explored_cells.clear()
	state.explored_cell_set.clear()
	state.actors.clear()
	state.player = null
	state.world_actor_positions.clear()
	state.world_actor_display_names.clear()
	state.tracked_world_actor_id = ""
	state.show_tracked_world_actor_hint = false
	state.tracked_world_actor_relative_hint = ""
	state.world_npc_positions.clear()
	state.world_npc_display_names.clear()
	state.tracked_world_npc_id = ""
	state.show_tracked_world_npc_hint = false
	state.tracked_world_npc_relative_hint = ""
	state.defer_enemy_phase_for_interaction = false
	state.world_enemy_spawn_profile = "calm"


func _rebuild_world_slice_state(state, seed_value: String, visibility_reason: String) -> void:
	if state == null:
		return
	_reset_runtime_state(state)
	var generation_session: Dictionary = _world_generator.create_generation_session(seed_value, _map_config)
	for stage in _world_generator.get_stage_defs():
		_world_generator.run_generation_stage(generation_session, String(stage.get("id", "")))
	state.map_data = _world_generator.finish_generation_session(generation_session)
	_apply_generated_map_state(state, visibility_reason)


func _rebuild_world_slice_state_with_progress(state, seed_value: String, visibility_reason: String, progress_callback: Callable = Callable()) -> void:
	if state == null:
		return
	_reset_runtime_state(state)
	var generation_session: Dictionary = _world_generator.create_generation_session(seed_value, _map_config)
	var stage_defs: Array = _world_generator.get_stage_defs()
	await _emit_generation_progress(progress_callback, "start", "准备世界参数", 0.0, -1, stage_defs.size())
	for stage_index in range(stage_defs.size()):
		var stage: Dictionary = stage_defs[stage_index]
		_world_generator.run_generation_stage(generation_session, String(stage.get("id", "")))
		await _emit_generation_progress(
			progress_callback,
			String(stage.get("id", "")),
			String(stage.get("label", "")),
			float(stage_index + 1) / float(max(1, stage_defs.size())),
			stage_index,
			stage_defs.size()
		)
	state.map_data = _world_generator.finish_generation_session(generation_session)
	_apply_generated_map_state(state, visibility_reason)


func _reset_runtime_state(state) -> void:
	_next_actor_id = 0
	_next_item_id = 1000
	state.actors.clear()
	state.player = null
	state.turn_count = 0
	state.phase = "planning"
	state.battle_finished = false
	state.victory = false
	state.items_at.clear()
	state.preview_move_cells.clear()
	state.preview_attack_cells.clear()
	state.danger_cells.clear()
	state.enemy_intents.clear()
	state.messages.clear()
	state.reveal_all_debug = false
	state.world_actor_positions.clear()
	state.world_actor_display_names.clear()
	state.tracked_world_actor_id = ""
	state.show_tracked_world_actor_hint = false
	state.tracked_world_actor_relative_hint = ""
	state.world_npc_positions.clear()
	state.world_npc_display_names.clear()
	state.tracked_world_npc_id = ""
	state.show_tracked_world_npc_hint = false
	state.tracked_world_npc_relative_hint = ""
	state.defer_enemy_phase_for_interaction = false
	state.world_enemy_spawn_profile = "calm"
	state.last_visibility_recompute_reason = ""
	state.visible_cells.clear()
	state.explored_cells.clear()
	state.visible_cell_set.clear()
	state.explored_cell_set.clear()
	state.render_window_rect = Rect2i()
	state.active_window_tile_count = 0
	state.board_refresh_count = 0
	state.fov_recompute_count = 0
	state.hud_refresh_count = 0
	state.entity_visual_count = 0
	state.last_board_refresh_ms = 0.0
	state.last_fov_ms = 0.0
	state.last_generation_ms = 0.0
	state.generation_breakdown_ms = {}
	if state.action_trace != null:
		state.action_trace.clear()


func _apply_generated_map_state(state, visibility_reason: String) -> void:
	state.last_generation_ms = float(state.map_data.generation_total_ms)
	state.generation_breakdown_ms = state.map_data.generation_breakdown_ms.duplicate(true)
	if state.grid == null:
		state.grid = GridModelScript.new()
	state.grid.setup(state.map_data.width, state.map_data.height)
	_sync_grid_from_map_data(state)

	var player_cell: Vector2i = _resolve_player_spawn(state.map_data)
	var player = _add_actor(state, PLAYER_DEF, player_cell, _pick_player_facing(state.map_data, player_cell))

	var reserved: Dictionary = {}
	reserved[player_cell] = true
	_spawn_safe_zone_npcs(state, reserved)
	_spawn_world_poi_npcs(state, reserved)
	_orient_player_toward_tracked_world_npc(state)

	var prop_cell: Vector2i = _pick_prop_cell(state.map_data, reserved)
	if prop_cell != Vector2i(-1, -1):
		_add_placeholder_prop(state, prop_cell)
		reserved[prop_cell] = true

	for enemy_cell in _pick_enemy_spawn_cells(state.map_data, player_cell, reserved, REQUIRED_ENEMY_COUNT):
		var enemy_def = _pick_world_slice_enemy_def_for_index(state, state.get_alive_enemies().size(), REQUIRED_ENEMY_COUNT)
		_add_enemy_actor(state, enemy_def, enemy_cell, _step_direction_toward(enemy_cell, player_cell))
		reserved[enemy_cell] = true

	state.add_message("World slice ready. Seed %s." % state.map_data.seed)
	recompute_visibility(state, visibility_reason)
	_refresh_world_npc_tracking(state)
	refresh_streamed_enemies(state, "initial_stream")


func _emit_generation_progress(progress_callback: Callable, stage_id: String, stage_label: String, progress: float, stage_index: int, stage_count: int) -> void:
	if progress_callback.is_valid():
		progress_callback.call({
			"stage_id": stage_id,
			"stage_label": stage_label,
			"progress": progress,
			"stage_index": stage_index,
			"stage_count": stage_count,
		})
	if DisplayServer.get_name() == "headless":
		return
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		await main_loop.process_frame


func _resolve_player_spawn(map_data) -> Vector2i:
	if map_data != null and map_data.is_walkable(map_data.player_spawn):
		return map_data.player_spawn
	for cell in map_data.get_walkable_cells():
		return cell
	return Vector2i.ZERO


func _pick_player_facing(map_data, player_cell: Vector2i) -> Vector2i:
	for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		if map_data.is_walkable(player_cell + dir):
			return dir
	return Vector2i.RIGHT


func _pick_prop_cell(map_data, reserved: Dictionary) -> Vector2i:
	var preferred: Array[Vector2i] = []
	for record in map_data.get_poi_records():
		var interaction_cell: Vector2i = Vector2i(record.get("interaction_cell", Vector2i(-1, -1)))
		if interaction_cell != Vector2i(-1, -1):
			preferred.append(interaction_cell)
	if preferred.is_empty():
		if map_data.tavern_cell != Vector2i(-1, -1):
			preferred.append(map_data.tavern_cell)
		preferred.append_array(map_data.challenge_cells)
		preferred.append_array(map_data.ruin_cells)
		preferred.append_array(map_data.chest_cells)
		preferred.append_array(map_data.easter_egg_cells)
		preferred.append_array(map_data.shrine_cells)

	for cell in preferred:
		if map_data.is_walkable(cell) and not reserved.has(cell):
			return cell

	var center: Vector2i = Vector2i(map_data.width / 2, map_data.height / 2)
	return _pick_nearest_walkable(map_data.get_walkable_cells(), center, reserved)


func _spawn_safe_zone_npcs(state, reserved: Dictionary) -> int:
	if state == null or state.map_data == null:
		return 0
	var tavern_record: Dictionary = _find_player_tavern_record(state.map_data)
	if tavern_record.is_empty():
		return 0
	var spawned: int = 0
	for slot_value in tavern_record.get("npc_spawn_slots", []):
		var slot: Dictionary = Dictionary(slot_value)
		var npc_id := String(slot.get("npc_id", ""))
		var npc_def = NPC_DEF_BY_ID.get(npc_id)
		if npc_def == null:
			continue
		var spawn_cell: Vector2i = _pick_safe_zone_npc_cell_for_slot(state.map_data, tavern_record, reserved, slot)
		if spawn_cell == Vector2i(-1, -1):
			continue
		var npc = _add_actor(state, npc_def, spawn_cell, _step_direction_toward(spawn_cell, state.player.grid_pos))
		if npc == null:
			continue
		if not npc.tags.has("npc"):
			npc.tags.append("npc")
		if not npc.tags.has("safe_zone_npc"):
			npc.tags.append("safe_zone_npc")
		if not npc.tags.has("tracked_npc_candidate"):
			npc.tags.append("tracked_npc_candidate")
		reserved[spawn_cell] = true
		state.world_actor_positions[npc_id] = spawn_cell
		state.world_actor_display_names[npc_id] = String(npc.display_name)
		state.world_npc_positions[npc_id] = spawn_cell
		state.world_npc_display_names[npc_id] = String(npc.display_name)
		if bool(slot.get("track_by_default", false)):
			state.tracked_world_actor_id = npc_id
			state.show_tracked_world_actor_hint = true
			state.tracked_world_npc_id = npc_id
			state.show_tracked_world_npc_hint = true
		spawned += 1
	return spawned


func _find_player_tavern_record(map_data) -> Dictionary:
	if map_data == null:
		return {}
	var best_record: Dictionary = {}
	var best_distance: float = INF
	for record in map_data.get_poi_records():
		if String(record.get("type", "")) != "tavern":
			continue
		var occupied_cells: Array = record.get("occupied_cells", [])
		for occupied_value in occupied_cells:
			if Vector2i(occupied_value) == map_data.player_spawn:
				return record
		var interaction_cell: Vector2i = Vector2i(record.get("interaction_cell", Vector2i(-1, -1)))
		if interaction_cell == Vector2i(-1, -1):
			continue
		var distance: float = interaction_cell.distance_to(map_data.player_spawn)
		if distance < best_distance:
			best_distance = distance
			best_record = record
	return best_record


func _spawn_world_poi_npcs(state, reserved: Dictionary) -> int:
	if state == null or state.map_data == null or state.player == null:
		return 0
	var spawned := 0
	for record_value in state.map_data.get_poi_records():
		var record: Dictionary = Dictionary(record_value)
		var poi_type := String(record.get("type", ""))
		var npc_id := ""
		match poi_type:
			"challenge_entrance":
				npc_id = "boss_gatekeeper"
			"ruin":
				npc_id = "ruin_guide"
			_:
				continue
		var npc_def = NPC_DEF_BY_ID.get(npc_id)
		if npc_def == null:
			continue
		var spawn_cell := _pick_world_poi_npc_cell(state, record, reserved)
		if spawn_cell == Vector2i(-1, -1):
			continue
		var interaction_cell := Vector2i(record.get("interaction_cell", Vector2i(-1, -1)))
		var facing := _step_direction_toward(spawn_cell, interaction_cell if interaction_cell != Vector2i(-1, -1) else state.player.grid_pos)
		var npc = _add_actor(state, npc_def, spawn_cell, facing)
		if npc == null:
			continue
		var record_id := String(record.get("id", npc_id))
		npc.grid_item_id = record_id
		if not npc.tags.has("npc"):
			npc.tags.append("npc")
		if not npc.tags.has("poi_npc"):
			npc.tags.append("poi_npc")
		if not npc.tags.has("poi_npc:%s" % poi_type):
			npc.tags.append("poi_npc:%s" % poi_type)
		if not record_id.is_empty() and not npc.tags.has("poi_record:%s" % record_id):
			npc.tags.append("poi_record:%s" % record_id)
		reserved[spawn_cell] = true
		state.world_actor_positions[npc_id] = spawn_cell
		state.world_actor_display_names[npc_id] = String(npc.display_name)
		state.world_npc_positions[npc_id] = spawn_cell
		state.world_npc_display_names[npc_id] = String(npc.display_name)
		spawned += 1
	return spawned


func _pick_world_poi_npc_cell(state, record: Dictionary, reserved: Dictionary) -> Vector2i:
	if state == null or state.map_data == null or state.grid == null:
		return Vector2i(-1, -1)
	var interaction_cell := Vector2i(record.get("interaction_cell", Vector2i(-1, -1)))
	if interaction_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = interaction_cell + dir
		if reserved.has(cell) or not state.map_data.is_walkable(cell):
			continue
		var occupant = state.grid.get_actor(cell)
		if occupant != null and occupant != state.player:
			continue
		var score := -float(cell.distance_squared_to(state.player.grid_pos))
		for neighbor_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_cell: Vector2i = cell + neighbor_dir
			var map_cell = state.map_data.get_cell(neighbor_cell)
			if map_cell != null and not bool(map_cell.walkable):
				score += 2.5
		if score > best_score:
			best = cell
			best_score = score
	return best


func _pick_safe_zone_npc_cell_for_slot(map_data, tavern_record: Dictionary, reserved: Dictionary, slot: Dictionary) -> Vector2i:
	var candidates: Array[Dictionary] = []
	var interaction_cell: Vector2i = Vector2i(tavern_record.get("interaction_cell", Vector2i(-1, -1)))
	var protected_cells: Dictionary = _build_tavern_npc_protected_cells(tavern_record)
	var preferred_tags: Array = slot.get("preferred_tags", [])
	var avoid_tags: Array = slot.get("avoid_tags", [])
	var origin: Vector2i = Vector2i(tavern_record.get("origin", Vector2i(-1, -1)))
	var fixed_cell_local: Vector2i = Vector2i(slot.get("fixed_cell_local", Vector2i(-1, -1)))
	if origin != Vector2i(-1, -1) and fixed_cell_local != Vector2i(-1, -1):
		var fixed_cell: Vector2i = origin + fixed_cell_local
		if map_data.is_walkable(fixed_cell) and not reserved.has(fixed_cell) and not protected_cells.has(fixed_cell):
			return fixed_cell
	var anchor_cell: Vector2i = map_data.player_spawn if String(slot.get("near", "player_spawn")) == "player_spawn" else interaction_cell
	for cell_value in tavern_record.get("occupied_cells", []):
		var cell: Vector2i = Vector2i(cell_value)
		if reserved.has(cell) or not map_data.is_walkable(cell):
			continue
		if protected_cells.has(cell):
			continue
		if cell == map_data.player_spawn or cell == interaction_cell:
			continue
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		var score: float = 0.0
		for preferred_tag in preferred_tags:
			if map_cell.tags.has(String(preferred_tag)):
				score += 4.0
		for avoid_tag in avoid_tags:
			if map_cell.tags.has(String(avoid_tag)):
				score -= 4.5
		if map_cell.tags.has("building_floor"):
			score += 3.0
		elif map_cell.tags.has("building_open_ground"):
			score += 1.0
		elif map_cell.tags.has("building_door"):
			score -= 2.0
		score += float(_adjacent_blocked_count(map_data, cell)) * 2.2
		score += float(_count_walkable_cardinal_neighbors(map_data, cell)) * 0.5
		if _is_wall_hugging_tavern_cell(map_data, cell):
			score += 4.0
		if anchor_cell != Vector2i(-1, -1):
			score -= absf(cell.distance_to(anchor_cell) - 2.0) * 0.8
		candidates.append({
			"cell": cell,
			"score": score,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	for candidate in candidates:
		var cell: Vector2i = Vector2i(candidate.get("cell", Vector2i(-1, -1)))
		if cell != Vector2i(-1, -1):
			return cell
	return Vector2i(-1, -1)


func _orient_player_toward_tracked_world_npc(state) -> void:
	if state == null or state.player == null:
		return
	var tracked_npc_id: String = String(state.tracked_world_npc_id)
	if tracked_npc_id.is_empty():
		return
	var npc_cell: Vector2i = Vector2i(state.world_npc_positions.get(tracked_npc_id, Vector2i(-1, -1)))
	if npc_cell == Vector2i(-1, -1):
		return
	var delta: Vector2i = npc_cell - state.player.grid_pos
	if absi(delta.x) + absi(delta.y) != 1:
		return
	state.player.facing = delta


func _build_tavern_npc_protected_cells(tavern_record: Dictionary) -> Dictionary:
	var protected_cells: Dictionary = {}
	var interaction_cell: Vector2i = Vector2i(tavern_record.get("interaction_cell", Vector2i(-1, -1)))
	if interaction_cell != Vector2i(-1, -1):
		protected_cells[interaction_cell] = true
	for entrance_value in tavern_record.get("entrance_cells", []):
		var entrance_cell: Vector2i = Vector2i(entrance_value)
		if entrance_cell == Vector2i(-1, -1):
			continue
		protected_cells[entrance_cell] = true
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			protected_cells[entrance_cell + dir] = true
	return protected_cells


func _is_wall_hugging_tavern_cell(map_data, cell: Vector2i) -> bool:
	if map_data == null:
		return false
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = map_data.get_cell(cell + dir)
		if neighbor == null:
			continue
		if neighbor.tags.has("building_wall") or not bool(neighbor.walkable):
			return true
	return false


func _pick_enemy_spawn_cells(map_data, player_cell: Vector2i, reserved: Dictionary, required_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var min_distance: int = int(_map_config.enemy_min_distance_from_spawn)
	for _index in range(required_count):
		var cell: Vector2i = _pick_best_enemy_cell(map_data, player_cell, reserved, result, min_distance)
		if cell == Vector2i(-1, -1):
			cell = _pick_best_enemy_cell(map_data, player_cell, reserved, result, 4)
		if cell == Vector2i(-1, -1):
			break
		result.append(cell)
		reserved[cell] = true
	return result


func _pick_best_enemy_cell(map_data, player_cell: Vector2i, reserved: Dictionary, chosen_cells: Array[Vector2i], min_distance: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = -INF
	for cell in map_data.get_walkable_cells():
		if reserved.has(cell):
			continue
		if _is_safe_zone_enemy_blocked_cell(map_data, cell):
			continue
		var distance_from_player: float = cell.distance_to(player_cell)
		if distance_from_player < float(min_distance):
			continue
		var spacing_score: float = _distance_to_closest(cell, chosen_cells)
		var terrain_pressure: int = _adjacent_blocked_count(map_data, cell)
		var poi_bonus: float = 0.0
		var map_cell = map_data.get_cell(cell)
		if map_cell != null:
			if map_cell.tags.has("poi:challenge_entrance"):
				poi_bonus += 2.0
			if map_cell.tags.has("poi:ruin"):
				poi_bonus += 1.5
		var score: float = distance_from_player * 1.35 + spacing_score * 0.75 + float(terrain_pressure) * 0.6 + poi_bonus
		if score > best_score:
			best = cell
			best_score = score
	return best


func _distance_to_closest(cell: Vector2i, chosen_cells: Array[Vector2i]) -> float:
	if chosen_cells.is_empty():
		return 6.0
	var best_distance: float = INF
	for chosen in chosen_cells:
		best_distance = minf(best_distance, cell.distance_to(chosen))
	return best_distance


func _step_direction_toward(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var delta: Vector2i = to_cell - from_cell
	if absi(delta.x) >= absi(delta.y):
		return Vector2i.RIGHT if delta.x >= 0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y >= 0 else Vector2i.UP


func _adjacent_blocked_count(map_data, cell: Vector2i) -> int:
	var count: int = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not map_data.is_walkable(cell + dir):
			count += 1
	return count


func _count_walkable_cardinal_neighbors(map_data, cell: Vector2i) -> int:
	var count: int = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if map_data != null and map_data.is_walkable(cell + dir):
			count += 1
	return count


func _refresh_world_npc_tracking(state) -> void:
	if state == null:
		return
	var tracked_actor_id: String = String(state.tracked_world_actor_id)
	if tracked_actor_id.is_empty():
		tracked_actor_id = String(state.tracked_world_npc_id)
	var show_hint: bool = bool(state.show_tracked_world_actor_hint) or bool(state.show_tracked_world_npc_hint)
	if tracked_actor_id.is_empty() or not show_hint:
		state.tracked_world_actor_relative_hint = ""
		state.tracked_world_npc_relative_hint = ""
		return
	var tracked_cell: Vector2i = Vector2i(state.world_actor_positions.get(tracked_actor_id, state.world_npc_positions.get(tracked_actor_id, Vector2i(-1, -1))))
	if tracked_cell == Vector2i(-1, -1) or state.player == null:
		state.tracked_world_actor_relative_hint = ""
		state.tracked_world_npc_relative_hint = ""
		return
	var relative_hint := _relative_direction_label(state.player.grid_pos, tracked_cell)
	state.tracked_world_actor_relative_hint = relative_hint
	state.tracked_world_npc_relative_hint = relative_hint
	_refresh_world_poi_tracking(state)


func _refresh_world_poi_tracking(state) -> void:
	if state == null or state.player == null or state.map_data == null:
		return
	var boss_cell: Vector2i = _first_valid_poi_cell(state.map_data.challenge_cells)
	state.tracked_boss_poi_cell = boss_cell
	state.tracked_boss_poi_relative_hint = "" if boss_cell == Vector2i(-1, -1) else _relative_direction_label(state.player.grid_pos, boss_cell)
	var safe_zone_cell: Vector2i = state.map_data.tavern_cell
	state.tracked_safe_zone_cell = safe_zone_cell
	state.tracked_safe_zone_relative_hint = "" if safe_zone_cell == Vector2i(-1, -1) else _relative_direction_label(state.player.grid_pos, safe_zone_cell)
	var ruin_cell: Vector2i = _nearest_poi_cell(state.player.grid_pos, state.map_data.ruin_cells)
	state.tracked_nearest_ruin_cell = ruin_cell
	state.tracked_nearest_ruin_relative_hint = "" if ruin_cell == Vector2i(-1, -1) else _relative_direction_label(state.player.grid_pos, ruin_cell)


func _first_valid_poi_cell(cells: Array) -> Vector2i:
	for raw_cell in cells:
		var cell: Vector2i = Vector2i(raw_cell)
		if cell != Vector2i(-1, -1):
			return cell
	return Vector2i(-1, -1)


func _nearest_poi_cell(origin: Vector2i, cells: Array) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for raw_cell in cells:
		var cell: Vector2i = Vector2i(raw_cell)
		if cell == Vector2i(-1, -1):
			continue
		var distance: float = origin.distance_squared_to(cell)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _relative_direction_label(from_cell: Vector2i, to_cell: Vector2i) -> String:
	var delta: Vector2i = to_cell - from_cell
	if delta == Vector2i.ZERO:
		return "同一位置"
	var vertical := ""
	var horizontal := ""
	if delta.y < 0:
		vertical = "北"
	elif delta.y > 0:
		vertical = "南"
	if delta.x < 0:
		horizontal = "西"
	elif delta.x > 0:
		horizontal = "东"
	var distance: int = absi(delta.x) + absi(delta.y)
	return "%s%s（%d 格）" % [horizontal, vertical, distance]


func _pick_nearest_walkable(candidates: Array[Vector2i], preferred: Vector2i, reserved: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for cell in candidates:
		if reserved.has(cell):
			continue
		var distance: float = float(cell.distance_squared_to(preferred))
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


func _add_placeholder_prop(state, cell: Vector2i) -> void:
	var prop = GridItemStateScript.new()
	prop.setup_grid_item(_next_item_id, "world_marker", GridItemStateScript.GridItemKind.PROP, cell, false)
	_next_item_id += 1
	prop.display_name = "World Marker"
	prop.tags.append("world_slice_placeholder")
	state.grid.place_item(prop, cell)


func _add_actor(state, actor_def, cell: Vector2i, facing: Vector2i):
	var actor = ActorStateScript.new()
	actor.setup(_next_actor_id, actor_def, cell)
	_next_actor_id += 1
	actor.facing = facing if facing != Vector2i.ZERO else Vector2i.RIGHT
	state.grid.place_actor(actor, cell)
	state.add_actor(actor)
	return actor


func _add_enemy_actor(state, actor_def, cell: Vector2i, facing: Vector2i):
	var actor = _add_actor(state, actor_def, cell, facing)
	if actor != null:
		if not actor.tags.has("world_streamed_enemy"):
			actor.tags.append("world_streamed_enemy")
	return actor


func refresh_streamed_enemies(state, reason: String = "manual") -> void:
	if state == null or not bool(state.is_world_slice) or state.player == null or state.map_data == null or state.grid == null:
		return
	var despawned: int = _despawn_far_streamed_enemies(state)
	var spawned: int = _spawn_streamed_enemies_near_player(state)
	state.world_enemy_stream_refresh_count += 1
	state.world_enemy_stream_last_spawned = spawned
	state.world_enemy_stream_last_despawned = despawned
	state.world_enemy_stream_spawn_total += spawned
	state.world_enemy_stream_despawn_total += despawned
	state.world_enemy_stream_last_reason = reason
	state.world_enemy_stream_target = STREAM_DESIRED_ACTIVE_ENEMY_COUNT


func _despawn_far_streamed_enemies(state) -> int:
	var removed: int = 0
	var far_sq: int = STREAM_DESPAWN_DISTANCE * STREAM_DESPAWN_DISTANCE
	var to_remove: Array = []
	for enemy in state.get_alive_enemies():
		if enemy == null or enemy == state.player:
			continue
		if not enemy.tags.has("world_streamed_enemy"):
			continue
		if state.visible_cell_set.has(enemy.grid_pos):
			continue
		if enemy.grid_pos.distance_squared_to(state.player.grid_pos) <= far_sq:
			continue
		to_remove.append(enemy)
	for enemy in to_remove:
		state.grid.remove_actor(enemy)
		state.actors.erase(enemy)
		removed += 1
	return removed


func _spawn_streamed_enemies_near_player(state) -> int:
	var active_enemy_count: int = state.get_alive_enemies().size()
	if active_enemy_count >= STREAM_DESIRED_ACTIVE_ENEMY_COUNT:
		return 0
	var needed: int = STREAM_DESIRED_ACTIVE_ENEMY_COUNT - active_enemy_count
	var spawned: int = 0
	var reserved: Dictionary = {}
	for actor in state.actors:
		if actor != null and not actor.is_dead():
			reserved[actor.grid_pos] = true
	for cell in state.map_data.get_all_poi_cells():
		reserved[cell] = true
	var candidates: Array[Vector2i] = _pick_stream_spawn_cells(state.map_data, state.player.grid_pos, reserved, needed)
	for cell in candidates:
		var enemy_def = _pick_world_slice_stream_enemy_def(state, state.get_alive_enemies().size() + spawned)
		if _add_enemy_actor(state, enemy_def, cell, _step_direction_toward(cell, state.player.grid_pos)) != null:
			reserved[cell] = true
			spawned += 1
	return spawned


func _pick_world_slice_enemy_def_for_index(state, index: int, total_required: int):
	var force_tier: int = 0
	if String(state.world_enemy_spawn_profile) == "calm":
		if index == 0:
			force_tier = 1
		elif index >= total_required - 1:
			force_tier = 2
	return _pick_world_slice_enemy_def_by_profile(state, force_tier)


func _pick_world_slice_stream_enemy_def(state, _index: int):
	return _pick_world_slice_enemy_def_by_profile(state)


func _pick_world_slice_enemy_def_by_profile(state, forced_tier: int = 0):
	var profile_id := String(state.world_enemy_spawn_profile if state != null else "calm")
	var weights: Dictionary = Dictionary(WORLD_ENEMY_PROFILE_WEIGHTS.get(profile_id, WORLD_ENEMY_PROFILE_WEIGHTS["calm"]))
	var random_service = Engine.get_main_loop().root.get_node_or_null("/root/RandomService") if Engine.get_main_loop() is SceneTree else null
	var chosen_tier := forced_tier if forced_tier > 0 else _weighted_pick_tier(weights, random_service)
	var tier_defs: Array = Array(WORLD_ENEMY_DEFS_BY_TIER.get(chosen_tier, WORLD_ENEMY_DEFS_BY_TIER[1]))
	if tier_defs.is_empty():
		return SLIME_DEF
	if random_service != null and random_service.has_method("randi_range_value"):
		return tier_defs[int(random_service.randi_range_value(0, tier_defs.size() - 1))]
	return tier_defs[randi_range(0, tier_defs.size() - 1)]


func _weighted_pick_tier(weights: Dictionary, random_service = null) -> int:
	var total_weight := 0
	for tier_key in weights.keys():
		total_weight += maxi(0, int(weights[tier_key]))
	if total_weight <= 0:
		return 1
	var roll: int = random_service.randi_range_value(1, total_weight) if random_service != null and random_service.has_method("randi_range_value") else randi_range(1, total_weight)
	var cursor := 0
	for tier in [1, 2]:
		cursor += maxi(0, int(weights.get(tier, 0)))
		if roll <= cursor:
			return tier
	return 1


func _pick_stream_spawn_cells(map_data, player_cell: Vector2i, reserved: Dictionary, required_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map_data == null or required_count <= 0:
		return result
	var min_sq: int = STREAM_SPAWN_RADIUS_MIN * STREAM_SPAWN_RADIUS_MIN
	var max_sq: int = STREAM_SPAWN_RADIUS_MAX * STREAM_SPAWN_RADIUS_MAX
	var candidates: Array[Dictionary] = []
	for cell in map_data.get_walkable_cells():
		if reserved.has(cell):
			continue
		if _is_safe_zone_enemy_blocked_cell(map_data, cell):
			continue
		var distance_sq: int = cell.distance_squared_to(player_cell)
		if distance_sq < min_sq or distance_sq > max_sq:
			continue
		var map_cell = map_data.get_cell(cell)
		if map_cell == null:
			continue
		var poi_penalty: float = 0.0
		for tag in map_cell.tags:
			var text := String(tag)
			if text.begins_with("poi:"):
				poi_penalty += 5.0
		var score: float = float(distance_sq) + _distance_to_closest(cell, result) * 3.0 + float(_adjacent_blocked_count(map_data, cell)) * 1.25 - poi_penalty
		candidates.append({
			"cell": cell,
			"score": score,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	for candidate in candidates:
		var cell: Vector2i = Vector2i(candidate.get("cell", Vector2i(-1, -1)))
		if cell == Vector2i(-1, -1):
			continue
		var too_close_to_existing := false
		for chosen in result:
			if cell.distance_squared_to(chosen) < 16:
				too_close_to_existing = true
				break
		if too_close_to_existing:
			continue
		result.append(cell)
		if result.size() >= required_count:
			break
	return result


func _is_safe_zone_enemy_blocked_cell(map_data, cell: Vector2i) -> bool:
	if map_data == null or cell == Vector2i(-1, -1):
		return false
	var map_cell = map_data.get_cell(cell)
	if map_cell == null or not bool(map_cell.walkable):
		return false
	for tag in map_cell.tags:
		var text := String(tag)
		if text == "poi:tavern":
			return true
		if text.begins_with("structure:tavern"):
			return true
		if text.begins_with("building:tavern_"):
			return true
	return false


func _update_actor_visibility(state) -> void:
	if state == null or state.grid == null:
		return
	var visible_set: Dictionary = {}
	if not state.visible_cell_set.is_empty():
		visible_set = state.visible_cell_set
	else:
		for cell in state.visible_cells:
			visible_set[cell] = true
	for actor in state.actors:
		if actor == null:
			continue
		actor.set("revealed", visible_set.has(actor.grid_pos))


func _sync_grid_from_map_data(state) -> void:
	if state == null or state.grid == null or state.map_data == null:
		return
	for cell in state.map_data.get_all_cells():
		if not state.map_data.is_walkable(cell):
			state.grid.add_blocked(cell)
		elif _is_safe_zone_enemy_blocked_cell(state.map_data, cell):
			state.grid.add_enemy_blocked(cell)


func _build_default_map_config():
	var cfg = MapGenConfigScript.new()
	cfg.map_size = WORLD_GRID_SIZE
	cfg.enemy_count = REQUIRED_ENEMY_COUNT
	return cfg


func _make_random_seed() -> String:
	_seed_counter += 1
	return "world_slice_%d_%d" % [int(Time.get_unix_time_from_system()), _seed_counter]
