class_name NpcInteractionService
extends RefCounted

const CARDINAL_DIRS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]


func find_interactable_npc(state):
	if state == null or state.player == null:
		return null
	var best_npc = null
	var best_distance: int = 999999
	for actor in state.actors:
		if not _is_interactable_npc(actor, state.player):
			continue
		var distance: int = _manhattan(actor.grid_pos, state.player.grid_pos)
		if distance < best_distance:
			best_npc = actor
			best_distance = distance
	return best_npc


func interact(state, progress_by_npc_id: Dictionary) -> Dictionary:
	var npc = find_interactable_npc(state)
	if npc == null:
		return {"handled": false}

	var npc_def = npc.def
	var npc_id: String = String(npc_def.id if npc_def != null else npc.grid_item_id)
	var lines: PackedStringArray = PackedStringArray()
	if npc_def != null and _has_property(npc_def, "interaction_lines"):
		lines = PackedStringArray(npc_def.get("interaction_lines"))
	var line_index: int = int(progress_by_npc_id.get(npc_id, 0))
	var line: String = ""
	if not lines.is_empty():
		line = String(lines[line_index % lines.size()])
	progress_by_npc_id[npc_id] = line_index + 1

	var title: String = String(npc.display_name)
	if npc_def != null and _has_property(npc_def, "interaction_title"):
		var configured_title := String(npc_def.get("interaction_title"))
		if not configured_title.is_empty():
			title = configured_title

	var prompt: String = "交谈"
	if npc_def != null and _has_property(npc_def, "interaction_prompt"):
		var configured_prompt := String(npc_def.get("interaction_prompt"))
		if not configured_prompt.is_empty():
			prompt = configured_prompt

	var dialogue_resource_path: String = ""
	var dialogue_cue: String = ""
	if npc_def != null and _has_property(npc_def, "dialogue_resource_path"):
		dialogue_resource_path = String(npc_def.get("dialogue_resource_path"))
	if npc_def != null and _has_property(npc_def, "dialogue_cue"):
		dialogue_cue = String(npc_def.get("dialogue_cue"))

	return {
		"handled": true,
		"npc": npc,
		"npc_id": npc_id,
		"npc_name": String(npc.display_name),
		"title": title,
		"prompt": prompt,
		"line": line,
		"dialogue_resource_path": dialogue_resource_path,
		"dialogue_cue": dialogue_cue,
	}


func get_interaction_prompt(state) -> String:
	var npc = find_interactable_npc(state)
	if npc == null:
		return ""
	var npc_def = npc.def
	var prompt := "交谈"
	if npc_def != null and _has_property(npc_def, "interaction_prompt"):
		var configured_prompt := String(npc_def.get("interaction_prompt"))
		if not configured_prompt.is_empty():
			prompt = configured_prompt
	return "确认键%s：%s" % [prompt, String(npc.display_name)]


func _is_interactable_npc(actor, player) -> bool:
	if actor == null or player == null or actor == player:
		return false
	if actor.has_method("is_dead") and actor.is_dead():
		return false
	if not actor.tags.has("npc"):
		return false
	var range_limit: int = 1
	if actor.def != null and _has_property(actor.def, "interaction_range"):
		range_limit = maxi(1, int(actor.def.get("interaction_range")))
	var distance: int = _manhattan(actor.grid_pos, player.grid_pos)
	return distance <= range_limit


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _has_property(object, property_name: String) -> bool:
	if object == null or not object.has_method("get_property_list"):
		return false
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
