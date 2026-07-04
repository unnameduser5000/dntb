class_name BattleUI
extends Control

signal start_requested
signal reward_chosen(index: int)
signal restart_requested
signal key_token_move_requested(source_slot_id: String, source_index: int, target_slot_id: String)
signal key_slot_preview_requested(slot_id: String)
signal key_slot_preview_cleared(slot_id: String)
signal rest_continue_requested
signal bag_toggle_requested
signal pause_menu_requested

const UiActionCardScene := preload("res://scenes/ui/components/UiActionCard.tscn")
const UiRewardCardScene := preload("res://scenes/ui/components/UiRewardCard.tscn")
const BagUIScript = preload("res://scripts/view/BagUI.gd")

@onready var _panel: PanelContainer = %BattlePanel
@onready var _overlay: Control = %Overlay
@onready var _hud: Control = %BattleHud
@onready var _feed_panel: PanelContainer = %FeedPanel
@onready var _feed_text: Label = %FeedText
@onready var _run_sidebar: Control = %RunSidebar
@onready var _rest_continue_button: Button = %RestContinueButton
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_body: Label = %OverlayBody
@onready var _overlay_buttons: HBoxContainer = %OverlayButtons
@onready var _bag_ui = %BagUI
@onready var _npc_dialogue_panel: PanelContainer = %NpcDialoguePanel
@onready var _npc_dialogue_title: Label = %NpcDialogueTitle
@onready var _npc_dialogue_body: Label = %NpcDialogueBody
@onready var _npc_dialogue_hint: Label = %NpcDialogueHint

var _key_program_editable := false
var _permanent_buffs: Array[Dictionary] = []
var _cached_slot_chains: Dictionary = {}
var _cached_pool_tokens: Array[String] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rest_continue_button.pressed.connect(func() -> void: rest_continue_requested.emit())
	_panel.visible = false
	show_title()
	_connect_bag_ui_signals()
	_refresh_bag_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not _bag_ui.is_open():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB or event.is_action_pressed("ui_cancel"):
		bag_toggle_requested.emit()
		get_viewport().set_input_as_handled()


func _connect_bag_ui_signals() -> void:
	_bag_ui.key_token_move_requested.connect(_on_bag_key_token_move_requested)
	_bag_ui.key_slot_preview_requested.connect(_on_bag_key_slot_preview_requested)
	_bag_ui.key_slot_preview_cleared.connect(_on_bag_key_slot_preview_cleared)
	_bag_ui.close_requested.connect(_on_bag_close_requested)
	_run_sidebar.bag_requested.connect(_on_run_sidebar_bag_requested)
	_run_sidebar.menu_requested.connect(_on_run_sidebar_menu_requested)


func _refresh_bag_ui() -> void:
	if not is_node_ready():
		return
	_bag_ui.setup(_cached_slot_chains, _cached_pool_tokens, _key_program_editable, _permanent_buffs)


func set_key_program(slot_chains: Dictionary, pool_tokens: Array) -> void:
	_cached_slot_chains.clear()
	for key_id in slot_chains:
		_cached_slot_chains[key_id] = slot_chains[key_id].duplicate()

	_cached_pool_tokens.clear()
	for token_id in pool_tokens:
		_cached_pool_tokens.append(String(token_id))

	_refresh_bag_ui()


func set_key_program_editable(is_editable: bool) -> void:
	_key_program_editable = is_editable
	_refresh_bag_ui()


func set_permanent_buffs(buffs: Array[Dictionary]) -> void:
	_permanent_buffs = buffs.duplicate(true)
	_refresh_bag_ui()


func set_inventory_items(items: Array) -> void:
	_run_sidebar.set_inventory_items(items)


func toggle_bag() -> void:
	if _bag_ui.is_open():
		_bag_ui.close_bag()
	else:
		_bag_ui.visible = true
		_bag_ui.open_bag()
	get_viewport().gui_release_focus()


func is_bag_open() -> bool:
	return _bag_ui.is_open()


func show_world_npc_dialogue(title_text: String, body_text: String, hint_text: String = "按任意键关闭") -> void:
	if _npc_dialogue_panel == null:
		return
	_npc_dialogue_title.text = title_text
	_npc_dialogue_body.text = body_text
	_npc_dialogue_hint.text = hint_text
	_npc_dialogue_panel.visible = true


func hide_world_npc_dialogue() -> void:
	if _npc_dialogue_panel == null:
		return
	_npc_dialogue_panel.visible = false


func is_world_npc_dialogue_visible() -> bool:
	return _npc_dialogue_panel != null and _npc_dialogue_panel.visible


func show_world_actor_dialogue(title_text: String, body_text: String, hint_text: String = "按任意键关闭") -> void:
	show_world_npc_dialogue(title_text, body_text, hint_text)


