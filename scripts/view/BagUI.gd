class_name BagUI
extends Control

signal key_token_move_requested(source_slot_id: String, source_index: int, target_slot_id: String)
signal key_slot_preview_requested(slot_id: String)
signal key_slot_preview_cleared(slot_id: String)
signal close_requested

const SLOT_ORDER: Array[String] = ["Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V"]
const KEY_POOL_ID := "POOL"
const TOKEN_DESCRIPTIONS := {
	"U": "向上移动一格。",
	"D": "向下移动一格。",
	"L": "向左移动一格。",
	"R": "向右移动一格。",
	"F": "朝当前朝向前进一格。",
	"B": "朝当前朝向后退一格。",
	"TL": "原地向左转，改变后续动作朝向。",
	"TR": "原地向右转，改变后续动作朝向。",
	"A": "触发当前武器的基础攻击动作。",
	"G": "进入防御，减少下一次受到的伤害。",
	"W": "等待一拍，不移动也不攻击。",
	"J": "朝当前朝向跳跃到落点；落点被阻挡则失败。",
}

const UiKeySlotScript := preload("res://scripts/view/UiKeySlot.gd")
const UiKeyTokenScript := preload("res://scripts/view/UiKeyToken.gd")
const UiPoolDropAreaScript := preload("res://scripts/view/UiPoolDropArea.gd")
const UiPoolDropCellScript := preload("res://scripts/view/UiPoolDropCell.gd")

@export var key_grid_columns: int = 4
@export var key_slot_token_columns: int = 2
@export var key_slot_visible_capacity: int = 2
@export var token_pool_columns: int = 5
@export var token_pool_visible_capacity: int = 25
@export var token_cell_size: Vector2 = Vector2(58, 38)
@export var key_slot_panel_min_width: float = 220.0
@export var buffs_panel_height: float = 152.0

var _bag_panel: Control = null
var _left_panel: Control = null
var _key_grid: GridContainer = null
var _pool_container: GridContainer = null
var _buffs_list: VBoxContainer = null
var _buffs_title: Label = null
var _pool_title: Label = null
var _buffs_scroll: ScrollContainer = null
var _key_scroll: ScrollContainer = null
var _editable_label: Label = null
var _hint_label: Label = null
var _close_button: Button = null

var _slot_chains: Dictionary = {}
var _pool_tokens: Array[String] = []
var _editable := false
var _permanent_buffs: Array[Dictionary] = []
var _slot_panels: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_find_nodes()
	_disable_button_focus()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var bag_panel := find_child("BagPanel", true, false) as Control
	if bag_panel == null:
		close_requested.emit()
		accept_event()
		return

	if not bag_panel.get_global_rect().has_point(get_global_mouse_position()):
		close_requested.emit()
		accept_event()


func _disable_button_focus(node: Node = self) -> void:
	for child in node.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
		_disable_button_focus(child)


func _find_nodes() -> void:
	_bag_panel = get_node_or_null("BagPanel") as Control
	_editable_label = get_node_or_null("BagPanel/Margin/Content/LeftPanel/Header/EditableLabel") as Label
	_hint_label = get_node_or_null("BagPanel/Margin/Content/LeftPanel/Header/HintLabel") as Label
	_close_button = get_node_or_null("BagPanel/Margin/Content/LeftPanel/Header/CloseButton") as Button
	_left_panel = get_node_or_null("BagPanel/Margin/Content/LeftPanel") as Control
	_key_scroll = get_node_or_null("BagPanel/Margin/Content/LeftPanel/KeyScroll") as ScrollContainer
	_key_grid = get_node_or_null("BagPanel/Margin/Content/LeftPanel/KeyScroll/KeyGrid") as GridContainer
	_buffs_title = get_node_or_null("BagPanel/Margin/Content/LeftPanel/BuffsTitle") as Label
	_buffs_scroll = get_node_or_null("BagPanel/Margin/Content/LeftPanel/BuffsScroll") as ScrollContainer
	_buffs_list = get_node_or_null("BagPanel/Margin/Content/LeftPanel/BuffsScroll/BuffsList") as VBoxContainer
	_pool_title = get_node_or_null("BagPanel/Margin/Content/RightPanel/PoolTitle") as Label
	_pool_container = get_node_or_null("BagPanel/Margin/Content/RightPanel/PoolScroll/PoolContainer") as GridContainer
	if _pool_container and _pool_container.has_signal("drop_requested"):
		if not _pool_container.drop_requested.is_connected(_on_key_dropped):
			_pool_container.drop_requested.connect(_on_key_dropped)
	if _pool_container and _pool_container.has_signal("interaction_blocked"):
		if not _pool_container.interaction_blocked.is_connected(_on_locked_slot_interaction):
			_pool_container.interaction_blocked.connect(_on_locked_slot_interaction)

	if _close_button and not _close_button.pressed.is_connected(_on_close_button_pressed):
		_close_button.pressed.connect(_on_close_button_pressed)

	_apply_layout_settings()


