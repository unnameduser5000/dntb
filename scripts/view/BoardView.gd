class_name BoardView
extends Control

const BoardCellScene := preload("res://scenes/map/BoardCell.tscn")
const TILE_TEXTURE_BASE_PATH := "res://art/tiles/board/"
const EXPLORED_FOG_ALPHA := 0.52
const EXPLORED_FOG_COLOR := Color(0.05, 0.06, 0.08, 1.0)
const EXPLORED_FOG_DESATURATE := 0.18

@export var cell_size: int = 52
@export var board_origin: Vector2 = Vector2(380, 120)
@export var world_slice_window_size: Vector2i = Vector2i(29, 29)
@export var world_slice_min_cell_size: int = 14
@export var world_slice_max_cell_size: int = 20
@export var world_slice_left_margin: int = 24
@export var world_slice_top_margin: int = 84
@export var world_slice_bottom_margin: int = 24
@export var world_slice_reserved_right_width: int = 404
@export var world_slice_right_gap: int = 24

@export var world_slice_zoom_min: int = 15
@export var world_slice_zoom_max: int = 45
@export var world_slice_zoom_step: int = 6

signal pan_refresh_requested

@onready var _grid: GridContainer = %AsciiGrid
var _render_window_origin: Vector2i = Vector2i.ZERO
var _render_window_size: Vector2i = Vector2i.ZERO
var _cell_pool: Array[Label] = []
var _pool_window_size: Vector2i = Vector2i.ZERO
var _pool_cell_size: int = -1
var _stylebox_cache: Dictionary = {}
var _texture_stylebox_cache: Dictionary = {}
var _loaded_tile_textures: Dictionary = {}
var _derived_tile_textures: Dictionary = {}

var _base_world_slice_window_size: Vector2i = Vector2i(29, 29)
var _zoom_window_size: Vector2i = Vector2i(29, 29)
var _pan_offset: Vector2i = Vector2i.ZERO
var _map_control_mode: String = "pointer"
var _is_panning: bool = false
var _pan_last_mouse: Vector2 = Vector2.ZERO
var _pan_accum: Vector2 = Vector2.ZERO
var _last_state = null


func _ready() -> void:
	position = board_origin
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_world_slice_window_size = world_slice_window_size
	_zoom_window_size = world_slice_window_size
	_rebuild_cell_pool(_compute_pool_size())


func grid_to_world(cell: Vector2i) -> Vector2:
	return position + Vector2(
		(cell.x - _render_window_origin.x) * (cell_size + 1),
		(cell.y - _render_window_origin.y) * (cell_size + 1)
	)


func world_to_grid(pos: Vector2) -> Vector2i:
	var local: Vector2 = pos - position
	return _render_window_origin + Vector2i(
		floori(local.x / float(cell_size + 1)),
		floori(local.y / float(cell_size + 1))
	)


func is_cell_in_render_window(cell: Vector2i) -> bool:
	return Rect2i(_render_window_origin, _render_window_size).has_point(cell)


func set_map_control_mode(mode: String) -> void:
	_map_control_mode = mode
	_is_panning = false
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "pan" else Control.MOUSE_FILTER_IGNORE


func zoom_in() -> void:
	_apply_zoom(-world_slice_zoom_step)


func zoom_out() -> void:
	_apply_zoom(world_slice_zoom_step)


func _apply_zoom(delta_cells: int) -> void:
	var next: int = clampi(_zoom_window_size.x + delta_cells, world_slice_zoom_min, world_slice_zoom_max)
	_zoom_window_size = Vector2i(next, next)


func reset_pan() -> void:
	_pan_offset = Vector2i.ZERO
	_pan_accum = Vector2.ZERO


func recenter_on_player() -> void:
	reset_pan()


func reset_map_controls() -> void:
	_base_world_slice_window_size = world_slice_window_size
	_zoom_window_size = world_slice_window_size
	reset_pan()
	set_map_control_mode("pointer")


func _gui_input(event: InputEvent) -> void:
	if _map_control_mode != "pan":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_panning = event.pressed
		_pan_last_mouse = event.position
		_pan_accum = Vector2.ZERO
		accept_event()
	elif event is InputEventMouseMotion and _is_panning:
		var stride: float = float(cell_size + 1)
		_pan_accum += _pan_last_mouse - event.position
		_pan_last_mouse = event.position
		var dx: int = int(_pan_accum.x / stride)
		var dy: int = int(_pan_accum.y / stride)
		if dx != 0 or dy != 0:
			_pan_offset += Vector2i(dx, dy)
			_pan_accum -= Vector2(dx, dy) * stride
			_request_pan_refresh()
		accept_event()


func _request_pan_refresh() -> void:
	if _last_state == null:
		return
	render(_last_state)
	pan_refresh_requested.emit()


