class_name ActionDef
extends Resource

enum ActionKind {
	MOVE,
	ATTACK,
	TURN,
	WAIT,
	GUARD,
	INTERACT,
}

@export var id: String = ""
@export var display_name: String = ""
@export var short_name: String = ""
@export var kind: ActionKind = ActionKind.MOVE
@export var icon: Texture2D
@export var range: int = 1
@export var power: int = 1
@export var direction_mode: String = "chosen"
@export var combo_symbol: StringName = &""
