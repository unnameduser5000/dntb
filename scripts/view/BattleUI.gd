class_name BattleUI
extends Control

signal start_requested
signal reward_chosen(index: int)
signal restart_requested
signal key_token_move_requested(source_slot_id: String, source_index: int, target_slot_id: String)
signal key_slot_preview_requested(slot_id: String)
signal key_slot_preview_cleared(slot_id: String)
signal rest_continue_requested

const KEY_POOL_ID := "POOL"
const KEY_ORDER := ["U", "D", "L", "R"]
const KEY_NAMES := {
	"U": "上",
	"D": "下",
	"L": "左",
	"R": "右",
}
const UiActionCardScene := preload("res://scenes/ui/components/UiActionCard.tscn")
const UiKeySlotScript := preload("res://scripts/view/UiKeySlot.gd")
const UiKeyTokenScript := preload("res://scripts/view/UiKeyToken.gd")

@onready var _panel: PanelContainer = %BattlePanel
@onready var _overlay: Control = %Overlay
@onready var _hud: BattleHud = %BattleHud
@onready var _run_sidebar: RunSidebar = %RunSidebar
@onready var _key_slot_grid: GridContainer = %ActionList
@onready var _key_pool_container: VBoxContainer = %KeyPoolContainer
@onready var _message_list: VBoxContainer = %MessageList
@onready var _intent_list: VBoxContainer = %IntentList
@onready var _action_title: Label = $BattlePanel/Margin/Scroll/Content/ActionTitle
@onready var _hp_value: Label = $BattlePanel/Margin/Scroll/Content/HpRow/Value
@onready var _room_value: Label = $BattlePanel/Margin/Scroll/Content/RoomRow/Value
@onready var _enemy_value: Label = $BattlePanel/Margin/Scroll/Content/EnemyRow/Value
@onready var _turn_value: Label = $BattlePanel/Margin/Scroll/Content/TurnRow/Value
@onready var _rest_continue_button: Button = %RestContinueButton
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_body: Label = %OverlayBody
@onready var _overlay_buttons: VBoxContainer = %OverlayButtons

var _slot_chains: Dictionary = {}
var _pool_tokens: Array[String] = []
var _key_program_editable := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rest_continue_button.pressed.connect(func() -> void: rest_continue_requested.emit())
	_key_slot_grid.columns = 2
	show_title()


func _unhandled_input(_event: InputEvent) -> void:
	pass


func set_key_program(slot_chains: Dictionary, pool_tokens: Array) -> void:
	_slot_chains = _duplicate_key_program(slot_chains)
	_pool_tokens.clear()
	for token_id in pool_tokens:
		_pool_tokens.append(String(token_id))
	_refresh_key_program()


func set_key_program_editable(is_editable: bool) -> void:
	_key_program_editable = is_editable
	_refresh_key_program()


func set_inventory_items(items: Array) -> void:
	_run_sidebar.set_inventory_items(items)


func update_state(state) -> void:
	if state == null:
		return

	_panel.visible = true
	_hud.update_state(state)
	_run_sidebar.update_state(state)
	_hp_value.text = "%d/%d" % [state.player.hp, state.player.max_hp]
	_room_value.text = "%d - %s" % [state.room_index + 1, state.room_name]
	_enemy_value.text = str(state.get_alive_enemies().size())
	_turn_value.text = str(state.turn_count)
	if bool(state.is_world_slice):
		if _key_program_editable:
			_action_title.text = "按键槽：酒馆休息区内可调整"
		else:
			_action_title.text = "按键槽：已锁定，回到酒馆可调整"
	_refresh_messages(state.messages)
	_refresh_intents(state.enemy_intents)


func show_title() -> void:
	_panel.visible = false
	_hud.visible = false
	_run_sidebar.visible = false
	_show_overlay("别按那个键", "在休息点编排四个键槽，进战斗后按键执行，真实结果再驱动武器连招。", [
		{"text": "开始游戏", "callback": func() -> void: start_requested.emit()},
	])


func show_battle() -> void:
	_overlay.visible = false
	_panel.visible = true
	_hud.visible = true
	_run_sidebar.visible = true
	_rest_continue_button.visible = false
	_action_title.text = "按键槽：战斗中锁定"


func show_rest_site(title: String, body: String = "") -> void:
	_overlay.visible = false
	_panel.visible = true
	_hud.visible = true
	_run_sidebar.visible = true
	_rest_continue_button.visible = true
	_action_title.text = "%s：可拖拽调整四个键槽" % title
	if not body.is_empty():
		_add_screen_message(body)


func show_reward(rewards: Array) -> void:
	var buttons: Array = []
	for index in range(rewards.size()):
		var reward = rewards[index]
		buttons.append({
			"text": reward["name"],
			"callback": _emit_reward_chosen.bind(index),
		})

	_show_overlay("选择奖励", "房间清空。选一个奖励继续前进。", buttons)


