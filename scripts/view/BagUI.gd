class_name BagUI
extends Control

signal key_token_move_requested(source_slot_id: String, source_index: int, target_slot_id: String)
signal key_slot_preview_requested(slot_id: String)
signal key_slot_preview_cleared(slot_id: String)

const SLOT_ORDER: Array[String] = ["Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V"]
const KEY_POOL_ID := "POOL"

const UiKeySlotScript := preload("res://scripts/view/UiKeySlot.gd")
const UiKeyTokenScript := preload("res://scripts/view/UiKeyToken.gd")

var _key_grid: GridContainer = null
var _pool_container: VBoxContainer = null
var _buffs_list: VBoxContainer = null
var _editable_label: Label = null

var _slot_chains: Dictionary = {}
var _pool_tokens: Array[String] = []
var _editable := false
var _permanent_buffs: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_find_nodes()


func _find_nodes() -> void:
	var header := find_child("Header", true, false)
	if header:
		_editable_label = header.find_child("EditableLabel", false, false) as Label

	var left_panel := find_child("LeftPanel", true, false)
	if left_panel:
		_key_grid = left_panel.find_child("KeyGrid", false, false) as GridContainer
		_buffs_list = left_panel.find_child("BuffsList", false, false) as VBoxContainer

	var pool_scroll := find_child("PoolScroll", true, false)
	if pool_scroll:
		_pool_container = pool_scroll.find_child("PoolContainer", false, false) as VBoxContainer

	if _key_grid:
		_key_grid.columns = 4


func setup(slot_chains: Dictionary, pool_tokens: Array, editable: bool, buffs: Array[Dictionary]) -> void:
	_slot_chains.clear()
	for key_id in SLOT_ORDER:
		_slot_chains[key_id] = []
		for token_id in slot_chains.get(key_id, []):
			_slot_chains[key_id].append(String(token_id))

	_pool_tokens.clear()
	for token_id in pool_tokens:
		_pool_tokens.append(String(token_id))

	_editable = editable
	_permanent_buffs = buffs.duplicate(true)
	_refresh()


func open_bag() -> void:
	visible = true


func close_bag() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _refresh() -> void:
	if not is_node_ready():
		return

	_find_nodes()

	if _editable_label:
		_editable_label.text = "可编辑 · 拖拽调整按键绑定" if _editable else "已锁定 · 查看不可编辑"

	if _key_grid:
		for child in _key_grid.get_children():
			child.queue_free()
		for key_id in SLOT_ORDER:
			_key_grid.add_child(_make_key_slot_panel(key_id))

	if _pool_container:
		for child in _pool_container.get_children():
			child.queue_free()
		_pool_container.add_child(_make_pool_slot_panel())

	if _buffs_list:
		for child in _buffs_list.get_children():
			child.queue_free()
		if _permanent_buffs.is_empty():
			var empty := Label.new()
			empty.text = "暂无永久增益"
			empty.theme_type_variation = &"ScreenHint"
			_buffs_list.add_child(empty)
		else:
			for buff_data in _permanent_buffs:
				var buff_label := Label.new()
				buff_label.text = "- %s" % String(buff_data.get("name", ""))
				var desc := String(buff_data.get("description", ""))
				buff_label.tooltip_text = desc
				buff_label.mouse_filter = Control.MOUSE_FILTER_STOP
				buff_label.theme_type_variation = &"BattleMessage"
				_buffs_list.add_child(buff_label)


func _make_key_slot_panel(key_id: String) -> PanelContainer:
	var token_ids: Array = _slot_chains.get(key_id, [])
	var binding := _get_binding_label(key_id)
	var suffix := "可调整" if _editable else "锁定"
	var title := "%s键槽 [%s] · %s" % [key_id, binding, suffix]

	var panel = UiKeySlotScript.new()
	panel.setup(key_id, _editable)
	panel.key_dropped.connect(_on_key_dropped)
	panel.preview_requested.connect(_on_key_slot_preview_requested)
	panel.preview_cleared.connect(_on_key_slot_preview_cleared)
	panel.custom_minimum_size = Vector2(0, 70)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"BattleSectionTitle"
	content.add_child(title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)

	if token_ids.is_empty():
		var empty := Label.new()
		empty.text = "空：按键无映射"
		empty.theme_type_variation = &"ScreenHint"
		row.add_child(empty)
		return panel

	for index in range(token_ids.size()):
		var token_key_id := String(token_ids[index])
		var token = UiKeyTokenScript.new()
		token.setup(token_key_id, key_id, index, _token_label(token_key_id), _editable)
		row.add_child(token)

	return panel


func _make_pool_slot_panel() -> PanelContainer:
	var title := "备用 token（未分配技能）" if _editable else "备用 token（只读）"

	var panel = UiKeySlotScript.new()
	panel.setup(KEY_POOL_ID, _editable)
	panel.key_dropped.connect(_on_key_dropped)
	panel.custom_minimum_size = Vector2(0, 70)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"BattleSectionTitle"
	content.add_child(title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	content.add_child(row)

	if _pool_tokens.is_empty():
		var empty := Label.new()
		empty.text = "暂无备用 token"
		empty.theme_type_variation = &"ScreenHint"
		row.add_child(empty)
		return panel

	for index in range(_pool_tokens.size()):
		var token_key_id := String(_pool_tokens[index])
		var token = UiKeyTokenScript.new()
		token.setup(token_key_id, KEY_POOL_ID, index, _token_label(token_key_id), _editable)
		row.add_child(token)

	return panel


func _on_key_dropped(target_slot_id: String, drag_data: Dictionary) -> void:
	key_token_move_requested.emit(
		String(drag_data["source_slot_id"]),
		int(drag_data["source_index"]),
		target_slot_id
	)


func _on_key_slot_preview_requested(slot_id: String) -> void:
	key_slot_preview_requested.emit(slot_id)


func _on_key_slot_preview_cleared(slot_id: String) -> void:
	key_slot_preview_cleared.emit(slot_id)


func _get_binding_label(key_id: String) -> String:
	var input_service = get_node_or_null("/root/PlayerInputService")
	if input_service == null:
		return key_id
	var action_name: String = input_service.get_action_for_key_id(key_id)
	if action_name.is_empty():
		return key_id
	return input_service.get_binding_label(action_name)


func _token_label(token_id: String) -> String:
	match token_id:
		"F":
			return "前进"
		"TL":
			return "左转"
		"TR":
			return "右转"
		"J":
			return "跳跃"
		"U":
			return "上"
		"D":
			return "下"
		"L":
			return "左"
		"R":
			return "右"
	return token_id
