class_name WeaponComboResolver
extends RefCounted

## WeaponComboResolver reads ActionTrace and finds weapon techniques whose
## patterns match the actor's recent execution semantics.
##
## Current scope:
## - recognition over ActionTrace
## - non-overlapping matching over ActionTrace entries
## - no direct battle-state writes inside this resolver itself
##
## TurnController consumes its match results after base actions resolve.
## That keeps recognition logic separate from the follow-up execution step.


func find_matches(actor, trace, unlocked_technique_ids: Array[String] = [], trigger_timing: int = -1) -> Array:
	if actor == null or trace == null:
		return []
	return find_matches_for_entries(actor, trace.get_recent_entries_for_actor(int(actor.id)), unlocked_technique_ids, trigger_timing)


func find_matches_for_symbols(actor, trace_symbols: Array[StringName], unlocked_technique_ids: Array[String] = [], trigger_timing: int = -1) -> Array:
	var entries: Array = []
	for symbol in trace_symbols:
		var entry := {
			"symbol": StringName(symbol),
			"moved": false,
			"move_dir": Vector2i.ZERO,
		}
		entries.append(entry)
	return find_matches_for_entries(actor, entries, unlocked_technique_ids, trigger_timing)


func find_matches_for_entries(actor, trace_entries: Array, unlocked_technique_ids: Array[String] = [], trigger_timing: int = -1) -> Array:
	var results: Array = []
	if actor == null or actor.active_weapon == null:
		return results

	var techniques: Array = _sorted_techniques(_weapon_combo_techniques(actor.active_weapon))
	if techniques.is_empty():
		return results

	if trace_entries.is_empty():
		return results

	for technique in techniques:
		if not _is_technique_available(actor.active_weapon, technique, unlocked_technique_ids):
			continue
		if trigger_timing >= 0 and int(technique.trigger_timing) != trigger_timing:
			continue
		var matches: Array = _match_technique(trace_entries, technique)
		for match_data in matches:
			results.append(match_data)

	results.sort_custom(func(a, b) -> bool:
		var a_index := int(a.get("match_start_index", 0))
		var b_index := int(b.get("match_start_index", 0))
		if a_index != b_index:
			return a_index < b_index

		var a_priority := 0 if a == null or not a.has("technique") or a["technique"] == null else int(a["technique"].priority)
		var b_priority := 0 if b == null or not b.has("technique") or b["technique"] == null else int(b["technique"].priority)
		if a_priority != b_priority:
			return a_priority > b_priority

		var a_id := "" if a == null else String(a.get("technique_id", ""))
		var b_id := "" if b == null else String(b.get("technique_id", ""))
		return a_id < b_id
	)

	return results


func find_best_match(actor, trace, unlocked_technique_ids: Array[String] = [], trigger_timing: int = -1) -> Dictionary:
	var matches := find_matches(actor, trace, unlocked_technique_ids, trigger_timing)
	return {} if matches.is_empty() else matches[0]


func _weapon_combo_techniques(weapon) -> Array:
	if weapon == null:
		return []
	var raw_techniques = weapon.get("combo_techniques")
	if raw_techniques is Array:
		return raw_techniques
	return []


func _is_technique_available(weapon, technique, _unlocked_technique_ids: Array[String]) -> bool:
	if weapon == null or technique == null:
		return false

	var technique_id := String(technique.resolved_technique_id())
	if technique_id.is_empty():
		return false

	# Current baseline rule:
	# equipped weapon support is enough to make its combo technique available.
	# unlocked_technique_ids stays in the function signature as a future hook for
	# mastery / seal / upgrade restrictions, but it does not gate the default
	# combat flow right now.
	if weapon.has_method("supports_technique"):
		return bool(weapon.call("supports_technique", technique_id))
	return true


func _match_technique(trace_entries: Array, technique) -> Array:
	var results: Array = []
	if technique == null:
		return results

	match int(technique.pattern_type):
		int(WeaponTechniqueDef.PatternType.SYMBOL_SEQUENCE):
			results = _match_symbol_sequence(trace_entries, technique)
		int(WeaponTechniqueDef.PatternType.SAME_MOVE_DIRECTION):
			results = _match_same_move_direction(trace_entries, technique)
		_:
			results = _match_symbol_sequence(trace_entries, technique)

	return results


