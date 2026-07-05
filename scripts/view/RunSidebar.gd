class_name RunSidebar
extends Control

signal bag_requested
signal menu_requested
signal safe_zone_poi_requested
signal boss_poi_requested
signal ruin_poi_requested

@onready var _inventory_panel: PanelContainer = %InventoryPanel
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _inventory_button: Button = %InventoryButton
@onready var _menu_button: Button = %MenuButton
@onready var _inventory_close_button: Button = %InventoryCloseButton
@onready var _debug_close_button: Button = %DebugCloseButton
@onready var _inventory_list: VBoxContainer = %InventoryList
@onready var _debug_text: Label = %DebugText
@onready var _poi_hint_panel: PanelContainer = %PoiHintPanel
@onready var _poi_hint_title: Label = %PoiHintTitle
@onready var _safe_zone_poi_hint: Button = %SafeZonePoiHint
@onready var _boss_poi_hint: Button = %BossPoiHint
@onready var _ruin_poi_hint: Button = %RuinPoiHint

var _inventory_items: Array = []
var _debug_messages: Array[String] = []
var _debug_state_text := ""


func _ready() -> void:
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_safe_zone_poi_hint.pressed.connect(func() -> void: safe_zone_poi_requested.emit())
	_boss_poi_hint.pressed.connect(func() -> void: boss_poi_requested.emit())
	_ruin_poi_hint.pressed.connect(func() -> void: ruin_poi_requested.emit())
	_inventory_close_button.pressed.connect(func() -> void: _inventory_panel.visible = false)
	_debug_close_button.pressed.connect(func() -> void: _debug_panel.visible = false)
	_refresh_inventory()
	_refresh_debug()
	_refresh_poi_hints(null)
	_inventory_panel.visible = false
	_debug_panel.visible = false
	_disable_button_focus()


func _disable_button_focus(node: Node = self) -> void:
	for child in node.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
		_disable_button_focus(child)


func show_inventory() -> void:
	_debug_panel.visible = false
	_inventory_panel.visible = not _inventory_panel.visible


func show_debug() -> void:
	_inventory_panel.visible = false
	_debug_panel.visible = not _debug_panel.visible


func _on_inventory_button_pressed() -> void:
	_inventory_panel.visible = false
	_debug_panel.visible = false
	bag_requested.emit()


func _on_menu_button_pressed() -> void:
	_inventory_panel.visible = false
	_debug_panel.visible = false
	menu_requested.emit()


func set_inventory_items(items: Array) -> void:
	_inventory_items = items.duplicate()
	_refresh_inventory()


func set_debug_messages(messages: Array) -> void:
	_debug_messages.clear()
	for message in messages:
		_debug_messages.append(String(message))
	_refresh_debug()


func update_state(state) -> void:
	if state == null or state.player == null:
		_refresh_poi_hints(null)
		return
	state.hud_refresh_count += 1
	_debug_state_text = _build_debug_state_text(state)
	_refresh_debug()
	_refresh_poi_hints(state)


func _refresh_inventory() -> void:
	if not is_instance_valid(_inventory_list):
		return

	for child in _inventory_list.get_children():
		child.queue_free()

	if _inventory_items.is_empty():
		var empty := Label.new()
		empty.text = "暂无背包物品。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.theme_type_variation = &"ScreenHint"
		_inventory_list.add_child(empty)
		return

	for item in _inventory_items:
		var label := Label.new()
		label.text = "- %s" % str(item)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"BattleMessage"
		_inventory_list.add_child(label)


func _refresh_debug() -> void:
	if not is_instance_valid(_debug_text):
		return

	var parts: Array[String] = []
	if not _debug_messages.is_empty():
		parts.append("事件记录")
		for message in _debug_messages:
			parts.append("- %s" % message)
	if not _debug_state_text.is_empty():
		if not parts.is_empty():
			parts.append("")
		parts.append("调试状态")
		parts.append(_debug_state_text)

	_debug_text.text = "\n".join(parts) if not parts.is_empty() else "调试信息会在游戏开始后显示。"


func _refresh_poi_hints(state) -> void:
	if not is_instance_valid(_poi_hint_panel):
		return
	if state == null or not bool(state.is_world_slice) or state.map_data == null or String(state.map_node_kind) != "world_slice":
		_poi_hint_panel.visible = false
		return
	_poi_hint_panel.visible = true
	if is_instance_valid(_poi_hint_title):
		_poi_hint_title.text = "导航指引"
	if is_instance_valid(_safe_zone_poi_hint):
		_safe_zone_poi_hint.text = _poi_button_text("最近安全区", String(state.tracked_safe_zone_relative_hint), String(state.focused_nav_target_label))
		_safe_zone_poi_hint.tooltip_text = "点击后只在地图上指向目标，不会自动走动。"
	if is_instance_valid(_boss_poi_hint):
		_boss_poi_hint.text = _poi_button_text("Boss遗迹", String(state.tracked_boss_poi_relative_hint), String(state.focused_nav_target_label))
		_boss_poi_hint.tooltip_text = "点击后只在地图上指向目标，不会自动走动。"
	if is_instance_valid(_ruin_poi_hint):
		_ruin_poi_hint.text = _poi_button_text("最近小遗迹", String(state.tracked_nearest_ruin_relative_hint), String(state.focused_nav_target_label))
		_ruin_poi_hint.tooltip_text = "点击后只在地图上指向目标，不会自动走动。"


