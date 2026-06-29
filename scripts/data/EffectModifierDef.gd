class_name EffectModifierDef
extends Resource

## Effect modifiers participate in two different phases of the pipeline:
##
## 1. modify_packets()
##    Reads and rewrites the packet list before execution.
##    Typical uses:
##    - duplicate packets
##    - scale damage / knockback
##    - tag or cancel packets
##
## 2. react_to_event()
##    Listens to execution events emitted after packets resolve and may
##    generate follow-up packets.
##
## Depth controls:
## - max_generation_depth limits packet-copy chains in modify_packets()
##   via packet.generation_depth
## - max_event_depth limits follow-up event reactions in react_to_event()
##   via event.depth
##
## These are two separate recursion guards for two separate expansion paths.

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
