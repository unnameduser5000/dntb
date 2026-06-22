class_name RoomDef
extends Resource

@export var id: String = ""
@export var width: int = 12
@export var height: int = 8
@export var player_spawn: Vector2i = Vector2i.ONE
@export var exit_cell: Vector2i = Vector2i(10, 1)
@export var wall_rects: Array[Rect2i] = []
@export var key_spawns: Dictionary = {}
@export var enemy_spawns: Array[Dictionary] = []