func _apply_layout_settings() -> void:
	if _bag_panel:
		_bag_panel.custom_minimum_size = Vector2(1120, 680)
	if _key_grid:
		_key_grid.columns = maxi(1, key_grid_columns)
		_key_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_key_grid.custom_minimum_size = _key_grid_min_size()
	if _key_scroll:
		_key_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_key_scroll.custom_minimum_size = Vector2(_key_grid_min_size().x, 392.0)
	if _left_panel:
		_left_panel.custom_minimum_size = Vector2(_key_grid_min_size().x, 0.0)
	if _pool_container:
		if _pool_container.has_method("setup"):
			_pool_container.setup(_editable)
		_pool_container.columns = maxi(1, token_pool_columns)
	if _buffs_scroll:
		_buffs_scroll.custom_minimum_size = Vector2(0, buffs_panel_height)


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
	if _hint_label:
		_hint_label.text = "同一键位会按从左到右顺序触发；Tab / Esc 关闭；休息区可拖拽编辑" if _editable else "同一键位会按从左到右顺序触发；Tab / Esc 关闭；战斗中只可查看顺序"
	if _buffs_title:
		_buffs_title.text = "永久增益（悬停查看详情）"
	if _pool_title:
		_pool_title.text = "未分配技能 / Token（%d格起）" % maxi(1, token_pool_visible_capacity)

	if _key_grid:
		_slot_panels.clear()
		for child in _key_grid.get_children():
			child.queue_free()
		for key_id in SLOT_ORDER:
			_key_grid.add_child(_make_key_slot_panel(key_id))
		_key_grid.custom_minimum_size = _key_grid_min_size()

	if _pool_container:
		for child in _pool_container.get_children():
			child.queue_free()
		_refresh_pool_grid()

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
				var buff_name := String(buff_data.get("name", ""))
				var desc := String(buff_data.get("description", ""))
				buff_label.text = "• %s" % buff_name if not desc.is_empty() else "• %s" % buff_name
				buff_label.tooltip_text = desc
				buff_label.mouse_filter = Control.MOUSE_FILTER_STOP
				buff_label.theme_type_variation = &"BattleMessage"
				_buffs_list.add_child(buff_label)

	_disable_button_focus()


func _make_key_slot_panel(key_id: String) -> PanelContainer:
	var token_ids: Array = _slot_chains.get(key_id, [])
	var binding := _get_binding_label(key_id)
	var suffix := "可调整" if _editable else "锁定"
	var meta_text := "绑定：%s · %d格 · %s" % [binding, maxi(1, key_slot_visible_capacity), suffix]

	var panel = UiKeySlotScript.new()
	panel.setup(key_id, _editable)
	panel.key_dropped.connect(_on_key_dropped)
	panel.preview_requested.connect(_on_key_slot_preview_requested)
	panel.preview_cleared.connect(_on_key_slot_preview_cleared)
	panel.interaction_blocked.connect(_on_locked_slot_interaction)
	panel.custom_minimum_size = Vector2(key_slot_panel_min_width, _key_slot_panel_min_height())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_panels[key_id] = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	content.add_child(header_row)

	header_row.add_child(_make_key_badge(key_id))

	var meta_label := Label.new()
	meta_label.text = meta_text
	meta_label.theme_type_variation = &"BattleSectionTitle"
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(meta_label)

	var token_grid := GridContainer.new()
	token_grid.columns = maxi(1, key_slot_token_columns)
	token_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	token_grid.add_theme_constant_override("h_separation", 4)
	token_grid.add_theme_constant_override("v_separation", 4)
	content.add_child(token_grid)

	var visible_slots := maxi(maxi(1, key_slot_visible_capacity), token_ids.size())
	for index in range(visible_slots):
		if index < token_ids.size():
			token_grid.add_child(_make_token_button(String(token_ids[index]), key_id, index))
		else:
			token_grid.add_child(_make_key_slot_empty_cell())

	return panel


