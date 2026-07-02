class_name WeaponDef
extends Resource

## WeaponDef is now a thin data resource:
## one weapon corresponds to one attack action.
## The key-program layer still emits the generic attack token, but that token
## resolves to the equipped weapon's declared attack_action.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var attack_action: Resource