func _match_symbol_sequence(trace_entries: Array, technique) -> Array:
	var results: Array = []
	var pattern: Array = technique.pattern
	var pattern_size := pattern.size()
	if pattern_size <= 0 or trace_entries.size() < pattern_size:
		return results

	var index := 0
	while index <= trace_entries.size() - pattern_size:
		var matched := true
		for offset in range(pattern_size):
			var entry = trace_entries[index + offset]
			if entry == null or _entry_symbol(entry) != StringName(pattern[offset]):
				matched = false
				break
		if matched:
			results.append(_build_match_data(technique, trace_entries, index, pattern_size, pattern.duplicate()))
			index += pattern_size
		else:
			index += 1
	return results


func _match_same_move_direction(trace_entries: Array, technique) -> Array:
	var results: Array = []
	var required_count := maxi(0, int(technique.required_move_count))
	if required_count <= 0 or trace_entries.size() < required_count:
		return results

	var index := 0
	while index <= trace_entries.size() - required_count:
		var first = trace_entries[index]
		if first == null or not _entry_moved(first):
			index += 1
			continue

		var move_dir := _entry_move_dir(first)
		if move_dir == Vector2i.ZERO:
			index += 1
			continue

		var matched := true
		for offset in range(1, required_count):
			var entry = trace_entries[index + offset]
			if entry == null or not _entry_moved(entry) or _entry_move_dir(entry) != move_dir:
				matched = false
				break
		if matched:
			results.append(_build_match_data(
				technique,
				trace_entries,
				index,
				required_count,
				_entry_symbols(trace_entries, index, required_count),
				{
					"matched_move_dir": move_dir,
					"matched_move_dirs": [move_dir],
				}
			))
			index += required_count
		else:
			index += 1
	return results


func _build_match_data(technique, trace_entries: Array, start_index: int, match_size: int, matched_symbols: Array[StringName], extra_data: Dictionary = {}) -> Dictionary:
	var trace_symbols: Array[StringName] = []
	for entry in trace_entries:
		if entry == null:
			continue
		trace_symbols.append(_entry_symbol(entry))

	var match_data := {
		"technique_id": technique.resolved_technique_id(),
		"technique": technique,
		"matched_symbols": matched_symbols,
		"trace_symbols": trace_symbols,
		"consume_pattern": bool(technique.consume_pattern),
		"trigger_timing": int(technique.trigger_timing),
		"match_start_index": start_index,
		"match_size": match_size,
	}
	for key in extra_data.keys():
		match_data[key] = extra_data[key]
	return match_data


func _entry_symbols(trace_entries: Array, start_index: int, match_size: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for offset in range(match_size):
		var entry = trace_entries[start_index + offset]
		if entry == null:
			continue
		result.append(_entry_symbol(entry))
	return result


func _entry_symbol(entry) -> StringName:
	if entry == null:
		return &""
	if entry is Dictionary:
		return StringName(entry.get("symbol", ""))
	return StringName(entry.symbol)


func _entry_moved(entry) -> bool:
	if entry == null:
		return false
	if entry is Dictionary:
		return bool(entry.get("moved", false))
	return bool(entry.moved)


func _entry_move_dir(entry) -> Vector2i:
	if entry == null:
		return Vector2i.ZERO
	if entry is Dictionary:
		return Vector2i(entry.get("move_dir", Vector2i.ZERO))
	return Vector2i(entry.move_dir)


func _sorted_techniques(techniques: Array) -> Array:
	var sorted := techniques.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var a_len := 0 if a == null else int(a.pattern_size())
		var b_len := 0 if b == null else int(b.pattern_size())
		if a_len != b_len:
			return a_len > b_len

		var a_priority := 0 if a == null else int(a.priority)
		var b_priority := 0 if b == null else int(b.priority)
		if a_priority != b_priority:
			return a_priority > b_priority

		var a_id := "" if a == null else String(a.resolved_technique_id())
		var b_id := "" if b == null else String(b.resolved_technique_id())
		return a_id < b_id
	)
	return sorted