func render(state) -> void:
	_last_state = state
	if state != null and bool(state.is_world_slice):
		_apply_world_slice_layout()
	var started_at: int = Time.get_ticks_msec()
	var render_window: Rect2i = _compute_render_window(state)
	_render_window_origin = render_window.position
	_render_window_size = render_window.size
	_ensure_cell_pool(_render_window_size)
	_grid.columns = max(1, _render_window_size.x)
	var active_tile_count: int = _render_window_size.x * _render_window_size.y

	if state != null:
		state.render_window_rect = render_window
		state.active_window_tile_count = active_tile_count
		state.board_refresh_count += 1

	var pool_index: int = 0
	for y in range(_render_window_origin.y, _render_window_origin.y + _render_window_size.y):
		for x in range(_render_window_origin.x, _render_window_origin.x + _render_window_size.x):
			var cell: Vector2i = Vector2i(x, y)
			_apply_cell_visual(_cell_pool[pool_index], _describe_cell(cell, state))
			pool_index += 1

	for index in range(pool_index, _cell_pool.size()):
		_cell_pool[index].visible = false

	if state != null:
		state.last_board_refresh_ms = float(Time.get_ticks_msec() - started_at)


func _compute_render_window(state) -> Rect2i:
	if state == null or state.grid == null:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	if not bool(state.is_world_slice):
		return Rect2i(Vector2i.ZERO, Vector2i(state.grid.width, state.grid.height))

	var grid_width: int = int(state.grid.width)
	var grid_height: int = int(state.grid.height)
	var window_size: Vector2i = Vector2i(
		min(_zoom_window_size.x, grid_width),
		min(_zoom_window_size.y, grid_height)
	)
	if window_size.x <= 0 or window_size.y <= 0:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	var player_cell: Vector2i = Vector2i.ZERO
	if state.player != null:
		player_cell = Vector2i(state.player.grid_pos)

	var half_window: Vector2i = Vector2i(int(window_size.x / 2), int(window_size.y / 2))
	var desired: Vector2i = player_cell - half_window + _pan_offset
	var origin: Vector2i = Vector2i(
		clampi(desired.x, 0, max(0, grid_width - window_size.x)),
		clampi(desired.y, 0, max(0, grid_height - window_size.y))
	)
	return Rect2i(origin, window_size)


func _describe_cell(cell: Vector2i, state) -> Dictionary:
	var has_visibility_layer: bool = _has_visibility_layer(state)
	var reveal_all: bool = bool(state.reveal_all_debug) if has_visibility_layer else true
	var is_visible: bool = reveal_all or _cell_in_set(state, "visible_cell_set", "visible_cells", cell)
	var is_explored: bool = is_visible or _cell_in_set(state, "explored_cell_set", "explored_cells", cell)
	var is_danger: bool = state.danger_cells.has(cell)
	var is_preview_move: bool = state.preview_move_cells.has(cell)
	var is_preview_attack: bool = state.preview_attack_cells.has(cell)

	if has_visibility_layer and not is_explored:
		return {
			"char": " ",
			"style": "BoardUnseenCell",
			"tooltip": "Unseen",
		}

	var actor = state.grid.get_actor(cell)
	if actor != null and (is_visible or reveal_all):
		var char: String = String(actor.map_char())
		if actor.team == "player":
			char = _player_facing_char(actor.facing)
		return {
			"char": char,
			"style": _actor_cell_style(actor, is_danger, is_preview_move, is_preview_attack),
			"tooltip": _actor_tooltip(actor, is_danger, is_preview_move, is_preview_attack),
		}

	if (is_visible or reveal_all) and state.items_at.has(cell):
		return {
			"char": String(state.items_at[cell]),
			"style": _preview_cell_style(is_danger, is_preview_move, is_preview_attack, "BoardItemCell"),
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + "Key token: %s" % String(state.items_at[cell]),
		}

	var grid_items: Array = state.grid.get_grid_items(cell)
	if (is_visible or reveal_all) and not grid_items.is_empty():
		var grid_item = grid_items[0]
		if grid_item != null and grid_item != actor:
			return {
				"char": String(grid_item.get_grid_display_name()).substr(0, 1).to_upper(),
				"style": "BoardItemCell",
				"tooltip": String(grid_item.get_grid_display_name()),
			}

	if cell == state.exit_cell:
		var is_open: bool = state.get_alive_enemies().is_empty()
		return {
			"char": "X",
			"style": _preview_cell_style(is_danger, is_preview_move, is_preview_attack, "BoardExitOpenCell" if is_open else "BoardExitLockedCell"),
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + ("Exit open" if is_open else "Exit locked"),
		}

	if is_preview_attack:
		return {
			"char": "*",
			"style": "BoardPreviewAttackCell",
			"tooltip": "Predicted attack cell",
		}

	if is_preview_move:
		return {
			"char": "+",
			"style": "BoardPreviewMoveCell",
			"tooltip": "Predicted movement path",
		}

	if is_danger:
		return {
			"char": "!",
			"style": "BoardDangerCell",
			"tooltip": "Threatened by enemy action",
		}

	return _describe_terrain_cell(cell, state, is_visible)


