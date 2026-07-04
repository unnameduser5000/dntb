class_name WeaponDef
extends Resource

## Legacy data resource kept for content reference.
## Current combat flow no longer resolves attacks through an equipped weapon.
## New weapon-flavored content should be exposed as its own token + ActionDef.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var attack_action: Resource
