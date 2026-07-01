class_name EffectEvent
extends RefCounted

const TYPE_DAMAGE_DEALT := &"damage_dealt"
const TYPE_ATTACK_HIT_CONFIRMED := &"attack_hit_confirmed"
const TYPE_ATTACK_MISSED_CONFIRMED := &"attack_missed_confirmed"
const TYPE_ACTOR_KILLED := &"actor_killed"
const TYPE_ACTOR_MOVED := &"actor_moved"
const TYPE_MOVE_BLOCKED := &"move_blocked"
const TYPE_KNOCKBACK_APPLIED := &"knockback_applied"
const TYPE_PULL_APPLIED := &"pull_applied"
const TYPE_SWAP_APPLIED := &"swap_applied"
const TYPE_TELEPORT_APPLIED := &"teleport_applied"
const TYPE_COMBO_TRIGGERED := &"combo_triggered"

var event_type: StringName = &""
var source
var target
var actor
var packet
var action
var from_cell: Vector2i = Vector2i.ZERO
var to_cell: Vector2i = Vector2i.ZERO
var direction: Vector2i = Vector2i.ZERO
var amount: int = 0
var depth: int = 0
var tags: Array[StringName] = []
var metadata: Dictionary = {}


func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func inherit_packet_tags(source_packet) -> void:
	if source_packet == null:
		return
	for tag in source_packet.tags:
		add_tag(tag)
