class_name ActorInteractionService
extends RefCounted


func find_interactable_actor(state):
	if state == null or state.player == null:
		return null
	var facing: Vector2i = state.player.facing
	if facing == Vector2i.ZERO:
		return null
	var target_cell: Vector2i = state.player.grid_pos + facing
	var actor = state.grid.get_actor(target_cell) if state.grid != null else null
	if _is_interactable_actor(actor, state.player):
		return actor
	return null


func interact(state, progress_by_actor_id: Dictionary) -> Dictionary:
	var actor = find_interactable_actor(state)
	if actor == null:
		return {"handled": false}

	var actor_def = actor.def
	var actor_type_id: String = String(actor_def.id if actor_def != null else actor.grid_item_id)
	var actor_id: String = actor_type_id
	if actor.tags.has("poi_npc") and not String(actor.grid_item_id).is_empty():
		actor_id = String(actor.grid_item_id)
	var lines: PackedStringArray = PackedStringArray()
	if actor_def != null and _has_property(actor_def, "interaction_lines"):
		lines = PackedStringArray(actor_def.get("interaction_lines"))
	var line_index: int = int(progress_by_actor_id.get(actor_id, 0))
	var line: String = ""
	if not lines.is_empty():
		line = String(lines[line_index % lines.size()])
	progress_by_actor_id[actor_id] = line_index + 1

	var title: String = String(actor.display_name)
	if actor_def != null and _has_property(actor_def, "interaction_title"):
		var configured_title := String(actor_def.get("interaction_title"))
		if not configured_title.is_empty():
			title = configured_title

	var prompt: String = "交互"
	if actor_def != null and _has_property(actor_def, "interaction_prompt"):
		var configured_prompt := String(actor_def.get("interaction_prompt"))
		if not configured_prompt.is_empty():
			prompt = configured_prompt

	var dialogue_resource_path: String = ""
	var dialogue_cue: String = ""
	if actor_def != null and _has_property(actor_def, "dialogue_resource_path"):
		dialogue_resource_path = String(actor_def.get("dialogue_resource_path"))
	if actor_def != null and _has_property(actor_def, "dialogue_cue"):
		dialogue_cue = String(actor_def.get("dialogue_cue"))

	return {
		"handled": true,
		"actor": actor,
		"actor_id": actor_id,
		"actor_type_id": actor_type_id,
		"actor_progress_id": actor_id,
		"actor_name": String(actor.display_name),
		"title": title,
		"prompt": prompt,
		"line": line,
		"dialogue_resource_path": dialogue_resource_path,
		"dialogue_cue": dialogue_cue,
	}


func get_interaction_prompt(state) -> String:
	var actor = find_interactable_actor(state)
	if actor == null:
		return ""
	var actor_def = actor.def
	var prompt := "交互"
	if actor_def != null and _has_property(actor_def, "interaction_prompt"):
		var configured_prompt := String(actor_def.get("interaction_prompt"))
		if not configured_prompt.is_empty():
			prompt = configured_prompt
	return "确认键%s：%s" % [prompt, String(actor.display_name)]


func _is_interactable_actor(actor, player) -> bool:
	if actor == null or player == null or actor == player:
		return false
	if actor.has_method("is_dead") and actor.is_dead():
		return false
	if actor.def == null or not bool(actor.def.get("interaction_enabled")):
		return false
	var range_limit: int = 1
	if actor.def != null and _has_property(actor.def, "interaction_range"):
		range_limit = maxi(1, int(actor.def.get("interaction_range")))
	var distance: int = _manhattan(actor.grid_pos, player.grid_pos)
	if distance > range_limit:
		return false
	var facing: Vector2i = player.facing
	if facing == Vector2i.ZERO:
		return false
	return actor.grid_pos == player.grid_pos + facing


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _has_property(object, property_name: String) -> bool:
	if object == null or not object.has_method("get_property_list"):
		return false
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