func _poi_button_text(label: String, hint_text: String, focused_label: String) -> String:
	var suffix := hint_text if not hint_text.is_empty() else "未定位"
	var prefix := "已指向 · " if focused_label == label else ""
	return "%s%s：%s" % [prefix, label, suffix]


func _build_debug_state_text(state) -> String:
	if bool(state.is_world_slice) and state.map_data != null:
		return _build_world_slice_debug_text(state)

	var trace_text := "-"
	var move_text := "-"
	if state.action_trace != null:
		trace_text = state.action_trace.debug_string_for_actor(int(state.player.id), 4)
		move_text = _recent_move_dirs_text(state)

	return "Mode: %s\nPos: %s\nFacing: %s\nFOV Radius: %d\nVisible: %d\nExplored: %d\nReveal All: %s\nLast FOV: %s\nTrace: %s\nMoveDir: %s\nHP: %d / %d\nSAN: %d / %d\nRoom: %s" % [
		str(state.map_node_kind),
		str(state.player.grid_pos),
		_move_dir_label(state.player.facing),
		int(state.fov_radius),
		state.visible_cells.size(),
		state.explored_cells.size(),
		"on" if bool(state.reveal_all_debug) else "off",
		str(state.last_visibility_recompute_reason),
		trace_text,
		move_text,
		state.player.hp,
		state.player.max_hp,
		state.player.san,
		state.player.max_san,
		state.room_name,
	]


func _build_world_slice_debug_text(state) -> String:
	var terrain_counts: Dictionary = state.map_data.get_terrain_counts()
	var tracked_name := "-"
	var tracked_hint := "off"
	var boss_ruin_hint := "off"
	var safe_zone_hint := "off"
	var nearest_ruin_hint := "off"
	var tracked_actor_id := String(state.tracked_world_actor_id) if state.get("tracked_world_actor_id") != null else ""
	if tracked_actor_id.is_empty():
		tracked_actor_id = String(state.tracked_world_npc_id)
	if not tracked_actor_id.is_empty():
		tracked_name = String(state.world_actor_display_names.get(tracked_actor_id, state.world_npc_display_names.get(tracked_actor_id, tracked_actor_id)))
		var actor_hint := String(state.tracked_world_actor_relative_hint) if state.get("tracked_world_actor_relative_hint") != null else ""
		tracked_hint = actor_hint if (not actor_hint.is_empty() and bool(state.show_tracked_world_actor_hint)) else (String(state.tracked_world_npc_relative_hint) if bool(state.show_tracked_world_npc_hint) else "off")
	safe_zone_hint = String(state.tracked_safe_zone_relative_hint) if state.get("tracked_safe_zone_relative_hint") != null and not String(state.tracked_safe_zone_relative_hint).is_empty() else "off"
	boss_ruin_hint = String(state.tracked_boss_poi_relative_hint) if state.get("tracked_boss_poi_relative_hint") != null and not String(state.tracked_boss_poi_relative_hint).is_empty() else "off"
	nearest_ruin_hint = String(state.tracked_nearest_ruin_relative_hint) if state.get("tracked_nearest_ruin_relative_hint") != null and not String(state.tracked_nearest_ruin_relative_hint).is_empty() else "off"

	var render_rect: Rect2i = state.render_window_rect
	return "Mode: %s\nSeed: %s\nMap Size: %dx%d\nPlayer: %s\nFacing: %s\nCurrent Tile: %s\nProgram Edit: %s\nTracked NPC: %s\nTracked Hint: %s\n最近安全区: %s\nBoss遗迹: %s\n最近小遗迹: %s\nWindow: %s size=%s tiles=%d\nFOV Radius: %d\nVisible: %d\nExplored: %d\nReveal All: %s\nLast FOV Reason: %s\nBoard Refreshes: %d (%.2f ms)\nFOV Recomputes: %d (%.2f ms)\nHUD Refreshes: %d\nEntity Visuals: %d\nGeneration: %.2f ms\nGeneration Breakdown: %s\nEnemy Stream: active %d / target %d | refresh %d | +%d/-%d | total +%d/-%d | reason %s\nTrace: %s\nMoveDir: %s\nXP: %d\nTavern: %s\nChallenge: %d\nChest: %d\nRuin: %d\nEgg: %d\nTerrain: plain %d | forest %d | tree %d | hill %d | mountain %d | peak %d | water %d | river %d | bridge %d | swamp %d | desert %d\nReachable: %d\nUnreachable POI: %d\nCarved Passes: %d\nHotkeys: F5 same seed | F6 new seed | V reveal | M summary" % [
		str(state.map_node_kind),
		str(state.map_data.seed),
		int(state.map_data.width),
		int(state.map_data.height),
		str(state.player.grid_pos),
		_move_dir_label(state.player.facing),
		_world_slice_tile_context_text(state),
		"enabled (inside tavern)" if _key_program_editable_for_world_slice(state) else "locked (return to tavern)",
		tracked_name,
		tracked_hint,
		safe_zone_hint,
		boss_ruin_hint,
		nearest_ruin_hint,
		str(render_rect.position),
		str(render_rect.size),
		int(state.active_window_tile_count),
		int(state.fov_radius),
		state.visible_cells.size(),
		state.explored_cells.size(),
		"on" if bool(state.reveal_all_debug) else "off",
		str(state.last_visibility_recompute_reason),
		int(state.board_refresh_count),
		float(state.last_board_refresh_ms),
		int(state.fov_recompute_count),
		float(state.last_fov_ms),
		int(state.hud_refresh_count),
		int(state.entity_visual_count),
		float(state.last_generation_ms),
		_generation_breakdown_text(state.generation_breakdown_ms),
		state.get_alive_enemies().size(),
		int(state.world_enemy_stream_target),
		int(state.world_enemy_stream_refresh_count),
		int(state.world_enemy_stream_last_spawned),
		int(state.world_enemy_stream_last_despawned),
		int(state.world_enemy_stream_spawn_total),
		int(state.world_enemy_stream_despawn_total),
		str(state.world_enemy_stream_last_reason),
		state.action_trace.debug_string_for_actor(int(state.player.id), 6) if state.action_trace != null else "-",
		_recent_move_dirs_text(state),
		int(state.player_xp),
		str(state.map_data.tavern_cell),
		state.map_data.challenge_cells.size(),
		state.map_data.chest_cells.size(),
		state.map_data.ruin_cells.size(),
		state.map_data.easter_egg_cells.size(),
		int(terrain_counts.get("plain", 0)),
		int(terrain_counts.get("forest", 0)),
		int(terrain_counts.get("tree", 0)),
		int(terrain_counts.get("hill", 0)),
		int(terrain_counts.get("mountain", 0)),
		int(terrain_counts.get("peak", 0)),
		int(terrain_counts.get("water", 0)),
		int(terrain_counts.get("river", 0)),
		int(terrain_counts.get("bridge", 0)),
		int(terrain_counts.get("swamp", 0)),
		int(terrain_counts.get("desert", 0)),
		int(state.map_data.reachable_count),
		int(state.map_data.unreachable_poi_count),
		int(state.map_data.carved_pass_count),
	]


