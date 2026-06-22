extends Node

signal gold_changed(value: int)
signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal purchase_failed(item_id: String, reason: String)
signal item_purchased(item_id: String, price: int)

var gold: int = 0
var inventory: Dictionary = {}


func _ready() -> void:
	var save_service = get_node_or_null("/root/SaveService")
	if save_service != null:
		save_service.register_provider("economy", self)


func reset_run(starting_gold: int = 0) -> void:
	gold = maxi(0, starting_gold)
	inventory.clear()
	gold_changed.emit(gold)


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)


func can_afford(price: int) -> bool:
	return gold >= maxi(0, price)


func buy_item(item_id: String, price: int, amount: int = 1) -> bool:
	if item_id.is_empty():
		purchase_failed.emit(item_id, "empty_item_id")
		return false
	if not can_afford(price):
		purchase_failed.emit(item_id, "not_enough_gold")
		return false

	add_gold(-price)
	add_item(item_id, amount)
	item_purchased.emit(item_id, price)
	return true


func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	item_added.emit(item_id, amount)


func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	var owned := int(inventory.get(item_id, 0))
	if owned < amount:
		return false

	owned -= amount
	if owned <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = owned
	item_removed.emit(item_id, amount)
	return true


func get_save_data() -> Dictionary:
	return {
		"gold": gold,
		"inventory": inventory,
	}


func load_save_data(data: Dictionary) -> void:
	gold = maxi(0, int(data.get("gold", 0)))
	inventory.clear()
	var raw_inventory = data.get("inventory", {})
	if typeof(raw_inventory) == TYPE_DICTIONARY:
		for item_id in raw_inventory.keys():
			inventory[String(item_id)] = int(raw_inventory[item_id])
	gold_changed.emit(gold)
