class_name TokenDropTable
extends RefCounted

const ActionProgramControllerScript := preload("res://scripts/core/ActionProgramController.gd")

const TOKEN_TIERS := {
	"U": 1,
	"D": 1,
	"L": 1,
	"R": 1,
	"F": 1,
	"B": 1,
	"SL": 1,
	"SR": 1,
	"TL": 1,
	"TR": 1,
	"A": 1,
	"I": 1,
	"G": 1,
	"W": 1,
	"J": 1,
	"DS": 2,
	"HK": 2,
	"SB": 2,
	"PI": 2,
	"BW": 2,
	"TH": 2,
	"HM": 3,
	"RA": 3,
	"SW": 3,
	"CA": 3,
}


static func token_tier(token_id: String) -> int:
	return maxi(1, int(TOKEN_TIERS.get(token_id, 1)))


static func pick_drop_key(monster_tier: int, rng_service = null) -> String:
	var pool: Array[String] = ActionProgramControllerScript.TOKEN_DROP_POOL
	if pool.is_empty():
		return ""
	var normalized_monster_tier := clampi(monster_tier, 1, 3)
	var weighted_pool: Array[String] = []
	for token_id in pool:
		var weight: int = _drop_weight_for_tiers(normalized_monster_tier, token_tier(String(token_id)))
		for _index in range(maxi(0, weight)):
			weighted_pool.append(String(token_id))
	if weighted_pool.is_empty():
		return String(pool[0])
	if rng_service != null and rng_service.has_method("randi_range_value"):
		return String(weighted_pool[int(rng_service.randi_range_value(0, weighted_pool.size() - 1))])
	return String(weighted_pool[randi_range(0, weighted_pool.size() - 1)])


static func _drop_weight_for_tiers(monster_tier: int, item_tier: int) -> int:
	var normalized_monster_tier := clampi(monster_tier, 1, 3)
	var normalized_item_tier := clampi(item_tier, 1, 3)
	var weight_matrix := {
		1: {1: 18, 2: 5, 3: 1},
		2: {1: 9, 2: 16, 3: 5},
		3: {1: 2, 2: 12, 3: 24},
	}
	return int(weight_matrix.get(normalized_monster_tier, {}).get(normalized_item_tier, 1))
