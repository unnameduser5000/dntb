class_name EnemyDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 1
@export var atk: int = 1
@export var move_range: int = 1
@export var map_char: String = "M"
@export var team: String = "enemy"
@export var ai_type: String = "static"
@export var default_drop_key: String = ""
@export var view_scene: PackedScene
@export var color: Color = Color.WHITE
@export var spawn_floor: int = 1
@export var weight: int = 1