func show_result(victory: bool) -> void:
	var title := "通关" if victory else "失败"
	var body := "你打穿了这个盒装小样。" if victory else "玩家倒下了。再跑一局。"
	_show_overlay(title, body, [
		{"text": "重新开始", "callback": func() -> void: restart_requested.emit()},
	])


func _show_overlay(title_text: String, body_text: String, buttons: Array) -> void:
	_overlay.visible = true
	_overlay_title.text = title_text
	_overlay_body.text = body_text
	for child in _overlay_buttons.get_children():
		child.queue_free()

	for index in range(buttons.size()):
		var button_data = buttons[index]
		var button := UiActionCardScene.instantiate() as Button
		button.text = String(button_data["text"])
		if index == 0:
			button.theme_type_variation = &"PrimaryButton"
		button.pressed.connect(button_data["callback"])
		_overlay_buttons.add_child(button)


func _refresh_key_program() -> void:
	if not is_node_ready():
		return

	for child in _key_slot_grid.get_children():
		child.queue_free()

	for key_id in KEY_ORDER:
		var suffix := "可调整" if _key_program_editable else "锁定"
		_key_slot_grid.add_child(_make_slot_panel(key_id, "%s键槽 [%s] · %s" % [_key_name(key_id), _binding_label(key_id), suffix], _slot_chains.get(key_id, [])))

	for child in _key_pool_container.get_children():
		child.queue_free()

	_key_pool_container.add_child(_make_slot_panel(KEY_POOL_ID, "备用 token（拾取/奖励获得）", _pool_tokens))


func _make_slot_panel(slot_id: String, title: String, keys: Array) -> PanelContainer:
	var panel = UiKeySlotScript.new()
	panel.setup(slot_id, _key_program_editable)
	panel.key_dropped.connect(_on_key_dropped)
	panel.preview_requested.connect(_on_key_slot_preview_requested)
	panel.preview_cleared.connect(_on_key_slot_preview_cleared)
	panel.custom_minimum_size = Vector2(0, 76)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"BattleSectionTitle"
	content.add_child(title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)

	if keys.is_empty():
		var empty := Label.new()
		empty.text = "空：按键无映射" if slot_id != KEY_POOL_ID else "暂无备用 token"
		empty.theme_type_variation = &"ScreenHint"
		row.add_child(empty)
		return panel

	for index in range(keys.size()):
		var key_id := String(keys[index])
		var token = UiKeyTokenScript.new()
		token.setup(key_id, slot_id, index, _token_label(key_id), _key_program_editable)
		row.add_child(token)

	return panel


func _on_key_dropped(target_slot_id: String, drag_data: Dictionary) -> void:
	key_token_move_requested.emit(
		String(drag_data["source_slot_id"]),
		int(drag_data["source_index"]),
		target_slot_id
	)


func _on_key_slot_preview_requested(slot_id: String) -> void:
	if slot_id == KEY_POOL_ID:
		return
	key_slot_preview_requested.emit(slot_id)


func _on_key_slot_preview_cleared(slot_id: String) -> void:
	if slot_id == KEY_POOL_ID:
		return
	key_slot_preview_cleared.emit(slot_id)


func _emit_reward_chosen(index: int) -> void:
	reward_chosen.emit(index)


func _refresh_messages(messages: Array[String]) -> void:
	for child in _message_list.get_children():
		child.queue_free()

	for message in messages:
		_add_screen_message(message)


func _add_screen_message(message: String) -> void:
	var label := Label.new()
	label.text = "- %s" % message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = &"BattleMessage"
	_message_list.add_child(label)


func _refresh_intents(intents: Array) -> void:
	for child in _intent_list.get_children():
		child.queue_free()

	if intents.is_empty():
		var empty := Label.new()
		empty.text = "-"
		empty.theme_type_variation = &"ScreenHint"
		_intent_list.add_child(empty)
		return

	for intent in intents:
		var label := Label.new()
		label.text = intent
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"BattleIntent"
		_intent_list.add_child(label)


func _duplicate_key_program(slot_chains: Dictionary) -> Dictionary:
	var result := {}
	for key_id in KEY_ORDER:
		result[key_id] = []
		for chain_key_id in slot_chains.get(key_id, []):
			result[key_id].append(String(chain_key_id))
	return result


func _key_name(key_id: String) -> String:
	return String(KEY_NAMES.get(key_id, key_id))


func _token_label(token_id: String) -> String:
	match token_id:
		"TL":
			return "左转"
		"TR":
			return "右转"
		"J":
			return "跳跃"
	if KEY_ORDER.has(token_id) or KEY_NAMES.has(token_id):
		return _key_name(token_id)
	return token_id


func _binding_label(key_id: String) -> String:
	var input_service = get_node_or_null("/root/PlayerInputService")
	if input_service == null:
		return key_id
	var action_name: String = input_service.get_action_for_key_id(key_id)
	if action_name.is_empty():
		return key_id
	return input_service.get_binding_label(action_name)
