class_name WeaponTechniqueDef
extends Resource

## WeaponTechniqueDef is the weapon-side combo description.
## It matches a suffix pattern over ActionTrace symbols and can optionally
## point at a follow-up ActionDef that should execute when the pattern hits.
##
## Current pattern semantics:
## - pattern matching is driven by pattern_type
## - SYMBOL_SEQUENCE matches exact non-overlapping symbol runs in ActionTrace
## - SAME_MOVE_DIRECTION matches repeated successful moves with the same dir
## - longer patterns and higher priority win first within the same type
##
## This lets the project start separating:
## - editable input program
## - executed action trace
## - weapon-side combo recognition

enum TriggerTiming {
	AFTER_ACTION,
	AFTER_CHAIN,
}

enum PatternType {
	SYMBOL_SEQUENCE,
	SAME_MOVE_DIRECTION,
}

@export var id: String = ""
@export var display_name: String = ""
@export var pattern: Array[StringName] = []
@export var pattern_type: PatternType = PatternType.SYMBOL_SEQUENCE
@export var required_move_count: int = 0
@export var priority: int = 0
@export var trigger_timing: TriggerTiming = TriggerTiming.AFTER_CHAIN
@export var consume_pattern: bool = false
## Optional follow-up action resource executed after the combo is recognized.
## This keeps programmable input and weapon payoff separate: the player still
## writes base input tokens, while the weapon converts a recognized trace
## pattern into its own technique action/effect.
@export var action: Resource


func resolved_technique_id() -> String:
	return id


func pattern_size() -> int:
	if pattern_type == PatternType.SAME_MOVE_DIRECTION:
		return max(0, required_move_count)
	return pattern.size()


func resolved_action():
	return action
