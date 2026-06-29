class_name RunSidebar
extends Control

@onready var _panel: PanelContainer = %DrawerPanel
@onready var _toggle_button: Button = %DrawerToggle
@onready var _status_button: Button = %StatusTab
@onready var _inventory_button: Button = %InventoryTab
@onready var _tabs: TabContainer = %DrawerTabs
@onready var _status_text: Label = %StatusText
@onready var _inventory_list: VBoxContainer = %InventoryList

var _expanded := false
var _inventory_items: Array = []


func _ready() -> void:
	_toggle_button.pressed.connect(toggle)
	_status_button.pressed.connect(show_status)
	_inventory_button.pressed.connect(show_inventory)
	_set_expanded(false)
	_refresh_status()
	_refresh_inventory()


func toggle() -> void:
	_set_expanded(not _expanded)


func show_status() -> void:
	_set_expanded(true)
	_tabs.current_tab = 0


func show_inventory() -> void:
	_set_expanded(true)
	_tabs.current_tab = 1


func set_inventory_items(items: Array) -> void:
	_inventory_items = items.duplicate()
	_refresh_inventory()


func update_state(state) -> void:
	if state == null or state.player == null:
		return

	var weapon_name := "-"
	var technique_ids: Array[String] = []
	if state.player.active_weapon != null:
		weapon_name = str(state.player.active_weapon.display_name)
		if state.player.active_weapon.has_method("supports_technique"):
			if bool(state.player.active_weapon.call("supports_technique", "lunge")):
				technique_ids.append("lunge")
			if bool(state.player.active_weapon.call("supports_technique", "sweep")):
				technique_ids.append("sweep")

	var trace_text := "-"
	var move_text := "-"
	var combo_text := "-"
	if state.action_trace != null:
		trace_text = state.action_trace.debug_string_for_actor(int(state.player.id), 4)
		move_text = _recent_move_dirs_text(state)
	if state.has_method("get_weapon_combo_matches_for_actor"):
		var combo_ids: Array[String] = []
		for match_data in state.get_weapon_combo_matches_for_actor(int(state.player.id), 1):
			combo_ids.append(str(match_data.get("technique_id", "")))
		combo_text = " -> ".join(combo_ids)

	var facing_text := _move_dir_label(state.player.facing)
	var visible_count: int = state.visible_cells.size()
	var explored_count: int = state.explored_cells.size()
	var visibility_reason := str(state.last_visibility_recompute_reason)

	_status_text.text = "Mode: %s\nPos: %s\nFacing: %s\nFOV Radius: %d\nVisible: %d\nExplored: %d\nReveal All: %s\nLast FOV: %s\nWeapon: %s\nTechniques: %s\nTrace: %s\nMoveDir: %s\nCombo: %s\nHP: %d / %d\nSAN: %d / %d\nRoom: %s" % [
		str(state.map_node_kind),
		str(state.player.grid_pos),
		facing_text,
		int(state.fov_radius),
		visible_count,
		explored_count,
		"on" if bool(state.reveal_all_debug) else "off",
		visibility_reason,
		weapon_name,
		(", ".join(technique_ids) if not technique_ids.is_empty() else "-"),
		trace_text,
		move_text,
		combo_text,
		state.player.hp,
		state.player.max_hp,
		state.player.san,
		state.player.max_san,
		state.room_name,
	]


func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_panel.visible = expanded
	_toggle_button.text = "◀" if expanded else "▶"
	_toggle_button.tooltip_text = "Collapse sidebar" if expanded else "Open status and inventory"


func _refresh_status() -> void:
	if not is_instance_valid(_status_text):
		return
	_status_text.text = "World slice info will appear here during play."


func _recent_move_dirs_text(state) -> String:
	if state == null or state.player == null or state.action_trace == null:
		return "-"
	var parts: Array[String] = []
	for entry in state.action_trace.get_recent_entries_for_actor(int(state.player.id), 4):
		if entry == null:
			continue
		parts.append(_move_dir_label(Vector2i(entry.move_dir)))
	return " -> ".join(parts)


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


func _refresh_inventory() -> void:
	if not is_instance_valid(_inventory_list):
		return

	for child in _inventory_list.get_children():
		child.queue_free()

	if _inventory_items.is_empty():
		var empty := Label.new()
		empty.text = "No inventory items yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.theme_type_variation = &"ScreenHint"
		_inventory_list.add_child(empty)
		return

	for item in _inventory_items:
		var label := Label.new()
		label.text = "- %s" % str(item)
		label.theme_type_variation = &"BattleMessage"
		_inventory_list.add_child(label)
