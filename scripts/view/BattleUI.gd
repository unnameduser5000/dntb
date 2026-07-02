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
const BagUIScript = preload("res://scripts/view/BagUI.gd")

@onready var _panel: PanelContainer = %BattlePanel
@onready var _overlay: Control = %Overlay
@onready var _hud: Control = %BattleHud
@onready var _run_sidebar: Control = %RunSidebar
@onready var _rest_continue_button: Button = %RestContinueButton
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_body: Label = %OverlayBody
@onready var _overlay_buttons: VBoxContainer = %OverlayButtons
@onready var _bag_ui = %BagUI

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


func update_state(state) -> void:
	if state == null:
		return

	_hud.update_state(state)
	_run_sidebar.update_state(state)
	_run_sidebar.set_debug_messages(state.messages)


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
