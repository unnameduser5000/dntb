class_name ActorDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 1
@export var max_san: int = 0
@export var atk: int = 1
@export var move_range: int = 1
@export var map_char: String = "?"
@export var team: String = "enemy"
@export var ai_type: String = "static"
@export var default_drop_key: String = ""
@export var default_weapon: Resource
@export var default_effect_modifiers: Array[Resource] = []
@export var view_scene: PackedScene
@export var color: Color = Color.WHITE
