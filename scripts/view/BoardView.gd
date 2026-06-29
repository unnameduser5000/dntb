class_name BoardView
extends Control

const BoardCellScene := preload("res://scenes/map/BoardCell.tscn")

@export var cell_size: int = 52
@export var board_origin: Vector2 = Vector2(380, 120)
@export var world_slice_window_size: Vector2i = Vector2i(15, 15)

@onready var _grid: GridContainer = %AsciiGrid
var _render_window_origin: Vector2i = Vector2i.ZERO
var _render_window_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	position = board_origin


func grid_to_world(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(
		(cell.x - _render_window_origin.x) * (cell_size + 1),
		(cell.y - _render_window_origin.y) * (cell_size + 1)
	)


func world_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - board_origin
	return _render_window_origin + Vector2i(
		floori(local.x / float(cell_size + 1)),
		floori(local.y / float(cell_size + 1))
	)


func render(state) -> void:
	var render_window := _compute_render_window(state)
	_render_window_origin = render_window.position
	_render_window_size = render_window.size
	_grid.columns = max(1, _render_window_size.x)
	for child in _grid.get_children():
		child.queue_free()

	for y in range(_render_window_origin.y, _render_window_origin.y + _render_window_size.y):
		for x in range(_render_window_origin.x, _render_window_origin.x + _render_window_size.x):
			var cell := Vector2i(x, y)
			_grid.add_child(_make_cell_label(_describe_cell(cell, state)))


func _compute_render_window(state) -> Rect2i:
	if state == null or state.grid == null:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	if not bool(state.is_world_slice):
		return Rect2i(Vector2i.ZERO, Vector2i(state.grid.width, state.grid.height))

	var grid_width := int(state.grid.width)
	var grid_height := int(state.grid.height)
	var window_size := Vector2i(
		min(world_slice_window_size.x, grid_width),
		min(world_slice_window_size.y, grid_height)
	)
	if window_size.x <= 0 or window_size.y <= 0:
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)

	var player_cell := Vector2i.ZERO
	if state.player != null:
		player_cell = Vector2i(state.player.grid_pos)

	var half_window := Vector2i(int(window_size.x / 2), int(window_size.y / 2))
	var origin := Vector2i(
		clampi(player_cell.x - half_window.x, 0, max(0, grid_width - window_size.x)),
		clampi(player_cell.y - half_window.y, 0, max(0, grid_height - window_size.y))
	)
	return Rect2i(origin, window_size)


func _describe_cell(cell: Vector2i, state) -> Dictionary:
	var has_visibility_layer := _has_visibility_layer(state)
	var reveal_all := bool(state.reveal_all_debug) if has_visibility_layer else true
	var is_visible: bool = reveal_all or (has_visibility_layer and state.visible_cells.has(cell))
	var is_explored: bool = is_visible or (has_visibility_layer and state.explored_cells.has(cell))
	var is_danger: bool = state.danger_cells.has(cell)
	var is_preview_move: bool = state.preview_move_cells.has(cell)
	var is_preview_attack: bool = state.preview_attack_cells.has(cell)

	if has_visibility_layer and not is_explored:
		return {
			"char": " ",
			"style": "BoardUnseenCell",
			"tooltip": "unseen",
		}

	var actor = state.grid.get_actor(cell)
	if actor != null and (is_visible or reveal_all):
		var char := String(actor.map_char())
		if actor.team == "player":
			char = _player_facing_char(actor.facing)

		return {
			"char": char,
			"style": _actor_cell_style(actor, is_danger, is_preview_move, is_preview_attack),
			"tooltip": _actor_tooltip(actor, is_danger, is_preview_move, is_preview_attack),
		}

	if is_visible and state.items_at.has(cell):
		return {
			"char": String(state.items_at[cell]),
			"style": _preview_cell_style(is_danger, is_preview_move, is_preview_attack, "BoardItemCell"),
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + "鎸夐敭 %s" % String(state.items_at[cell]),
		}

	var grid_items: Array = state.grid.get_grid_items(cell)
	if is_visible and not grid_items.is_empty():
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
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + ("鍑哄彛" if is_open else "閿佸畾鍑哄彛"),
		}

	if state.grid.is_blocked(cell):
		return {
			"char": "#",
			"style": "BoardWallCell",
			"tooltip": "澧?",
		}

	if is_preview_attack:
		return {
			"char": "*",
			"style": "BoardPreviewAttackCell",
			"tooltip": "褰撳墠鎸夐敭妲芥敾鍑婚瑙?",
		}

	if is_preview_move:
		return {
			"char": "+",
			"style": "BoardPreviewMoveCell",
			"tooltip": "褰撳墠鎸夐敭妲界Щ鍔ㄩ瑙?",
		}

	if is_danger:
		return {
			"char": "!",
			"style": "BoardDangerCell",
			"tooltip": "鏁屼汉鏀诲嚮鑼冨洿",
		}

	return {
		"char": ".",
		"style": "BoardFloorCell" if (not has_visibility_layer or is_visible) else "BoardExploredCell",
		"tooltip": "鍦伴潰",
	}


func _make_cell_label(cell_data: Dictionary) -> Label:
	var label := BoardCellScene.instantiate() as Label
	label.custom_minimum_size = Vector2(cell_size, cell_size)
	label.text = String(cell_data["char"])
	label.tooltip_text = String(cell_data["tooltip"])
	label.theme_type_variation = StringName(cell_data["style"])
	return label


func _actor_cell_style(actor, is_danger: bool, is_preview_move: bool, is_preview_attack: bool) -> String:
	if is_preview_attack:
		return "BoardPreviewAttackCell"
	if is_preview_move:
		return "BoardPreviewMoveCell"
	if actor.team == "enemy":
		return "BoardEnemyCell"
	return "BoardDangerCell" if is_danger else "BoardPlayerCell"


func _actor_tooltip(actor, is_danger: bool, is_preview_move: bool, is_preview_attack: bool) -> String:
	var tooltip := "%s HP %d/%d" % [actor.def.display_name, actor.hp, actor.max_hp]
	if is_preview_attack:
		tooltip = "褰撳墠鎸夐敭妲芥敾鍑婚瑙?/ " + tooltip
	elif is_preview_move:
		tooltip = "褰撳墠鎸夐敭妲界Щ鍔ㄩ瑙?/ " + tooltip
	if is_danger:
		tooltip = "鏁屼汉鏀诲嚮鑼冨洿 / " + tooltip
	return tooltip


func _danger_prefix(is_danger: bool) -> String:
	return "鏁屼汉鏀诲嚮鑼冨洿 / " if is_danger else ""


func _preview_prefix(is_preview_move: bool, is_preview_attack: bool) -> String:
	if is_preview_attack:
		return "褰撳墠鎸夐敭妲芥敾鍑婚瑙?/ "
	if is_preview_move:
		return "褰撳墠鎸夐敭妲界Щ鍔ㄩ瑙?/ "
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
