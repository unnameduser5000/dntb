class_name BoardView
extends Control

const BoardCellScene := preload("res://scenes/map/BoardCell.tscn")
const TILE_TEXTURE_BASE_PATH := "res://art/tiles/board/"
const EXPLORED_FOG_ALPHA := 0.52
const EXPLORED_FOG_COLOR := Color(0.05, 0.06, 0.08, 1.0)
const EXPLORED_FOG_DESATURATE := 0.18
const POI_MARKER_TAIL_RADIUS_CELLS := 1.0
const POI_MARKER_TIP_RADIUS_CELLS := 1.5
const MAX_TILE_TEXTURE_SOURCE_SIZE := 128
const POI_MARKER_SYMBOLS := {
	"boss": "B",
	"ruin": "R",
}
const POI_MARKER_COLORS := {
	"boss": Color(0.92, 0.78, 0.42, 0.98),
	"ruin": Color(0.72, 0.9, 0.78, 0.98),
}

@export var cell_size: int = 52
@export var board_origin: Vector2 = Vector2(380, 120)
@export var world_slice_window_size: Vector2i = Vector2i(29, 29)
@export var world_slice_min_cell_size: int = 14
@export var world_slice_max_cell_size: int = 20
@export var world_slice_min_zoom_cell_size: int = 7
@export var world_slice_max_zoom_cell_size: int = 120
@export var world_slice_left_margin: int = 24
@export var world_slice_top_margin: int = 84
@export var world_slice_bottom_margin: int = 24
@export var world_slice_reserved_right_width: int = 404
@export var world_slice_right_gap: int = 24
@export var enable_pan_zoom: bool = true
@export var min_zoom: float = 0.25
@export var max_zoom: float = 5.0
@export var zoom_step_factor: float = 1.15
@export var world_slice_camera_follow: bool = true
@export var world_slice_render_margin_cells: int = 2

@onready var _grid: GridContainer = %AsciiGrid
var _render_window_origin: Vector2i = Vector2i.ZERO
var _render_window_size: Vector2i = Vector2i.ZERO
var _cell_pool: Array[Label] = []
var _pool_window_size: Vector2i = Vector2i.ZERO
var _pool_cell_size: int = -1
var _camera_offset: Vector2 = Vector2.ZERO
var _camera_zoom: float = 1.0
var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO
var _camera_node: Camera2D = null
var _stylebox_cache: Dictionary = {}
var _texture_stylebox_cache: Dictionary = {}
var _loaded_tile_textures: Dictionary = {}
var _derived_tile_textures: Dictionary = {}
var _cropped_texture_cache: Dictionary = {}
var _last_state = null


func _ready() -> void:
	position = board_origin
	mouse_filter = Control.MOUSE_FILTER_PASS
	_camera_node = get_parent().get_node_or_null("Camera2D")
	_rebuild_cell_pool(_compute_pool_size())
	var settings_service = get_node_or_null("/root/SettingsService")
	if settings_service != null:
		settings_service.world_slice_zoom_changed.connect(_on_world_slice_zoom_changed)
	queue_redraw()


func center_world_slice_camera_on_player(state) -> void:
	if _camera_node == null or state == null or state.player == null:
		return
	if not world_slice_camera_follow:
		return
	var cell_size: int = compute_world_slice_zoomed_cell_size()
	_camera_node.position = Vector2(state.player.grid_pos) * float(cell_size + 1) + Vector2(cell_size * 0.5, cell_size * 0.5)


func _on_world_slice_zoom_changed(_index: int) -> void:
	if _last_state != null and bool(_last_state.is_world_slice):
		center_world_slice_camera_on_player(_last_state)
		render(_last_state)


func _gui_input(event: InputEvent) -> void:
	if not _is_world_slice_mode() or not enable_pan_zoom or world_slice_camera_follow:
		return
	if get_viewport().gui_is_dragging():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(get_global_mouse_position(), zoom_step_factor)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(get_global_mouse_position(), 1.0 / zoom_step_factor)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_mouse = event.position
				_drag_start_offset = _camera_offset
			else:
				_is_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		_camera_offset = _drag_start_offset + (event.position - _drag_start_mouse) * _camera_zoom
		_clamp_camera_offset()
		_apply_camera_transform()
		accept_event()


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


