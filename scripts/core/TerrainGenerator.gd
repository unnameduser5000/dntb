class_name TerrainGenerator
extends RefCounted

const MapCellScript := preload("res://scripts/core/MapCell.gd")


func generate(map_data, config, rng: RandomNumberGenerator) -> void:
	if map_data == null:
		return

	var moisture_noise = _build_moisture_noise(rng, config)
	for cell in map_data.get_all_cells():
		var map_cell = map_data.get_or_create_cell(cell)
		if map_cell == null:
			continue
		map_cell.moisture_score = _score_moisture(cell, moisture_noise)
		map_cell.dryness_score = _score_dryness(cell, map_cell.moisture_score, moisture_noise)
		map_data.set_terrain(cell, _choose_terrain(map_cell, config))


func _choose_terrain(map_cell, config) -> int:
	var peak_threshold: float = float(config.peak_threshold) if config != null else 0.85
	var mountain_threshold: float = float(config.mountain_threshold) if config != null else 0.65
	var hill_threshold: float = float(config.hill_threshold) if config != null else 0.45

	if map_cell.height_score >= peak_threshold:
		return MapCellScript.TerrainType.PEAK
	if map_cell.height_score >= mountain_threshold:
		return MapCellScript.TerrainType.MOUNTAIN
	if map_cell.height_score >= hill_threshold:
		return MapCellScript.TerrainType.HILL
	if map_cell.moisture_score >= 0.72:
		return MapCellScript.TerrainType.SWAMP
	if map_cell.dryness_score >= 0.76:
		return MapCellScript.TerrainType.DESERT
	if map_cell.moisture_score >= 0.58:
		return MapCellScript.TerrainType.FOREST
	return MapCellScript.TerrainType.PLAIN


func _build_moisture_noise(rng: RandomNumberGenerator, config):
	if config == null or not bool(config.use_fast_noise_lite):
		return null
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = float(config.moisture_noise_frequency)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 2
	return noise


func _score_moisture(cell: Vector2i, moisture_noise) -> float:
	var base: float = 0.5
	var east_west_band: float = sin(float(cell.x) * 0.11) * 0.08
	var north_south_band: float = cos(float(cell.y) * 0.07) * 0.06
	var noise_value: float = moisture_noise.get_noise_2d(float(cell.x), float(cell.y)) * 0.28 if moisture_noise != null else _fallback_noise(cell) * 0.22
	return clampf(base + east_west_band + north_south_band + noise_value, 0.0, 1.0)


func _score_dryness(cell: Vector2i, moisture_score: float, moisture_noise) -> float:
	var noise_value: float = 0.0
	if moisture_noise != null:
		noise_value = moisture_noise.get_noise_2d(float(cell.x + 97), float(cell.y - 41)) * 0.08
	else:
		noise_value = cos(float(cell.x) * 0.13 - float(cell.y) * 0.05) * 0.05
	return clampf(1.0 - moisture_score + noise_value, 0.0, 1.0)


func _fallback_noise(cell: Vector2i) -> float:
	return sin(float(cell.x) * 0.09 + float(cell.y) * 0.13) * 0.5
