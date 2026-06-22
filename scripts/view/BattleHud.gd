class_name BattleHud
extends Control

@onready var _health_bar: UiVitalBar = $Panel/Margin/Content/HealthBar
@onready var _san_bar: UiVitalBar = $Panel/Margin/Content/SanBar
@onready var _room_value: Label = %RoomValue
@onready var _turn_value: Label = %TurnValue


func update_state(state) -> void:
	if state == null or state.player == null:
		return

	_health_bar.set_value(state.player.hp, state.player.max_hp)
	_san_bar.set_value(state.player.san, state.player.max_san)
	_san_bar.bar_theme_variant = &"VitalSanLowBar" if state.player.max_san > 0 and state.player.san * 10 <= state.player.max_san * 3 else &"VitalSanBar"
	_room_value.text = state.room_name
	_turn_value.text = "回合 %d" % state.turn_count