func compute_world_slice_cell_size() -> int:
	var viewport_rect: Rect2 = get_viewport_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return cell_size
	var fit_cell_width: int = int(floor((viewport_rect.size.x - float(world_slice_window_size.x - 1)) / float(world_slice_window_size.x)))
	var fit_cell_height: int = int(floor((viewport_rect.size.y - float(world_slice_window_size.y - 1)) / float(world_slice_window_size.y)))
	return clampi(mini(fit_cell_width, fit_cell_height), world_slice_min_cell_size, world_slice_max_cell_size)


func compute_world_slice_zoomed_cell_size() -> int:
	var base_size: int = compute_world_slice_cell_size()
	var zoom_factor: float = _get_world_slice_zoom_factor()
	var zoomed_size: int = int(round(float(base_size) * zoom_factor))
	return clampi(zoomed_size, world_slice_min_zoom_cell_size, world_slice_max_zoom_cell_size)


func _get_world_slice_zoom_factor() -> float:
	var settings_service = get_node_or_null("/root/SettingsService")
	if settings_service == null:
		return 1.0
	var index: int = settings_service.world_slice_zoom_index
	if index < 0 or index >= settings_service.WORLD_SLICE_ZOOM_OPTIONS.size():
		return 1.0
	return float(settings_service.WORLD_SLICE_ZOOM_OPTIONS[index])


func reset_camera() -> void:
	_camera_offset = Vector2.ZERO
	_camera_zoom = 1.0
	if _camera_node != null:
		_camera_node.position = Vector2.ZERO
		_camera_node.zoom = Vector2.ONE
	_apply_camera_transform()


func set_camera_offset(offset: Vector2) -> void:
	_camera_offset = offset
	_clamp_camera_offset()
	_apply_camera_transform()


func set_camera_zoom(zoom: float) -> void:
	_camera_zoom = clampf(zoom, min_zoom, max_zoom)
	_clamp_camera_offset()
	_apply_camera_transform()


func get_camera_offset() -> Vector2:
	return _camera_offset


func get_camera_zoom() -> float:
	return _camera_zoom


func get_render_window_size() -> Vector2i:
	return _render_window_size


func get_render_window_origin() -> Vector2i:
	return _render_window_origin


func _is_world_slice_mode() -> bool:
	# This is updated by render(); default false until first render.
	return _render_window_size != Vector2i.ZERO and _render_window_size.x > 0 and _render_window_size.y > 0


func _apply_camera_transform() -> void:
	position = board_origin + _camera_offset
	scale = Vector2(_camera_zoom, _camera_zoom)
	queue_redraw()


