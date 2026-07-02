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
# Optional battle presentation scene override. If empty, the default ActorView is used.
@export var view_scene: PackedScene
# Local offset from the board cell center for this actor's battle presentation.
@export var view_offset: Vector2 = Vector2.ZERO
# Multiplier applied to the default visual scale for this actor's battle presentation.
@export var view_scale: Vector2 = Vector2.ONE
# Base tint for the default glyph fallback and sprite-driven actor views.
@export var color: Color = Color.WHITE
@export var interaction_enabled: bool = false
@export var interaction_title: String = ""
@export var interaction_prompt: String = "交互"
@export var interaction_range: int = 1
@export var interaction_lines: PackedStringArray = []
@export var dialogue_resource_path: String = ""
@export var dialogue_cue: String = ""