func hide_world_actor_dialogue() -> void:
	hide_world_npc_dialogue()


func is_world_actor_dialogue_visible() -> bool:
	return is_world_npc_dialogue_visible()


func update_state(state) -> void:
	if state == null:
		return

	_hud.update_state(state)
	_refresh_feed(state)
	_run_sidebar.update_state(state)
	_run_sidebar.set_debug_messages(state.messages)


func _refresh_feed(state) -> void:
	if not is_instance_valid(_feed_panel) or not is_instance_valid(_feed_text):
		return
	if state == null:
		_feed_panel.visible = false
		return
	_feed_panel.visible = true
	if state.feed_messages.is_empty():
		_feed_text.text = "暂无新的获得内容。"
		_feed_text.modulate = Color(1, 1, 1, 1)
		return
	var lines: Array[String] = []
	var newest_type := "generic"
	for entry in state.feed_messages:
		if typeof(entry) == TYPE_DICTIONARY:
			lines.append("- %s" % String(entry.get("text", "")))
		else:
			lines.append("- %s" % String(entry))
	if not state.feed_messages.is_empty() and typeof(state.feed_messages[0]) == TYPE_DICTIONARY:
		newest_type = String(state.feed_messages[0].get("type", "generic"))
	_feed_text.text = "\n".join(lines)
	_feed_text.modulate = _feed_color(newest_type)


func _feed_color(message_type: String) -> Color:
	match message_type:
		"token":
			return Color(0.72, 0.96, 1.0, 1.0)
		"modifier":
			return Color(1.0, 0.9, 0.62, 1.0)
		_:
			return Color(1, 1, 1, 1)


func show_title() -> void:
	_panel.visible = false
	_hud.visible = false
	_run_sidebar.visible = false
	_rest_continue_button.visible = false
	_show_overlay("别按那个键", "Tab 键打开背包调整按键编排，进战斗后按键执行，真实结果再驱动武器连招。", [
		{"text": "开始游戏", "callback": func() -> void: start_requested.emit()},
	])


func show_battle() -> void:
	_overlay.visible = false
	_panel.visible = false
	_hud.visible = true
	_run_sidebar.visible = true
	_rest_continue_button.visible = false


func show_rest_site(title: String, body: String = "") -> void:
	_overlay.visible = false
	_panel.visible = false
	_hud.visible = true
	_run_sidebar.visible = true
	_rest_continue_button.visible = true
	if not body.is_empty():
		_run_sidebar.set_debug_messages([body])


func show_reward(rewards: Array, title_text: String = "选择奖励", body_text: String = "房间清空。选一个奖励继续前进。") -> void:
	var buttons: Array = []
	for index in range(rewards.size()):
		var reward = rewards[index]
		buttons.append({
			"title": reward["name"],
			"body": String(reward.get("description", "")),
			"callback": _emit_reward_chosen.bind(index),
		})

	_show_overlay(title_text, body_text, buttons)


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

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_buttons.add_child(left_spacer)

	for index in range(buttons.size()):
		var button_data = buttons[index]
		var button := _make_overlay_button(button_data, index)
		button.pressed.connect(button_data["callback"])
		_overlay_buttons.add_child(button)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_buttons.add_child(right_spacer)


func _make_overlay_button(button_data: Dictionary, index: int) -> Button:
	if button_data.has("title") or button_data.has("body"):
		var reward_button := UiRewardCardScene.instantiate() as Button
		reward_button.get_node("Margin/Content/Title").text = String(button_data.get("title", button_data.get("text", "")))
		reward_button.get_node("Margin/Content/Body").text = String(button_data.get("body", ""))
		if index == 0:
			reward_button.theme_type_variation = &"PrimaryButton"
		return reward_button
	var button := UiActionCardScene.instantiate() as Button
	button.text = String(button_data.get("text", ""))
	if index == 0:
		button.theme_type_variation = &"PrimaryButton"
	return button


func _on_bag_key_token_move_requested(source_slot_id: String, source_index: int, target_slot_id: String) -> void:
	key_token_move_requested.emit(source_slot_id, source_index, target_slot_id)


func _on_bag_key_slot_preview_requested(slot_id: String) -> void:
	key_slot_preview_requested.emit(slot_id)


func _on_bag_key_slot_preview_cleared(slot_id: String) -> void:
	key_slot_preview_cleared.emit(slot_id)


func _on_bag_close_requested() -> void:
	bag_toggle_requested.emit()


func _on_run_sidebar_bag_requested() -> void:
	bag_toggle_requested.emit()


func _on_run_sidebar_menu_requested() -> void:
	pause_menu_requested.emit()


func _emit_reward_chosen(index: int) -> void:
	reward_chosen.emit(index)
