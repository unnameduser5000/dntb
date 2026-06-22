class_name AchievementDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: String = "general"
@export var hidden: bool = false
@export var points: int = 0
@export var target: int = 1
@export var trigger_event: String = ""
@export var progress_per_event: int = 1


func is_progress_based() -> bool:
	return target > 1