func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var new_zoom: float = clampf(_camera_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(new_zoom, _camera_zoom):
		return

	var local_before: Vector2 = (screen_point - position) / _camera_zoom
	_camera_zoom = new_zoom
	var local_after: Vector2 = (screen_point - position) / _camera_zoom
	_camera_offset += (local_after - local_before) * _camera_zoom
	_clamp_camera_offset()
	_apply_camera_transform()


func _clamp_camera_offset() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var board_pixels: Vector2 = _window_pixel_size(_render_window_size) * _camera_zoom
	var min_offset := viewport_size - board_pixels
	var max_offset := Vector2.ZERO
	_camera_offset.x = clampf(_camera_offset.x, min(min_offset.x, 0.0), max_offset.x)
	_camera_offset.y = clampf(_camera_offset.y, min(min_offset.y, 0.0), max_offset.y)


func render(state) -> void:
	_last_state = state
	var render_window: Rect2i
	if state != null and bool(state.is_world_slice):
		# Camera-follow mode chooses cell_size from the viewport first, then
		# derives the render window, then aligns BoardView.position so the
		# rendered window maps to the right screen pixels.
		cell_size = compute_world_slice_zoomed_cell_size()
		render_window = _compute_render_window(state)
		_render_window_origin = render_window.position
		_render_window_size = render_window.size
		_ensure_cell_pool(_render_window_size)
		_apply_world_slice_layout()
	else:
		if state != null and state.grid != null:
			render_window = Rect2i(Vector2i.ZERO, Vector2i(state.grid.width, state.grid.height))
		else:
			render_window = Rect2i(Vector2i.ZERO, Vector2i.ZERO)
		_render_window_origin = render_window.position
		_render_window_size = render_window.size
		_ensure_cell_pool(_render_window_size)
	var started_at: int = Time.get_ticks_msec()
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
	queue_redraw()


func _draw() -> void:
	_draw_world_slice_poi_markers()
	_draw_focused_nav_marker()


func _draw_world_slice_poi_markers() -> void:
	var state = _last_state
	if state == null or not bool(state.is_world_slice) or state.player == null:
		return
	if _render_window_size == Vector2i.ZERO:
		return

	var player_center: Vector2 = _grid_to_local_center(state.player.grid_pos)
	var marker_tail_radius: float = maxf(12.0, float(cell_size) * POI_MARKER_TAIL_RADIUS_CELLS)
	var marker_tip_radius: float = maxf(18.0, float(cell_size) * POI_MARKER_TIP_RADIUS_CELLS)
	var marker_spacing: float = maxf(16.0, float(cell_size) * 0.55)
	var markers: Array[Dictionary] = []
	_append_poi_marker(markers, state, Vector2i(state.tracked_boss_poi_cell), "boss", player_center, marker_tail_radius, marker_tip_radius)
	_append_poi_marker(markers, state, Vector2i(state.tracked_nearest_ruin_cell), "ruin", player_center, marker_tail_radius, marker_tip_radius)
	if markers.is_empty():
		return

	var grouped: Dictionary = {}
	for marker in markers:
		var dir_key: String = _marker_direction_key(Vector2(marker.get("dir", Vector2.ZERO)))
		if not grouped.has(dir_key):
			grouped[dir_key] = []
		grouped[dir_key].append(marker)

	for group_markers in grouped.values():
		var marker_group: Array = Array(group_markers)
		for index in range(marker_group.size()):
			var marker: Dictionary = marker_group[index]
			var marker_dir: Vector2 = Vector2(marker.get("dir", Vector2.ZERO))
			var tangent := Vector2(-marker_dir.y, marker_dir.x)
			var centered_index: float = float(index) - (float(marker_group.size() - 1) * 0.5)
			var lateral_offset: Vector2 = tangent * centered_index * marker_spacing
			_draw_single_poi_marker(
				Vector2(marker.get("tail", player_center)),
				Vector2(marker.get("tip", player_center)),
				marker_dir,
				String(marker.get("symbol", "?")),
				Color(marker.get("color", Color.WHITE)),
				lateral_offset
			)


func _draw_focused_nav_marker() -> void:
	var state = _last_state
	if state == null or not bool(state.is_world_slice) or state.player == null:
		return
	var target_cell: Vector2i = Vector2i(state.focused_nav_target_cell)
	if target_cell == Vector2i(-1, -1):
		return
	var focus_color := Color(1.0, 0.92, 0.42, 0.98)
	var player_center: Vector2 = _grid_to_local_center(state.player.grid_pos)
	var delta: Vector2 = Vector2(target_cell - state.player.grid_pos)
	if delta.length_squared() <= 0.001:
		return
	var dir: Vector2 = delta.normalized()
	var marker_tail_radius: float = maxf(12.0, float(cell_size) * POI_MARKER_TAIL_RADIUS_CELLS)
	var marker_tip_radius: float = maxf(18.0, float(cell_size) * POI_MARKER_TIP_RADIUS_CELLS)
	_draw_single_poi_marker(
		player_center + dir * marker_tail_radius,
		player_center + dir * marker_tip_radius,
		dir,
		"!",
		focus_color
	)
	if is_cell_in_render_window(target_cell):
		var center := _grid_to_local_center(target_cell)
		draw_arc(center, maxf(12.0, float(cell_size) * 0.52), 0.0, TAU, 24, focus_color, 3.0, true)
		draw_circle(center, maxf(3.0, float(cell_size) * 0.08), focus_color)
		return
	if _render_window_size == Vector2i.ZERO:
		return


func _append_poi_marker(markers: Array[Dictionary], state, target_cell: Vector2i, marker_kind: String, player_center: Vector2, marker_tail_radius: float, marker_tip_radius: float) -> void:
	if target_cell == Vector2i(-1, -1):
		return
	if target_cell == state.player.grid_pos:
		return
	if _cell_in_set(state, "visible_cell_set", "visible_cells", target_cell):
		return
	var delta: Vector2 = Vector2(target_cell - state.player.grid_pos)
	if delta.length_squared() <= 0.001:
		return
	var dir: Vector2 = delta.normalized()
	markers.append({
		"dir": dir,
		"tail": player_center + dir * marker_tail_radius,
		"tip": player_center + dir * marker_tip_radius,
		"symbol": String(POI_MARKER_SYMBOLS.get(marker_kind, "?")),
		"color": Color(POI_MARKER_COLORS.get(marker_kind, Color.WHITE)),
	})


func _draw_single_poi_marker(tail_pos: Vector2, tip_pos: Vector2, dir: Vector2, symbol: String, color: Color, lateral_offset: Vector2 = Vector2.ZERO) -> void:
	var arrow_half_width: float = maxf(5.0, float(cell_size) * 0.18)
	var tail: Vector2 = tail_pos + lateral_offset
	var tip: Vector2 = tip_pos + lateral_offset
	var tangent := Vector2(-dir.y, dir.x)
	var left: Vector2 = tail + tangent * arrow_half_width
	var right: Vector2 = tail - tangent * arrow_half_width
	var shadow := Color(0.03, 0.04, 0.05, 0.82)
	var fill_points := PackedVector2Array([tip, left, right])
	draw_colored_polygon(fill_points, shadow)
	draw_line(left, tip, color, 2.0, true)
	draw_line(right, tip, color, 2.0, true)
	draw_line(tail, tip - dir * 2.0, color.darkened(0.2), 2.0, true)
	var marker_pos: Vector2 = tail.lerp(tip, 0.45)
	var label_pos: Vector2 = marker_pos - Vector2(float(cell_size) * 0.2, float(cell_size) * 0.3)
	var font := get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	if font != null:
		draw_string_outline(font, label_pos + Vector2(0, font_size * 0.35), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, shadow)
		draw_string(font, label_pos + Vector2(0, font_size * 0.35), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _grid_to_local_center(cell: Vector2i) -> Vector2:
	var cell_world: Vector2 = grid_to_world(cell)
	return (cell_world - global_position) / scale + Vector2(cell_size * 0.5, cell_size * 0.5)


func _marker_direction_key(dir: Vector2) -> String:
	if dir.length_squared() <= 0.001:
		return "0,0"
	return "%d,%d" % [roundi(dir.x * 2.0), roundi(dir.y * 2.0)]


func _compute_render_window(state) -> Rect2i:
	if state == null or state.grid == null:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	if not bool(state.is_world_slice):
		return Rect2i(Vector2i.ZERO, Vector2i(state.grid.width, state.grid.height))

	var grid_width: int = int(state.grid.width)
	var grid_height: int = int(state.grid.height)

	if not world_slice_camera_follow:
		var window_size: Vector2i = Vector2i(
			min(world_slice_window_size.x, grid_width),
			min(world_slice_window_size.y, grid_height)
		)
		if window_size.x <= 0 or window_size.y <= 0:
			return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

		var player_cell: Vector2i = Vector2i.ZERO
		if state.player != null:
			player_cell = Vector2i(state.player.grid_pos)

		var half_window: Vector2i = Vector2i(int(window_size.x / 2), int(window_size.y / 2))
		var origin: Vector2i = Vector2i(
			clampi(player_cell.x - half_window.x, 0, max(0, grid_width - window_size.x)),
			clampi(player_cell.y - half_window.y, 0, max(0, grid_height - window_size.y))
		)
		return Rect2i(origin, window_size)

	# Camera-follow mode: render enough cells to cover the viewport plus margin.
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	var camera_pos: Vector2 = Vector2.ZERO
	if _camera_node != null:
		camera_pos = _camera_node.position

	var cell_stride: float = float(cell_size + 1) * _camera_zoom
	if cell_stride <= 0.0:
		cell_stride = float(cell_size + 1)

	var half_viewport: Vector2 = viewport_size * 0.5
	var origin_cell := Vector2i(
		floori((camera_pos.x - half_viewport.x) / cell_stride) - world_slice_render_margin_cells,
		floori((camera_pos.y - half_viewport.y) / cell_stride) - world_slice_render_margin_cells
	)
	var end_cell := Vector2i(
		ceili((camera_pos.x + half_viewport.x) / cell_stride) + world_slice_render_margin_cells,
		ceili((camera_pos.y + half_viewport.y) / cell_stride) + world_slice_render_margin_cells
	)
	var window_size: Vector2i = Vector2i(
		clampi(end_cell.x - origin_cell.x, 1, grid_width),
		clampi(end_cell.y - origin_cell.y, 1, grid_height)
	)
	const MAX_RENDER_WINDOW_CELLS_PER_AXIS := 40
	if window_size.x > MAX_RENDER_WINDOW_CELLS_PER_AXIS:
		var excess_x: int = window_size.x - MAX_RENDER_WINDOW_CELLS_PER_AXIS
		origin_cell.x += excess_x / 2
		window_size.x = MAX_RENDER_WINDOW_CELLS_PER_AXIS
	if window_size.y > MAX_RENDER_WINDOW_CELLS_PER_AXIS:
		var excess_y: int = window_size.y - MAX_RENDER_WINDOW_CELLS_PER_AXIS
		origin_cell.y += excess_y / 2
		window_size.y = MAX_RENDER_WINDOW_CELLS_PER_AXIS
	origin_cell.x = clampi(origin_cell.x, 0, max(0, grid_width - window_size.x))
	origin_cell.y = clampi(origin_cell.y, 0, max(0, grid_height - window_size.y))
	return Rect2i(origin_cell, window_size)


func _describe_cell(cell: Vector2i, state) -> Dictionary:
	var has_visibility_layer: bool = _has_visibility_layer(state)
	var reveal_all: bool = bool(state.reveal_all_debug) if has_visibility_layer else true
	var is_visible: bool = reveal_all or _cell_in_set(state, "visible_cell_set", "visible_cells", cell)
	var is_explored: bool = is_visible or _cell_in_set(state, "explored_cell_set", "explored_cells", cell)
	var is_danger: bool = state.danger_cells.has(cell)
	var is_persistent_danger: bool = state.get("persistent_danger_cells") != null and state.persistent_danger_cells.has(cell)
	var is_preview_move: bool = state.preview_move_cells.has(cell)
	var is_preview_attack: bool = state.preview_attack_cells.has(cell)

	if has_visibility_layer and not is_explored:
		return {
			"char": " ",
			"style": "BoardUnseenCell",
			"tooltip": "Unseen",
		}

	var actor = state.grid.get_actor(cell)
	var actor_tooltip := ""
	if actor != null and (is_visible or reveal_all):
		actor_tooltip = _actor_tooltip(actor, is_danger, is_preview_move, is_preview_attack)

	if (is_visible or reveal_all) and state.items_at.has(cell):
		var item_id := String(state.items_at[cell])
		var item_char := _item_display_char(item_id)
		var item_tooltip := _item_tooltip(state, item_id)
		return {
			"char": item_char,
			"style": _preview_cell_style(is_danger, is_preview_move, is_preview_attack, "BoardItemCell"),
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + item_tooltip,
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

	if is_danger or is_persistent_danger:
		var danger_cell := _describe_terrain_cell(cell, state, is_visible)
		danger_cell["char"] = "!"
		danger_cell["font_color"] = Color(1.0, 0.18, 0.22, 1.0) if is_danger else Color(0.92, 0.28, 0.94, 1.0)
		danger_cell["border_color"] = Color(1.0, 0.14, 0.18, 0.98) if is_danger else Color(0.88, 0.26, 0.96, 0.98)
		danger_cell["tooltip"] = (actor_tooltip + "\n" if not actor_tooltip.is_empty() else "") + ("Threatened by enemy action" if is_danger else "Persistent corruption zone")
		return danger_cell

	var terrain_cell := _describe_terrain_cell(cell, state, is_visible)
	if not actor_tooltip.is_empty():
		terrain_cell["tooltip"] = "%s\n%s" % [actor_tooltip, String(terrain_cell.get("tooltip", ""))]
	return terrain_cell


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
	if state != null and bool(state.is_world_slice) and String(state.map_node_kind) == "boss" and walkable:
		tile_texture_id = "boss_dungeon_floor"
		terrain_name = "boss dungeon floor"

	return {
		"char": "",
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

	var style: StringName = StringName(cell_data["style"])
	var char_text: String = String(cell_data["char"])
	var tooltip: String = String(cell_data["tooltip"])
	var bg_variant = cell_data.get("bg_color", null)
	var font_variant = cell_data.get("font_color", null)
	var border_variant = cell_data.get("border_color", null)
	var tile_texture_id: String = String(cell_data.get("tile_texture_id", ""))
	var fog_overlay_alpha: float = clampf(float(cell_data.get("fog_overlay_alpha", 0.0)), 0.0, 1.0)

	var cell_key: String = "%s|%s|%s|%s|%s|%s|%s|%.3f" % [
		style,
		char_text,
		tooltip,
		bg_variant.to_html() if bg_variant is Color else "",
		font_variant.to_html() if font_variant is Color else "",
		border_variant.to_html() if border_variant is Color else "",
		tile_texture_id,
		fog_overlay_alpha,
	]

	var last_key: String = ""
	if label.has_meta("_last_cell_key"):
		last_key = String(label.get_meta("_last_cell_key"))

	var last_cell_size: int = int(label.get_meta("_last_cell_size", -1))
	if cell_key == last_key and last_cell_size == cell_size:
		return

	label.set_meta("_last_cell_key", cell_key)
	label.set_meta("_last_cell_size", cell_size)

	label.custom_minimum_size = Vector2(cell_size, cell_size)
	label.text = char_text
	label.tooltip_text = tooltip
	label.theme_type_variation = style
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


func _item_display_char(item_id: String) -> String:
	return item_id


func _item_tooltip(state, item_id: String) -> String:
	return "Key token: %s" % item_id


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
	if window_size.x <= 0 or window_size.y <= 0:
		_rebuild_cell_pool(window_size)
		return
	# Keep the existing pool if it is already large enough for the new window.
	# Rebuilding hundreds of Label nodes every frame causes noticeable stutter,
	# especially when the render window changes by only a few cells.
	if _cell_pool.size() >= window_size.x * window_size.y and _pool_cell_size == cell_size:
		_pool_window_size = window_size
		_grid.columns = max(1, window_size.x)
		return
	_rebuild_cell_pool(window_size)


func _rebuild_cell_pool(window_size: Vector2i) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cell_pool.clear()
	_pool_window_size = window_size
	_pool_cell_size = cell_size
	if window_size.x <= 0 or window_size.y <= 0:
		return
	_grid.columns = max(1, window_size.x)
	var total_cells: int = window_size.x * window_size.y
	_cell_pool.resize(total_cells)
	for index in range(total_cells):
		var label: Label = BoardCellScene.instantiate() as Label
		label.custom_minimum_size = Vector2(cell_size, cell_size)
		label.visible = true
		_grid.add_child(label)
		_cell_pool[index] = label


func _compute_pool_size() -> Vector2i:
	return Vector2i(max(1, world_slice_window_size.x), max(1, world_slice_window_size.y))


func _apply_world_slice_layout() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return

	if world_slice_camera_follow:
		# Camera-follow mode uses Camera2D.position as a data marker for the
		# world-pixel coordinate that should appear at the viewport center. Because
		# BoardView is a Control, the Camera2D itself does not scroll it; we compute
		# BoardView.position so the already-clamped render-window origin cell lands
		# at the correct screen pixel.
		var cell_stride: float = float(cell_size + 1)
		var viewport_center: Vector2 = viewport_rect.size * 0.5
		var camera_pos: Vector2 = Vector2.ZERO
		if _camera_node != null:
			camera_pos = _camera_node.position

		board_origin = viewport_center - camera_pos + Vector2(_render_window_origin) * cell_stride
		_camera_offset = Vector2.ZERO
		_camera_zoom = 1.0
		if _camera_node != null:
			_camera_node.enabled = false
		_apply_camera_transform()
		return

	var available_width: float = maxf(120.0, viewport_rect.size.x - float(world_slice_left_margin + world_slice_right_gap))
	var available_height: float = maxf(120.0, viewport_rect.size.y - float(world_slice_top_margin + world_slice_bottom_margin))
	var width_steps: int = max(1, world_slice_window_size.x)
	var height_steps: int = max(1, world_slice_window_size.y)
	var fit_cell_width: int = int(floor((available_width - float(width_steps - 1)) / float(width_steps)))
	var fit_cell_height: int = int(floor((available_height - float(height_steps - 1)) / float(height_steps)))
	cell_size = clampi(mini(fit_cell_width, fit_cell_height), world_slice_min_cell_size, world_slice_max_cell_size)

	var board_pixels: Vector2 = _window_pixel_size(world_slice_window_size)
	var pane_origin := Vector2(float(world_slice_left_margin), float(world_slice_top_margin))
	board_origin = Vector2(
		pane_origin.x + floor(maxf(0.0, (available_width - board_pixels.x) * 0.5)),
		pane_origin.y + floor(maxf(0.0, (available_height - board_pixels.y) * 0.5))
	)
	if _camera_node != null:
		_camera_node.enabled = false
	_apply_camera_transform()


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
	if map_cell.tags.has("boss_locked_door"):
		return "poi_locked_door"
	var poi_type: String = _poi_type_for_map_cell(map_cell)
	if map_cell.tags.has("building_door"):
		match poi_type:
			"challenge_entrance":
				return "poi_locked_door"
			"tavern":
				return "poi_camp"
			_:
				return "building_door"
	if map_cell.tags.has("building_floor"):
		match poi_type:
			"tavern":
				return "poi_camp"
			"challenge_entrance":
				return "challenge_floor"
			"ruin":
				return "poi_ruins"
			"shrine":
				return "poi_watchtower"
		return "building_floor"
	if map_cell.tags.has("building_open_ground"):
		if poi_type == "tavern":
			return "poi_camp"
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
		var resource_path := candidate if candidate.begins_with("res://") else TILE_TEXTURE_BASE_PATH + candidate + ".png"
		if not FileAccess.file_exists(resource_path):
			continue
		var texture: Texture2D = ResourceLoader.load(resource_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
		if texture == null:
			continue
		texture = _scaled_texture_if_needed(texture)
		if resource_path.contains("/art/imported/world/poi/"):
			var cropped: Texture2D = _crop_texture_to_visible_bounds_cached(texture, resource_path)
			if cropped != null:
				_loaded_tile_textures[tile_texture_id] = cropped
				return cropped
		_loaded_tile_textures[tile_texture_id] = texture
		return texture
	_loaded_tile_textures[tile_texture_id] = null
	return null


func _scaled_texture_if_needed(source_texture: Texture2D) -> Texture2D:
	if source_texture == null:
		return null
	var image: Image = source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var max_dimension: int = maxi(image.get_width(), image.get_height())
	if max_dimension <= MAX_TILE_TEXTURE_SOURCE_SIZE:
		return source_texture
	var scale_ratio: float = float(MAX_TILE_TEXTURE_SOURCE_SIZE) / float(max_dimension)
	var scaled_size := Vector2i(
		maxi(1, int(round(float(image.get_width()) * scale_ratio))),
		maxi(1, int(round(float(image.get_height()) * scale_ratio)))
	)
	var scaled := image.duplicate()
	if scaled.get_format() != Image.FORMAT_RGBA8:
		scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(scaled)


func _crop_texture_to_visible_bounds_cached(source_texture: Texture2D, cache_key: String) -> Texture2D:
	if source_texture == null:
		return null
	if _cropped_texture_cache.has(cache_key):
		return _cropped_texture_cache[cache_key]
	var image: Image = source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture
	var cropped := _crop_image_to_visible_bounds(image.duplicate())
	if cropped == null or cropped.is_empty():
		return source_texture
	var cropped_texture := ImageTexture.create_from_image(cropped)
	_cropped_texture_cache[cache_key] = cropped_texture
	return cropped_texture


func _tile_texture_asset_candidates(tile_texture_id: String) -> Array[String]:
	match tile_texture_id:
		"plain":
			return ["res://art/imported/world/biomes/biome_grassland.png", "plain"]
		"forest":
			return ["res://art/imported/world/foliage/tall_grass_generated.png", "res://art/imported/world/biomes/biome_grassland.png", "forest", "plain"]
		"tree":
			return ["res://art/imported/world/poi/poi_watchtower.png", "tree", "forest"]
		"rock":
			return ["res://art/imported/world/poi/poi_ruins.png", "rock", "structure_wall"]
		"statue":
			return ["res://art/imported/world/poi/poi_ruins.png", "statue", "rock"]
		"hill":
			return ["res://art/imported/world/biomes/biome_distant_mountains.png", "hill", "mountain"]
		"desert":
			return ["res://art/imported/world/biomes/biome_quicksand.png", "res://art/imported/world/biomes/biome_desert.png", "desert"]
		"swamp":
			return ["res://art/imported/world/biomes/biome_wetland.png", "swamp"]
		"mountain":
			return ["res://art/imported/world/biomes/biome_distant_mountains.png", "mountain"]
		"peak":
			return ["res://art/imported/world/biomes/biome_snowfield.png", "peak"]
		"river":
			return ["res://art/imported/world/biomes/biome_wetland.png", "river", "water"]
		"bridge":
			return ["res://art/imported/world/biomes/biome_grassland.png", "bridge", "plain"]
		"building_floor":
			return ["tavern_floor", "building_floor", "plain"]
		"building_door":
			return ["tavern_door", "building_door", "building_floor"]
		"building_yard":
			return ["res://art/imported/world/biomes/biome_grassland.png", "building_yard", "plain"]
		"poi_locked_door":
			return ["res://art/imported/world/poi/poi_locked_door.png", "building_door"]
		"poi_ruins":
			return ["res://art/imported/world/poi/poi_ruins.png", "ruin_floor", "building_floor"]
		"poi_watchtower":
			return ["res://art/imported/world/poi/poi_watchtower.png", "shrine_floor", "building_floor"]
		"poi_camp":
			return ["res://art/imported/world/poi/poi_camp.png", "building_floor", "building_yard"]
		"structure_wall":
			return ["res://art/imported/world/poi/poi_ruins.png", "structure_wall"]
		"challenge_floor":
			return ["res://art/imported/world/biomes/biome_desert.png", "challenge_floor", "building_floor"]
		"ruin_floor":
			return ["ruin_floor", "building_floor"]
		"shrine_floor":
			return ["shrine_floor", "building_floor"]
		"boss_dungeon_floor":
			return ["res://art/imported/world/dungeon/dungeon_concept.jpg", "challenge_floor"]
		_:
			return [tile_texture_id]
func _crop_image_to_visible_bounds(source_image: Image) -> Image:
	if source_image == null or source_image.is_empty():
		return source_image
	var min_x := source_image.get_width()
	var min_y := source_image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			if source_image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return source_image
	var cropped := Image.create(max_x - min_x + 1, max_y - min_y + 1, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(source_image, Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1), Vector2i.ZERO)
	return cropped


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
