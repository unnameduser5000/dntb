class_name EffectModifierDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var priority: int = 0
@export var max_generation_depth: int = 3
@export var max_event_depth: int = 3


func modify_packets(packets: Array, _context: Dictionary) -> Array:
	return packets


func react_to_event(_event, _context: Dictionary) -> Array:
	return []