func _recent_move_dirs_text(state) -> String:
	if state == null or state.player == null or state.action_trace == null:
		return "-"
	var parts: Array[String] = []
	for entry in state.action_trace.get_recent_entries_for_actor(int(state.player.id), 4):
		if entry == null:
			continue
		parts.append(_move_dir_label(Vector2i(entry.move_dir)))
	return " -> ".join(parts) if not parts.is_empty() else "-"


func _move_dir_label(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "U"
	if direction == Vector2i.DOWN:
		return "D"
	if direction == Vector2i.LEFT:
		return "L"
	if direction == Vector2i.RIGHT:
		return "R"
	return "-"



func _generation_breakdown_text(breakdown: Dictionary) -> String:
	if breakdown == null or breakdown.is_empty():
		return "-"
	var parts: Array[String] = []
	for key in [
		"fill_plain_ms",
		"mountain_generation_ms",
		"terrain_generation_ms",
		"river_generation_ms",
		"poi_placement_ms",
		"obstacle_generation_ms",
		"connectivity_ms",
	]:
		if breakdown.has(key):
			parts.append("%s %.2f" % [String(key).trim_suffix("_ms"), float(breakdown[key])])
	return ", ".join(parts) if not parts.is_empty() else "-"


func _world_slice_tile_context_text(state) -> String:
	if state == null or state.player == null or state.map_data == null:
		return "-"
	var map_cell = state.map_data.get_cell(state.player.grid_pos)
	if map_cell == null:
		return "-"
	var parts: Array[String] = []
	if map_cell.has_method("terrain_name"):
		parts.append(String(map_cell.terrain_name()))
	for tag in map_cell.tags:
		var text := String(tag)
		if text.begins_with("poi:"):
			parts.append(text.trim_prefix("poi:"))
			break
	if map_cell.tags.has("building_floor"):
		parts.append("building floor")
	elif map_cell.tags.has("building_door"):
		parts.append("door")
	elif map_cell.tags.has("building_open_ground"):
		parts.append("yard")
	elif map_cell.tags.has("tree_block"):
		parts.append("tree blocker")
	return " / ".join(parts)


func _key_program_editable_for_world_slice(state) -> bool:
	if state == null or state.player == null or state.map_data == null:
		return false
	var map_cell = state.map_data.get_cell(state.player.grid_pos)
	if map_cell == null:
		return false
	if not bool(map_cell.walkable):
		return false
	for tag in map_cell.tags:
		var text := String(tag)
		if text == "poi:tavern" or text.begins_with("structure:tavern") or text.begins_with("building:tavern_"):
			return true
	return false