func _describe_terrain_cell(cell: Vector2i, state, is_visible: bool) -> Dictionary:
	var terrain_char: String = "."
	var terrain_name: String = "floor"
	var walkable: bool = not state.grid.is_blocked(cell)
	var blocks_vision: bool = false
	var style: String = "BoardFloorCell" if is_visible else "BoardExploredCell"
	var palette: Dictionary = {}
	var tile_texture_id: String = ""
	if not walkable:
		style = "BoardWallCell"

	if state.map_data != null:
		var map_cell = state.map_data.get_cell(cell)
		if map_cell != null:
			terrain_char = String(map_cell.terrain_symbol()) if map_cell.has_method("terrain_symbol") else "."
			terrain_name = String(map_cell.terrain_name()) if map_cell.has_method("terrain_name") else "terrain"
			walkable = bool(map_cell.walkable)
			blocks_vision = bool(map_cell.blocks_vision)
			if not walkable:
				style = "BoardWallCell"
			palette = _terrain_palette_for_map_cell(map_cell, is_visible)
			tile_texture_id = _tile_texture_id_for_map_cell(map_cell)
			var context: String = _terrain_context_label(map_cell)
			if not context.is_empty():
				terrain_name = "%s / %s" % [terrain_name, context]

	return {
		"char": terrain_char if walkable or state.map_data != null else "#",
		"style": style,
		"tile_texture_id": tile_texture_id,
		"fog_overlay_alpha": 0.0 if is_visible else EXPLORED_FOG_ALPHA,
		"bg_color": palette.get("bg_color", null),
		"font_color": palette.get("font_color", null),
		"border_color": palette.get("border_color", null),
		"tooltip": "%s | walkable: %s | blocks vision: %s" % [
			terrain_name,
			"yes" if walkable else "no",
			"yes" if blocks_vision else "no",
		],
	}


func _make_cell_label(cell_data: Dictionary) -> Label:
	var label: Label = BoardCellScene.instantiate() as Label
	label.custom_minimum_size = Vector2(cell_size, cell_size)
	label.text = String(cell_data["char"])
	label.tooltip_text = String(cell_data["tooltip"])
	label.theme_type_variation = StringName(cell_data["style"])
	return label


func _apply_cell_visual(label: Label, cell_data: Dictionary) -> void:
	if label == null:
		return
	label.visible = true
	label.custom_minimum_size = Vector2(cell_size, cell_size)
	label.text = String(cell_data["char"])
	label.tooltip_text = String(cell_data["tooltip"])
	label.theme_type_variation = StringName(cell_data["style"])
	_apply_dynamic_palette(label, cell_data)


func _actor_cell_style(actor, is_danger: bool, is_preview_move: bool, is_preview_attack: bool) -> String:
	if is_preview_attack:
		return "BoardPreviewAttackCell"
	if is_preview_move:
		return "BoardPreviewMoveCell"
	if actor.team == "enemy":
		return "BoardEnemyCell"
	return "BoardDangerCell" if is_danger else "BoardPlayerCell"


func _actor_tooltip(actor, is_danger: bool, is_preview_move: bool, is_preview_attack: bool) -> String:
	var tooltip: String = "%s HP %d/%d" % [actor.def.display_name, actor.hp, actor.max_hp]
	if is_preview_attack:
		tooltip = "Predicted attack / " + tooltip
	elif is_preview_move:
		tooltip = "Predicted move / " + tooltip
	if is_danger:
		tooltip = "Danger / " + tooltip
	return tooltip


func _danger_prefix(is_danger: bool) -> String:
	return "Danger / " if is_danger else ""


func _preview_prefix(is_preview_move: bool, is_preview_attack: bool) -> String:
	if is_preview_attack:
		return "Predicted attack / "
	if is_preview_move:
		return "Predicted move / "
	return ""


func _preview_cell_style(is_danger: bool, is_preview_move: bool, is_preview_attack: bool, fallback_style: String) -> String:
	if is_preview_attack:
		return "BoardPreviewAttackCell"
	if is_preview_move:
		return "BoardPreviewMoveCell"
	if is_danger:
		return "BoardDangerCell"
	return fallback_style


func _player_facing_char(facing: Vector2i) -> String:
	if facing == Vector2i.UP:
		return "^"
	if facing == Vector2i.DOWN:
		return "v"
	if facing == Vector2i.LEFT:
		return "<"
	return ">"


func _has_visibility_layer(state) -> bool:
	if state == null:
		return false
	if bool(state.is_world_slice):
		return true
	return state.visible_cells.size() > 0 or state.explored_cells.size() > 0 or bool(state.reveal_all_debug)


func _ensure_cell_pool(window_size: Vector2i) -> void:
	if window_size == _pool_window_size and _pool_cell_size == cell_size and _cell_pool.size() == window_size.x * window_size.y:
		return
	_rebuild_cell_pool(window_size)


func _rebuild_cell_pool(window_size: Vector2i) -> void:
	for child in _grid.get_children():
		child.free()
	_cell_pool.clear()
	_pool_window_size = window_size
	_pool_cell_size = cell_size
	if window_size.x <= 0 or window_size.y <= 0:
		return
	_grid.columns = max(1, window_size.x)
	var total_cells: int = window_size.x * window_size.y
	for _index in range(total_cells):
		var label: Label = BoardCellScene.instantiate() as Label
		label.custom_minimum_size = Vector2(cell_size, cell_size)
		label.visible = true
		_grid.add_child(label)
		_cell_pool.append(label)


