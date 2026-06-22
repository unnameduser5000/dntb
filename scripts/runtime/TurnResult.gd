class_name TurnResult
extends RefCounted

var messages: Array[String] = []
var battle_finished: bool = false
var victory: bool = false

func add_message(message: String) -> void:
	messages.append(message)
