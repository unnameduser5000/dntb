class_name BattleHud
extends Control

@onready var _health_bar = $Panel/Margin/Content/HealthBar
@onready var _san_bar = $Panel/Margin/Content/SanBar
@onready var _room_value: Label = %RoomValue
@onready var _turn_value: Label = %TurnValue
@onready var _player_box: Label = %PlayerBox
@onready var _enemy_value: Label = %EnemyValue
@onready var _enemy_intent_list: VBoxContainer = %EnemyIntentList


func update_state(state) -> void:
	if state == null or state.player == null:
		return

	_health_bar.set_value(state.player.hp, state.player.max_hp)
	_san_bar.set_value(state.player.san, state.player.max_san)
	_san_bar.bar_theme_variant = &"VitalSanLowBar" if state.player.max_san > 0 and state.player.san * 10 <= state.player.max_san * 3 else &"VitalSanBar"
	_room_value.text = state.room_name
	_turn_value.text = "回合 %d" % state.turn_count
	_player_box.text = "玩家 %s · 朝向 %s" % [str(state.player.grid_pos), _direction_label(state.player.facing)]
	_enemy_value.text = "敌人: %d" % state.get_alive_enemies().size()
	_refresh_enemy_intents(state.enemy_intents)


func _refresh_enemy_intents(intents: Array) -> void:
	for child in _enemy_intent_list.get_children():
		child.queue_free()

	if intents.is_empty():
		var empty := Label.new()
		empty.text = "无威胁"
		empty.theme_type_variation = &"ScreenHint"
		_enemy_intent_list.add_child(empty)
		return

	for intent in intents:
		var label := Label.new()
		label.text = intent
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"BattleIntent"
		_enemy_intent_list.add_child(label)


func _direction_label(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "U"
	if direction == Vector2i.DOWN:
		return "D"
	if direction == Vector2i.LEFT:
		return "L"
	if direction == Vector2i.RIGHT:
		return "R"
	return "-"