func _compute_pool_size() -> Vector2i:
	return Vector2i(max(1, world_slice_zoom_max), max(1, world_slice_zoom_max))


func _apply_world_slice_layout() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return

	var available_width: float = maxf(120.0, viewport_rect.size.x - float(world_slice_left_margin + world_slice_reserved_right_width + world_slice_right_gap))
	var available_height: float = maxf(120.0, viewport_rect.size.y - float(world_slice_top_margin + world_slice_bottom_margin))
	var width_steps: int = max(1, _zoom_window_size.x)
	var height_steps: int = max(1, _zoom_window_size.y)
	var fit_cell_width: int = int(floor((available_width - float(width_steps - 1)) / float(width_steps)))
	var fit_cell_height: int = int(floor((available_height - float(height_steps - 1)) / float(height_steps)))
	cell_size = clampi(mini(fit_cell_width, fit_cell_height), world_slice_min_cell_size, world_slice_max_cell_size)

	var board_pixels: Vector2 = _window_pixel_size(_zoom_window_size)
	var pane_origin := Vector2(float(world_slice_left_margin), float(world_slice_top_margin))
	board_origin = Vector2(
		pane_origin.x + floor(maxf(0.0, (available_width - board_pixels.x) * 0.5)),
		pane_origin.y + floor(maxf(0.0, (available_height - board_pixels.y) * 0.5))
	)
	position = board_origin


func _window_pixel_size(window_size: Vector2i) -> Vector2:
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector2.ZERO
	return Vector2(
		float(window_size.x * cell_size + max(0, window_size.x - 1)),
		float(window_size.y * cell_size + max(0, window_size.y - 1))
	)


func _cell_in_set(state, set_name: String, array_name: String, cell: Vector2i) -> bool:
	if state == null:
		return false
	var set_value = state.get(set_name)
	if set_value is Dictionary:
		return set_value.has(cell)
	var array_value = state.get(array_name)
	if array_value is Array:
		return array_value.has(cell)
	return false


