extends SceneTree

const WorldGeneratorScript := preload("res://scripts/core/WorldGenerator.gd")
const MapGenConfigScript := preload("res://scripts/core/MapGenConfig.gd")

const SIZE_PRESETS := [
	Vector2i(128, 128),
	Vector2i(256, 256),
]

const SAMPLE_SEEDS := [
	"world_slice_demo",
	"route_probe_a",
	"route_probe_b",
	"route_probe_c",
	"route_probe_d",
]


func _init() -> void:
	var generator = WorldGeneratorScript.new()
	for map_size in SIZE_PRESETS:
		print("=== size=%s ===" % str(map_size))
		var total_sum: float = 0.0
		var poi_sum: float = 0.0
		var connectivity_sum: float = 0.0
		for seed in SAMPLE_SEEDS:
			var cfg = MapGenConfigScript.new()
			cfg.map_size = map_size
			var map_data = generator.generate_world("%s_%dx%d" % [seed, map_size.x, map_size.y], cfg)
			total_sum += float(map_data.generation_total_ms)
			poi_sum += float(map_data.generation_breakdown_ms.get("poi_placement_ms", 0.0))
			connectivity_sum += float(map_data.generation_breakdown_ms.get("connectivity_ms", 0.0))
			var building_counts: Dictionary = map_data.get_building_count_by_type()
			var challenge_present: bool = int(building_counts.get("challenge_entrance", 0)) > 0
			print("%s | total=%.2fms poi=%.2fms connectivity=%.2fms stamp=%d/%d challenge=%s tavern=%d challenge_count=%d ruin=%d unreachable_poi=%d failures=%s" % [
				String(map_data.seed),
				float(map_data.generation_total_ms),
				float(map_data.generation_breakdown_ms.get("poi_placement_ms", 0.0)),
				float(map_data.generation_breakdown_ms.get("connectivity_ms", 0.0)),
				int(map_data.stamp_success_count),
				int(map_data.stamp_failure_count),
				"yes" if challenge_present else "no",
				int(building_counts.get("tavern", 0)),
				int(building_counts.get("challenge_entrance", 0)),
				int(building_counts.get("ruin", 0)),
				int(map_data.unreachable_poi_count),
				_failure_summary_text(map_data.get_building_failure_summary()),
			])
		print("avg size=%s total=%.2fms poi=%.2fms connectivity=%.2fms" % [
			str(map_size),
			total_sum / float(SAMPLE_SEEDS.size()),
			poi_sum / float(SAMPLE_SEEDS.size()),
			connectivity_sum / float(SAMPLE_SEEDS.size()),
		])
		print("")
	quit()


func _failure_summary_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "none"
	var parts: Array[String] = []
	for poi_type in summary.keys():
		var bucket: Dictionary = summary.get(poi_type, {})
		var reasons: Dictionary = bucket.get("reasons", {})
		var top_reason: String = ""
		var top_count: int = -1
		for reason in reasons.keys():
			var count: int = int(reasons.get(reason, 0))
			if count > top_count:
				top_reason = String(reason)
				top_count = count
		parts.append("%s:%s=%d" % [String(poi_type), top_reason, top_count])
	return ", ".join(parts)
