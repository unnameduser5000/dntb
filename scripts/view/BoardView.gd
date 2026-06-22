class_name BoardView
extends Control

const BoardCellScene := preload("res://scenes/map/BoardCell.tscn")

@export var cell_size: int = 52
@export var board_origin: Vector2 = Vector2(380, 120)

@onready var _grid: GridContainer = %AsciiGrid


func _ready() -> void:
	position = board_origin


func grid_to_world(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x * (cell_size + 1), cell.y * (cell_size + 1))


func world_to_grid(pos: Vector2) -> Vector2i:
	var local := pos - board_origin
	return Vector2i(floori(local.x / float(cell_size + 1)), floori(local.y / float(cell_size + 1)))


func render(state) -> void:
	_grid.columns = state.grid.width
	for child in _grid.get_children():
		child.queue_free()

	for y in range(state.grid.height):
		for x in range(state.grid.width):
			var cell := Vector2i(x, y)
			_grid.add_child(_make_cell_label(_describe_cell(cell, state)))


func _describe_cell(cell: Vector2i, state) -> Dictionary:
	var is_danger: bool = state.danger_cells.has(cell)
	var is_preview_move: bool = state.preview_move_cells.has(cell)
	var is_preview_attack: bool = state.preview_attack_cells.has(cell)
	var actor = state.grid.get_actor(cell)
	if actor != null:
		var char := String(actor.map_char())
		if actor.team == "player":
			char = _player_facing_char(actor.facing)

		return {
			"char": char,
			"style": _actor_cell_style(actor, is_danger, is_preview_move, is_preview_attack),
			"tooltip": _actor_tooltip(actor, is_danger, is_preview_move, is_preview_attack),
		}

	if state.items_at.has(cell):
		return {
			"char": String(state.items_at[cell]),
			"style": _preview_cell_style(is_danger, is_preview_move, is_preview_attack, "BoardItemCell"),
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + "按键 %s" % String(state.items_at[cell]),
		}

	if cell == state.exit_cell:
		var is_open: bool = state.get_alive_enemies().is_empty()
		return {
			"char": "X",
			"style": _preview_cell_style(is_danger, is_preview_move, is_preview_attack, "BoardExitOpenCell" if is_open else "BoardExitLockedCell"),
			"tooltip": _preview_prefix(is_preview_move, is_preview_attack) + _danger_prefix(is_danger) + ("出口" if is_open else "锁定出口"),
		}

	if state.grid.is_blocked(cell):
		return {
			"char": "#",
			"style": "BoardWallCell",
			"tooltip": "墙",
		}

	if is_preview_attack:
		return {
			"char": "*",
			"style": "BoardPreviewAttackCell",
			"tooltip": "当前按键槽攻击预览",
		}

	if is_preview_move:
		return {
			"char": "+",
			"style": "BoardPreviewMoveCell",
			"tooltip": "当前按键槽移动预览",
		}

	if is_danger:
		return {
			"char": "!",
			"style": "BoardDangerCell",
			"tooltip": "敌人攻击范围",
		}

	return {
		"char": ".",
		"style": "BoardFloorCell",
		"tooltip": "地面",
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
		tooltip = "当前按键槽攻击预览 / " + tooltip
	elif is_preview_move:
		tooltip = "当前按键槽移动预览 / " + tooltip
	if is_danger:
		tooltip = "敌人攻击范围 / " + tooltip
	return tooltip


func _danger_prefix(is_danger: bool) -> String:
	return "敌人攻击范围 / " if is_danger else ""


func _preview_prefix(is_preview_move: bool, is_preview_attack: bool) -> String:
	if is_preview_attack:
		return "当前按键槽攻击预览 / "
	if is_preview_move:
		return "当前按键槽移动预览 / "
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