func _terrain_palette_for_map_cell(map_cell, is_visible: bool) -> Dictionary:
	if map_cell == null:
		return {}
	var bg_color: Color = Color(0.18, 0.16, 0.13, 1.0)
	var font_color: Color = Color(0.82, 0.78, 0.68, 1.0)
	var border_color: Color = Color(0.08, 0.08, 0.09, 0.72)
	var poi_type: String = _poi_type_for_map_cell(map_cell)

	if map_cell.tags.has("building_door"):
		match poi_type:
			"tavern":
				bg_color = Color(0.62, 0.38, 0.16, 1.0)
				font_color = Color(0.99, 0.93, 0.78, 1.0)
				border_color = Color(0.35, 0.17, 0.04, 0.96)
			"challenge_entrance":
				bg_color = Color(0.36, 0.31, 0.42, 1.0)
				font_color = Color(0.91, 0.9, 0.99, 1.0)
				border_color = Color(0.16, 0.13, 0.24, 0.96)
			"ruin":
				bg_color = Color(0.38, 0.36, 0.28, 1.0)
				font_color = Color(0.92, 0.94, 0.84, 1.0)
				border_color = Color(0.17, 0.15, 0.1, 0.95)
			"shrine":
				bg_color = Color(0.42, 0.28, 0.5, 1.0)
				font_color = Color(0.96, 0.91, 1.0, 1.0)
				border_color = Color(0.2, 0.1, 0.26, 0.96)
			_:
				bg_color = Color(0.56, 0.36, 0.18, 1.0)
				font_color = Color(0.97, 0.92, 0.78, 1.0)
				border_color = Color(0.28, 0.16, 0.05, 0.95)
	elif map_cell.tags.has("building_floor"):
		match poi_type:
			"tavern":
				bg_color = Color(0.43, 0.3, 0.18, 1.0)
				font_color = Color(0.98, 0.92, 0.78, 1.0)
				border_color = Color(0.21, 0.12, 0.05, 0.88)
			"challenge_entrance":
				bg_color = Color(0.28, 0.26, 0.34, 1.0)
				font_color = Color(0.88, 0.89, 0.96, 1.0)
				border_color = Color(0.12, 0.11, 0.18, 0.88)
			"ruin":
				bg_color = Color(0.31, 0.33, 0.24, 1.0)
				font_color = Color(0.9, 0.95, 0.83, 1.0)
				border_color = Color(0.12, 0.14, 0.09, 0.86)
			"chest":
				bg_color = Color(0.45, 0.37, 0.18, 1.0)
				font_color = Color(0.99, 0.95, 0.72, 1.0)
				border_color = Color(0.24, 0.18, 0.05, 0.9)
			"easter_egg":
				bg_color = Color(0.22, 0.38, 0.35, 1.0)
				font_color = Color(0.88, 0.99, 0.96, 1.0)
				border_color = Color(0.08, 0.18, 0.16, 0.88)
			"shrine":
				bg_color = Color(0.34, 0.24, 0.42, 1.0)
				font_color = Color(0.95, 0.89, 1.0, 1.0)
				border_color = Color(0.15, 0.08, 0.2, 0.9)
			_:
				bg_color = Color(0.39, 0.29, 0.19, 1.0)
				font_color = Color(0.96, 0.91, 0.78, 1.0)
				border_color = Color(0.18, 0.12, 0.08, 0.85)
	elif map_cell.tags.has("building_open_ground"):
		match poi_type:
			"tavern":
				bg_color = Color(0.36, 0.31, 0.21, 1.0)
				font_color = Color(0.92, 0.88, 0.74, 1.0)
				border_color = Color(0.17, 0.13, 0.08, 0.78)
			"challenge_entrance":
				bg_color = Color(0.26, 0.29, 0.31, 1.0)
				font_color = Color(0.85, 0.89, 0.93, 1.0)
				border_color = Color(0.1, 0.13, 0.15, 0.8)
			"ruin":
				bg_color = Color(0.29, 0.32, 0.22, 1.0)
				font_color = Color(0.88, 0.92, 0.81, 1.0)
				border_color = Color(0.11, 0.14, 0.08, 0.8)
			_:
				bg_color = Color(0.34, 0.31, 0.24, 1.0)
				font_color = Color(0.88, 0.85, 0.76, 1.0)
				border_color = Color(0.18, 0.15, 0.11, 0.75)
	elif map_cell.tags.has("interactable"):
		bg_color = Color(0.54, 0.45, 0.18, 1.0)
		font_color = Color(0.12, 0.1, 0.05, 1.0)
		border_color = Color(0.3, 0.23, 0.06, 0.95)
	else:
		match int(map_cell.terrain_type):
			1: # FOREST
				bg_color = Color(0.16, 0.28, 0.16, 1.0)
				font_color = Color(0.74, 0.9, 0.72, 1.0)
				border_color = Color(0.06, 0.14, 0.07, 0.82)
			2: # TREE
				bg_color = Color(0.08, 0.22, 0.1, 1.0)
				font_color = Color(0.75, 0.96, 0.76, 1.0)
				border_color = Color(0.03, 0.1, 0.04, 0.92)
			3: # ROCK
				bg_color = Color(0.32, 0.33, 0.37, 1.0)
				font_color = Color(0.9, 0.92, 0.96, 1.0)
				border_color = Color(0.14, 0.15, 0.18, 0.88)
			4: # STATUE
				bg_color = Color(0.44, 0.42, 0.49, 1.0)
				font_color = Color(0.98, 0.98, 1.0, 1.0)
				border_color = Color(0.2, 0.18, 0.24, 0.92)
			5: # STRUCTURE_WALL
				bg_color = Color(0.27, 0.2, 0.16, 1.0)
				font_color = Color(0.92, 0.85, 0.72, 1.0)
				border_color = Color(0.12, 0.08, 0.06, 0.95)
			6: # HILL
				bg_color = Color(0.42, 0.33, 0.21, 1.0)
				font_color = Color(0.98, 0.9, 0.72, 1.0)
				border_color = Color(0.2, 0.14, 0.08, 0.84)
			7: # MOUNTAIN
				bg_color = Color(0.34, 0.34, 0.36, 1.0)
				font_color = Color(0.95, 0.95, 0.98, 1.0)
				border_color = Color(0.16, 0.16, 0.18, 0.92)
			8: # PEAK
				bg_color = Color(0.56, 0.58, 0.64, 1.0)
				font_color = Color(0.09, 0.11, 0.15, 1.0)
				border_color = Color(0.28, 0.3, 0.36, 0.94)
			9: # WATER
				bg_color = Color(0.07, 0.27, 0.44, 1.0)
				font_color = Color(0.82, 0.94, 1.0, 1.0)
				border_color = Color(0.02, 0.13, 0.25, 0.9)
			10: # RIVER
				bg_color = Color(0.04, 0.34, 0.56, 1.0)
				font_color = Color(0.9, 0.98, 1.0, 1.0)
				border_color = Color(0.02, 0.16, 0.28, 0.94)
			11: # BRIDGE
				bg_color = Color(0.53, 0.4, 0.24, 1.0)
				font_color = Color(0.12, 0.08, 0.04, 1.0)
				border_color = Color(0.26, 0.18, 0.09, 0.92)
			12: # SWAMP
				bg_color = Color(0.26, 0.29, 0.14, 1.0)
				font_color = Color(0.9, 0.96, 0.72, 1.0)
				border_color = Color(0.11, 0.12, 0.05, 0.88)
			13: # DESERT
				bg_color = Color(0.61, 0.48, 0.24, 1.0)
				font_color = Color(0.18, 0.12, 0.03, 1.0)
				border_color = Color(0.31, 0.21, 0.07, 0.86)
			_:
				bg_color = Color(0.18, 0.16, 0.13, 1.0)
				font_color = Color(0.82, 0.78, 0.68, 1.0)
				border_color = Color(0.08, 0.08, 0.09, 0.72)

	if not is_visible:
		bg_color = bg_color.lerp(Color(0.05, 0.05, 0.06, 1.0), 0.58)
		font_color = font_color.lerp(Color(0.36, 0.36, 0.38, 1.0), 0.55)
		border_color = border_color.lerp(Color(0.03, 0.03, 0.04, 1.0), 0.45)
	return {
		"bg_color": bg_color,
		"font_color": font_color,
		"border_color": border_color,
	}


