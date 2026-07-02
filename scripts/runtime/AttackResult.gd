class_name AttackResult
extends RefCounted

var actor
var action
var direction: Vector2i = Vector2i.ZERO
var attempted_cells: Array[Vector2i] = []
var hit_targets: Array = []
var hit_cells: Array[Vector2i] = []
var damage_packets: Array = []
var total_damage: int = 0
var missed: bool = false
var miss_cell: Vector2i = Vector2i.ZERO
var hit_handled_by_weapon: bool = false
var moved_during_attack: bool = false
var movement_packets: Array = []


func setup(new_actor, new_action, new_direction: Vector2i) -> void:
	actor = new_actor
	action = new_action
	direction = new_direction
	attempted_cells.clear()
	hit_targets.clear()
	hit_cells.clear()
	damage_packets.clear()
	total_damage = 0
	missed = false
	miss_cell = Vector2i.ZERO
	hit_handled_by_weapon = false
	moved_during_attack = false
	movement_packets.clear()


func record_attempted_cell(cell: Vector2i) -> void:
	attempted_cells.append(cell)


func record_hit(target, cell: Vector2i, damage_packets_for_hit: Array, handled_by_weapon: bool, base_damage: int) -> void:
	hit_targets.append(target)
	hit_cells.append(cell)
	for packet in damage_packets_for_hit:
		damage_packets.append(packet)
	total_damage += maxi(0, base_damage)
	if handled_by_weapon:
		hit_handled_by_weapon = true
	missed = false


func record_miss(cell: Vector2i) -> void:
	missed = true
	miss_cell = cell


func record_attack_movement(packets: Array) -> void:
	movement_packets = packets.duplicate()
	for packet in packets:
		if packet != null and bool(packet.metadata.get("moved", false)):
			moved_during_attack = true
			return
