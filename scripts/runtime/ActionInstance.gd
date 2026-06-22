class_name ActionInstance
extends RefCounted

var actor
var def
var chosen_dir: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var key_id: String = ""
var chain_index: int = 0
var chain_speed: int = 1
var previous_dir: Vector2i = Vector2i.ZERO
var momentum_dir: Vector2i = Vector2i.ZERO
var momentum_speed: int = 0