func _terrain_context_label(map_cell) -> String:
	if map_cell == null:
		return ""
	var contexts: Array[String] = []
	var poi_type: String = _poi_type_for_map_cell(map_cell)
	if not poi_type.is_empty():
		contexts.append(poi_type)
	if map_cell.tags.has("building_floor"):
		contexts.append("building floor")
	elif map_cell.tags.has("building_open_ground"):
		contexts.append("building yard")
	elif map_cell.tags.has("building_door"):
		contexts.append("building door")
	elif map_cell.tags.has("building_wall"):
		contexts.append("building wall")
	if map_cell.tags.has("tree_block"):
		contexts.append("tree blocker")
	if map_cell.tags.has("interactable"):
		for tag in map_cell.tags:
			var text := String(tag)
			if text.begins_with("poi:"):
				contexts.append(text.trim_prefix("poi:"))
				break
	return ", ".join(contexts)


func _poi_type_for_map_cell(map_cell) -> String:
	if map_cell == null:
		return ""
	for tag in map_cell.tags:
		var text := String(tag)
		if text.begins_with("poi:"):
			return text.trim_prefix("poi:")
	return ""


func _apply_dynamic_palette(label: Label, cell_data: Dictionary) -> void:
	if label == null:
		return
	var bg_variant = cell_data.get("bg_color", null)
	var font_variant = cell_data.get("font_color", null)
	var border_variant = cell_data.get("border_color", null)
	var tile_texture_id: String = String(cell_data.get("tile_texture_id", ""))
	var fog_overlay_alpha: float = clampf(float(cell_data.get("fog_overlay_alpha", 0.0)), 0.0, 1.0)
	if bg_variant is Color and font_variant is Color and border_variant is Color:
		var bg_color: Color = bg_variant
		var font_color: Color = font_variant
		var border_color: Color = border_variant
		if not tile_texture_id.is_empty():
			label.add_theme_stylebox_override("normal", _textured_stylebox_for_palette(tile_texture_id, bg_color, font_color, border_color, fog_overlay_alpha))
		else:
			label.add_theme_stylebox_override("normal", _stylebox_for_palette(bg_color, border_color))
		label.add_theme_color_override("font_color", font_color)
	else:
		label.remove_theme_stylebox_override("normal")
		label.remove_theme_color_override("font_color")


