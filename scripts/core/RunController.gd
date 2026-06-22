class_name RunController
extends Node

signal room_requested(floor_index: int)

var current_floor: int = 1
var player_keys: Dictionary = {
	"U": 0,
	"D": 0,
	"L": 0,
	"R": 1,
}
var relics: Array = []

func start_run() -> void:
	current_floor = 1
	player_keys = {
		"U": 0,
		"D": 0,
		"L": 0,
		"R": 1,
	}
	room_requested.emit(current_floor)

func on_battle_won() -> void:
	current_floor += 1
	room_requested.emit(current_floor)