func _refresh_pool_grid() -> void:
	if _pool_container == null:
		return
	if _pool_container.has_method("setup"):
		_pool_container.setup(_editable)
	_pool_container.columns = maxi(1, token_pool_columns)
	var visible_slots := maxi(maxi(1, token_pool_visible_capacity), _pool_tokens.size())
	for index in range(visible_slots):
		if index < _pool_tokens.size():
			_pool_container.add_child(_make_token_button(String(_pool_tokens[index]), KEY_POOL_ID, index))
		else:
			_pool_container.add_child(_make_pool_empty_token_cell())


func _make_token_button(token_id: String, source_slot_id: String, source_index: int) -> Control:
	var token = UiKeyTokenScript.new()
	token.setup(
		token_id,
		source_slot_id,
		source_index,
		_token_label(token_id),
		_editable,
		_token_tooltip(token_id),
		token_cell_size
	)
	if not token.drop_requested.is_connected(_on_key_dropped):
		token.drop_requested.connect(_on_key_dropped)
	if not token.interaction_blocked.is_connected(_on_locked_slot_interaction):
		token.interaction_blocked.connect(_on_locked_slot_interaction)
	return token


func _make_key_slot_empty_cell() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = token_cell_size
	panel.theme_type_variation = &"ScreenPanel"
	panel.tooltip_text = "空槽位"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_square_stylebox(Color(0.15, 0.17, 0.2, 0.95), Color(0.34, 0.38, 0.45, 0.9)))
	return panel


func _make_pool_empty_token_cell() -> Control:
	var panel := UiPoolDropCellScript.new()
	panel.setup(_editable)
	panel.custom_minimum_size = token_cell_size
	panel.theme_type_variation = &"ScreenPanel"
	panel.tooltip_text = "空槽位"
	panel.add_theme_stylebox_override("panel", _make_square_stylebox(Color(0.15, 0.17, 0.2, 0.95), Color(0.34, 0.38, 0.45, 0.9)))
	if not panel.drop_requested.is_connected(_on_key_dropped):
		panel.drop_requested.connect(_on_key_dropped)
	return panel


func _key_slot_panel_min_height() -> float:
	var visible_rows := int(ceil(float(maxi(1, key_slot_visible_capacity)) / float(maxi(1, key_slot_token_columns))))
	return 44.0 + float(visible_rows) * (token_cell_size.y + 4.0) + 18.0


func _key_grid_min_size() -> Vector2:
	var column_count: int = maxi(1, key_grid_columns)
	var row_count: int = int(ceil(float(SLOT_ORDER.size()) / float(column_count)))
	var horizontal_gap: float = float(_key_grid.get_theme_constant("h_separation")) if _key_grid else 8.0
	var vertical_gap: float = float(_key_grid.get_theme_constant("v_separation")) if _key_grid else 6.0
	var width := float(column_count) * key_slot_panel_min_width + float(column_count - 1) * horizontal_gap
	var height := float(row_count) * _key_slot_panel_min_height() + float(row_count - 1) * vertical_gap
	return Vector2(width, height)


func _token_tooltip(token_id: String) -> String:
	var title := _token_label(token_id)
	var description := String(TOKEN_DESCRIPTIONS.get(token_id, "TODO：当前动作简介尚未接到统一的 ActionDef.description API。"))
	var drag_hint := "可拖拽到键位槽，按链顺序执行。" if _editable else "当前只读，可在休息区调整。"
	return "%s\n%s\n%s" % [title, description, drag_hint]

func _make_key_badge(key_id: String) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(42, 30)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _make_square_stylebox(Color(0.21, 0.24, 0.3, 1.0), Color(0.78, 0.82, 0.88, 0.92)))

	var label := Label.new()
	label.text = key_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.theme_type_variation = &"ScreenTitle"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _make_square_stylebox(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


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


func _on_locked_slot_interaction(slot_id: String) -> void:
	if _editable:
		return
	var panel = _slot_panels.get(slot_id)
	if panel != null and panel is UiKeySlot:
		panel.play_locked_feedback()


func _on_close_button_pressed() -> void:
	close_requested.emit()


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
		"B":
			return "后退"
		"TL":
			return "左转"
		"TR":
			return "右转"
		"A":
			return "攻击"
		"G":
			return "防御"
		"W":
			return "等待"
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