func _stylebox_for_palette(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var cache_key := "%s|%s" % [bg_color.to_html(), border_color.to_html()]
	if _stylebox_cache.has(cache_key):
		return _stylebox_cache[cache_key]
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	_stylebox_cache[cache_key] = style
	return style


func _textured_stylebox_for_palette(tile_texture_id: String, bg_color: Color, font_color: Color, border_color: Color, fog_overlay_alpha: float = 0.0) -> StyleBoxTexture:
	var cache_key := "%s|%s|%s|%s|%.3f" % [tile_texture_id, bg_color.to_html(), font_color.to_html(), border_color.to_html(), fog_overlay_alpha]
	if _texture_stylebox_cache.has(cache_key):
		return _texture_stylebox_cache[cache_key]
	var style := StyleBoxTexture.new()
	style.texture = _get_tile_texture(tile_texture_id, bg_color, font_color, border_color, fog_overlay_alpha)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_texture_stylebox_cache[cache_key] = style
	return style


func _tile_texture_id_for_map_cell(map_cell) -> String:
	if map_cell == null:
		return ""
	var poi_type: String = _poi_type_for_map_cell(map_cell)
	if map_cell.tags.has("building_door"):
		return "building_door"
	if map_cell.tags.has("building_floor"):
		match poi_type:
			"challenge_entrance":
				return "challenge_floor"
			"ruin":
				return "ruin_floor"
			"shrine":
				return "shrine_floor"
		return "building_floor"
	if map_cell.tags.has("building_open_ground"):
		return "building_yard"
	match int(map_cell.terrain_type):
		1:
			return "forest"
		2:
			return "tree"
		3:
			return "rock"
		4:
			return "statue"
		5:
			return "structure_wall"
		6:
			return "hill"
		7:
			return "mountain"
		8:
			return "peak"
		9:
			return "water"
		10:
			return "river"
		11:
			return "bridge"
		12:
			return "swamp"
		13:
			return "desert"
		_:
			return "plain"


func _generate_tile_texture(tile_texture_id: String, bg_color: Color, font_color: Color, border_color: Color) -> Texture2D:
	var size: int = 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(bg_color)
	var dark: Color = bg_color.lerp(border_color, 0.72)
	var light: Color = bg_color.lerp(font_color, 0.5)
	var strong: Color = font_color.lerp(Color.WHITE, 0.2)
	_fill_rect(image, Rect2i(0, 0, size, 1), border_color)
	_fill_rect(image, Rect2i(0, size - 1, size, 1), border_color)
	_fill_rect(image, Rect2i(0, 0, 1, size), border_color)
	_fill_rect(image, Rect2i(size - 1, 0, 1, size), border_color)

	match tile_texture_id:
		"plain":
			for pos in [Vector2i(14, 16), Vector2i(36, 22), Vector2i(20, 40), Vector2i(46, 44)]:
				_fill_rect(image, Rect2i(pos.x, pos.y, 4, 4), light)
				_fill_rect(image, Rect2i(pos.x + 1, pos.y + 1, 2, 2), strong)
		"forest":
			for x in [10, 24, 38, 52]:
				_fill_rect(image, Rect2i(x, 6, 2, 52), dark)
			for pos in [Vector2i(6, 12), Vector2i(18, 28), Vector2i(30, 14), Vector2i(44, 26), Vector2i(16, 46), Vector2i(40, 44)]:
				_fill_rect(image, Rect2i(pos.x, pos.y, 6, 4), light)
		"tree":
			_fill_rect(image, Rect2i(28, 38, 8, 16), dark)
			for rect in [Rect2i(16, 14, 14, 12), Rect2i(26, 10, 16, 14), Rect2i(38, 16, 12, 10), Rect2i(18, 24, 14, 10), Rect2i(34, 24, 14, 12)]:
				_fill_rect(image, rect, light)
		"rock":
			for rect in [Rect2i(12, 28, 16, 12), Rect2i(28, 18, 20, 16), Rect2i(34, 36, 12, 10)]:
				_fill_rect(image, rect, light)
				_fill_rect(image, Rect2i(rect.position.x + 2, rect.position.y + 2, max(2, rect.size.x - 6), max(2, rect.size.y - 6)), dark)
		"statue":
			_fill_rect(image, Rect2i(24, 14, 16, 8), light)
			_fill_rect(image, Rect2i(28, 22, 8, 24), strong)
			_fill_rect(image, Rect2i(22, 46, 20, 8), dark)
		"structure_wall":
			for y in [10, 24, 38, 52]:
				_fill_rect(image, Rect2i(4, y, 56, 2), dark)
			for x in [12, 28, 44]:
				_fill_rect(image, Rect2i(x, 4, 2, 20), dark)
			for x in [20, 36, 52]:
				_fill_rect(image, Rect2i(x, 24, 2, 16), dark)
			for x in [12, 30, 48]:
				_fill_rect(image, Rect2i(x, 40, 2, 18), dark)
		"building_floor":
			for y in [12, 22, 32, 42, 52]:
				_fill_rect(image, Rect2i(5, y, 54, 2), dark)
			for x in [18, 34, 50]:
				_fill_rect(image, Rect2i(x, 8, 1, 48), light)
		"building_yard":
			for pos in [Vector2i(10, 12), Vector2i(24, 18), Vector2i(40, 12), Vector2i(14, 34), Vector2i(34, 30), Vector2i(46, 42)]:
				_fill_rect(image, Rect2i(pos.x, pos.y, 8, 6), dark)
				_fill_rect(image, Rect2i(pos.x + 2, pos.y + 1, 3, 2), light)
		"building_door":
			for y in [10, 22, 34, 46]:
				_fill_rect(image, Rect2i(6, y, 52, 2), dark)
			_fill_rect(image, Rect2i(22, 14, 20, 34), strong)
			_fill_rect(image, Rect2i(24, 16, 16, 30), dark)
			_fill_rect(image, Rect2i(36, 30, 2, 2), light)
		"hill":
			for y in [12, 24, 36, 48]:
				_fill_rect(image, Rect2i(8, y, 48, 2), dark)
				_fill_rect(image, Rect2i(12, y - 4, 12, 2), dark)
				_fill_rect(image, Rect2i(36, y + 4, 12, 2), dark)
		"mountain":
			for rect in [Rect2i(10, 40, 44, 8), Rect2i(18, 30, 28, 8), Rect2i(26, 20, 12, 8)]:
				_fill_rect(image, rect, dark)
			_fill_rect(image, Rect2i(28, 12, 8, 8), light)
		"peak":
			for rect in [Rect2i(8, 42, 48, 8), Rect2i(18, 30, 30, 8), Rect2i(26, 18, 14, 10)]:
				_fill_rect(image, rect, dark)
			_fill_rect(image, Rect2i(24, 10, 18, 10), strong)
		"water":
			for y in [12, 24, 36, 48]:
				_fill_rect(image, Rect2i(6, y, 14, 2), light)
				_fill_rect(image, Rect2i(24, y + 4, 16, 2), light)
				_fill_rect(image, Rect2i(46, y, 12, 2), light)
		"river":
			for y in [10, 20, 30, 40, 50]:
				_fill_rect(image, Rect2i(4, y, 12, 2), strong)
				_fill_rect(image, Rect2i(18, y + 3, 14, 2), strong)
				_fill_rect(image, Rect2i(36, y, 16, 2), strong)
				_fill_rect(image, Rect2i(50, y + 3, 8, 2), strong)
		"bridge":
			for y in [10, 20, 30, 40, 50]:
				_fill_rect(image, Rect2i(10, y, 44, 4), dark)
			_fill_rect(image, Rect2i(8, 8, 4, 48), strong)
			_fill_rect(image, Rect2i(52, 8, 4, 48), strong)
		"swamp":
			for rect in [Rect2i(10, 16, 14, 10), Rect2i(28, 26, 18, 12), Rect2i(18, 42, 12, 8), Rect2i(42, 12, 10, 8)]:
				_fill_rect(image, rect, dark)
			for x in [14, 26, 40, 50]:
				_fill_rect(image, Rect2i(x, 6, 2, 10), light)
		"desert":
			for y in [14, 26, 38, 50]:
				_fill_rect(image, Rect2i(8, y, 18, 2), light)
				_fill_rect(image, Rect2i(24, y + 3, 20, 2), light)
				_fill_rect(image, Rect2i(42, y, 12, 2), light)
		_:
			for pos in [Vector2i(16, 18), Vector2i(34, 34)]:
				_fill_rect(image, Rect2i(pos.x, pos.y, 6, 4), light)

	return ImageTexture.create_from_image(image)


func _get_tile_texture(tile_texture_id: String, bg_color: Color, font_color: Color, border_color: Color, fog_overlay_alpha: float = 0.0) -> Texture2D:
	var loaded: Texture2D = _load_tile_texture_asset(tile_texture_id)
	if loaded != null:
		return _texture_with_fog_variant(tile_texture_id, loaded, fog_overlay_alpha)
	var generated := _generate_tile_texture(tile_texture_id, bg_color, font_color, border_color)
	return _texture_with_fog_variant("%s#generated" % tile_texture_id, generated, fog_overlay_alpha)


## SmokeTest uses this to verify that explored-cell fog still darkens real PNG
## tiles after moving away from flat debug-color rendering.
func debug_get_tile_texture_variant(tile_texture_id: String, fog_overlay_alpha: float = 0.0) -> Texture2D:
	return _get_tile_texture(tile_texture_id, Color.WHITE, Color.WHITE, Color.BLACK, fog_overlay_alpha)


func _texture_with_fog_variant(cache_id: String, source_texture: Texture2D, fog_overlay_alpha: float) -> Texture2D:
	if source_texture == null:
		return null
	var clamped_fog: float = clampf(fog_overlay_alpha, 0.0, 1.0)
	if clamped_fog <= 0.001:
		return source_texture
	var cache_key := "%s|fog=%.3f" % [cache_id, clamped_fog]
	if _derived_tile_textures.has(cache_key):
		return _derived_tile_textures[cache_key]
	var image: Image = source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var fogged: Image = image.duplicate()
	_apply_fog_to_image(fogged, clamped_fog)
	var fogged_texture := ImageTexture.create_from_image(fogged)
	_derived_tile_textures[cache_key] = fogged_texture
	return fogged_texture


func _apply_fog_to_image(image: Image, fog_overlay_alpha: float) -> void:
	var clamped_fog: float = clampf(fog_overlay_alpha, 0.0, 1.0)
	if image == null or image.is_empty() or clamped_fog <= 0.001:
		return
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var luma: float = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
			var grayscale := Color(luma, luma, luma, pixel.a)
			var mixed := pixel.lerp(grayscale, EXPLORED_FOG_DESATURATE)
			var fogged := mixed.lerp(EXPLORED_FOG_COLOR, clamped_fog)
			image.set_pixel(x, y, Color(fogged.r, fogged.g, fogged.b, pixel.a))


func _load_tile_texture_asset(tile_texture_id: String) -> Texture2D:
	if tile_texture_id.is_empty():
		return null
	if _loaded_tile_textures.has(tile_texture_id):
		return _loaded_tile_textures[tile_texture_id]
	var candidates: Array[String] = _tile_texture_asset_candidates(tile_texture_id)
	for candidate in candidates:
		var resource_path := TILE_TEXTURE_BASE_PATH + candidate + ".png"
		if not FileAccess.file_exists(resource_path):
			continue
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(resource_path))
		if image == null or image.is_empty():
			continue
		var texture := ImageTexture.create_from_image(image)
		if texture != null:
			_loaded_tile_textures[tile_texture_id] = texture
			return texture
	_loaded_tile_textures[tile_texture_id] = null
	return null


func _tile_texture_asset_candidates(tile_texture_id: String) -> Array[String]:
	match tile_texture_id:
		"building_floor":
			return ["tavern_floor", "building_floor", "plain"]
		"building_door":
			return ["tavern_door", "building_door", "building_floor"]
		"building_yard":
			return ["building_yard", "plain"]
		"structure_wall":
			return ["structure_wall"]
		"challenge_floor":
			return ["challenge_floor", "building_floor"]
		"ruin_floor":
			return ["ruin_floor", "building_floor"]
		"shrine_floor":
			return ["shrine_floor", "building_floor"]
		_:
			return [tile_texture_id]


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var clipped := Rect2i(
		clampi(rect.position.x, 0, image.get_width()),
		clampi(rect.position.y, 0, image.get_height()),
		maxi(0, mini(rect.size.x, image.get_width() - rect.position.x)),
		maxi(0, mini(rect.size.y, image.get_height() - rect.position.y))
	)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	image.fill_rect(clipped, color)
