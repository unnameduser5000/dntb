class_name NpcDef
extends "res://scripts/data/ActorDef.gd"

@export var interaction_title: String = ""
@export var interaction_prompt: String = "交谈"
@export var interaction_range: int = 1
@export var interaction_lines: PackedStringArray = []
@export var dialogue_resource_path: String = ""
@export var dialogue_cue: String = ""
