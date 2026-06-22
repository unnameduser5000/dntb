class_name RunSidebar
extends Control

@onready var _panel: PanelContainer = %DrawerPanel
@onready var _toggle_button: Button = %DrawerToggle
@onready var _status_button: Button = %StatusTab
@onready var _inventory_button: Button = %InventoryTab
@onready var _tabs: TabContainer = %DrawerTabs
@onready var _status_text: Label = %StatusText
@onready var _inventory_list: VBoxContainer = %InventoryList

var _expanded := false
var _action_count := 0
var _inventory_items: Array = []


func _ready() -> void:
	_toggle_button.pressed.connect(toggle)
	_status_button.pressed.connect(show_status)
	_inventory_button.pressed.connect(show_inventory)
	_set_expanded(false)
	_refresh_status()
	_refresh_inventory()


func toggle() -> void:
	_set_expanded(not _expanded)


func show_status() -> void:
	_set_expanded(true)
	_tabs.current_tab = 0


func show_inventory() -> void:
	_set_expanded(true)
	_tabs.current_tab = 1


func set_action_count(count: int) -> void:
	_action_count = maxi(0, count)
	_refresh_status()


func set_inventory_items(items: Array) -> void:
	_inventory_items = items.duplicate()
	_refresh_inventory()


func update_state(state) -> void:
	if state == null or state.player == null:
		return
	_status_text.text = "生命：%d / %d\nSAN：%d / %d\n行动库：%d 张\n房间：%s" % [
		state.player.hp,
		state.player.max_hp,
		state.player.san,
		state.player.max_san,
		_action_count,
		state.room_name,
	]


func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_panel.visible = expanded
	_toggle_button.text = "‹" if expanded else "›"
	_toggle_button.tooltip_text = "收起侧栏" if expanded else "展开状态与背包"


func _refresh_status() -> void:
	if not is_instance_valid(_status_text):
		return
	_status_text.text = "行动库：%d 张\n进入战斗后显示本房间状态。" % _action_count


func _refresh_inventory() -> void:
	if not is_instance_valid(_inventory_list):
		return

	for child in _inventory_list.get_children():
		child.queue_free()

	if _inventory_items.is_empty():
		var empty := Label.new()
		empty.text = "暂未获得物品。\n这里将显示遗物、装备与消耗品。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.theme_type_variation = &"ScreenHint"
		_inventory_list.add_child(empty)
		return

	for item in _inventory_items:
		var label := Label.new()
		label.text = "• %s" % String(item)
		label.theme_type_variation = &"BattleMessage"
		_inventory_list.add_child(label)
