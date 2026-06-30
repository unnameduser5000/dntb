class_name MountainGenerator
extends RefCounted


enum RidgeDirection {
	NW_TO_SE,
	SW_TO_NE,
	W_TO_E,
	N_TO_S,
}


func generate(map_data, config, rng: RandomNumberGenerator) -> Array:
	var ridges: Array = []
	if map_data == null:
		return ridges

	var size: Vector2i = map_data.get_size()
	if size.x <= 0 or size.y <= 0:
		return ridges

	var primary_direction: int = _pick_primary_direction(rng)
	var primary_ridge: Array[Vector2i] = _build_primary_ridge(size, primary_direction, config, rng)
	if not primary_ridge.is_empty():
		ridges.append(primary_ridge)

	var branch_min: int = int(config.ridge_branch_min) if config != null else 0
	var branch_max: int = int(config.ridge_branch_max) if config != null else 2
	var branch_count: int = rng.randi_range(branch_min, maxi(branch_min, branch_max))
	for _index in range(branch_count):
		var branch: Array[Vector2i] = _build_branch_ridge(primary_ridge, size, primary_direction, config, rng)
		if not branch.is_empty():
			ridges.append(branch)

	var height_noise = _build_height_noise(rng, config)
	var ridge_points: Array[Vector2i] = _flatten_ridge_points(ridges)
	var sample_step: int = _pick_height_sample_step(size, config)
	var sampled_height_field: Array = _build_sampled_height_field(size, ridge_points, config, height_noise, sample_step)
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x, y)
			var map_cell = map_data.get_or_create_cell(cell)
			if map_cell == null:
				continue
			map_cell.height_score = _sample_height_field(sampled_height_field, cell, size, sample_step)

	return ridges


func _pick_primary_direction(rng: RandomNumberGenerator) -> int:
	var options: Array = [
		RidgeDirection.NW_TO_SE,
		RidgeDirection.SW_TO_NE,
		RidgeDirection.W_TO_E,
		RidgeDirection.N_TO_S,
	]
	return options[rng.randi_range(0, options.size() - 1)]


func _build_primary_ridge(size: Vector2i, direction: int, config, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var control_points: Array = [
		_pick_edge_point(size, direction, false, config, rng),
		_pick_mid_point(size, direction, 0.33, config, rng),
		_pick_mid_point(size, direction, 0.66, config, rng),
		_pick_edge_point(size, direction, true, config, rng),
	]
	return _build_polyline(control_points, size)


func _build_branch_ridge(primary_ridge: Array[Vector2i], size: Vector2i, direction: int, config, rng: RandomNumberGenerator) -> Array[Vector2i]:
	if primary_ridge.is_empty():
		return []

	var start_index_min: int = int(primary_ridge.size() * 0.2)
	var start_index_max: int = maxi(start_index_min, int(primary_ridge.size() * 0.8))
	var anchor: Vector2i = primary_ridge[rng.randi_range(start_index_min, start_index_max)]
	var branch_target: Vector2i = _pick_branch_target(anchor, size, direction, config, rng)
	var mid: Vector2i = _clamp_cell(Vector2i(
		int(round(lerpf(float(anchor.x), float(branch_target.x), 0.45))) + rng.randi_range(-2, 2),
		int(round(lerpf(float(anchor.y), float(branch_target.y), 0.45))) + rng.randi_range(-2, 2)
	), size)

	return _build_polyline([anchor, mid, branch_target], size)


func _pick_edge_point(size: Vector2i, direction: int, at_end: bool, config, rng: RandomNumberGenerator) -> Vector2i:
	var margin: int = int(config.ridge_edge_margin) if config != null else 2
	var max_x: int = maxi(0, size.x - 1)
	var max_y: int = maxi(0, size.y - 1)
	var span_x_min: int = margin
	var span_x_max: int = maxi(margin, max_x - margin)
	var span_y_min: int = margin
	var span_y_max: int = maxi(margin, max_y - margin)

	match direction:
		RidgeDirection.W_TO_E:
			return Vector2i(0 if not at_end else max_x, rng.randi_range(span_y_min, span_y_max))
		RidgeDirection.N_TO_S:
			return Vector2i(rng.randi_range(span_x_min, span_x_max), 0 if not at_end else max_y)
		RidgeDirection.SW_TO_NE:
			return Vector2i(0 if not at_end else max_x, max_y if not at_end else 0)
		_:
			return Vector2i(0 if not at_end else max_x, 0 if not at_end else max_y)


func _pick_mid_point(size: Vector2i, direction: int, ratio: float, config, rng: RandomNumberGenerator) -> Vector2i:
	var jitter: int = int(config.ridge_control_point_jitter) if config != null else 5
	var width: int = maxi(1, size.x - 1)
	var height: int = maxi(1, size.y - 1)

	match direction:
		RidgeDirection.W_TO_E:
			return _clamp_cell(Vector2i(
				int(round(width * ratio)),
				int(round(height * 0.5)) + rng.randi_range(-jitter, jitter)
			), size)
		RidgeDirection.N_TO_S:
			return _clamp_cell(Vector2i(
				int(round(width * 0.5)) + rng.randi_range(-jitter, jitter),
				int(round(height * ratio))
			), size)
		RidgeDirection.SW_TO_NE:
			return _clamp_cell(Vector2i(
				int(round(width * ratio)) + rng.randi_range(-2, 2),
				int(round(height * (1.0 - ratio))) + rng.randi_range(-jitter, jitter)
			), size)
		_:
			return _clamp_cell(Vector2i(
				int(round(width * ratio)) + rng.randi_range(-2, 2),
				int(round(height * ratio)) + rng.randi_range(-jitter, jitter)
			), size)


func _pick_branch_target(anchor: Vector2i, size: Vector2i, direction: int, config, rng: RandomNumberGenerator) -> Vector2i:
	var margin: int = int(config.ridge_edge_margin) if config != null else 2
	var max_x: int = maxi(0, size.x - 1)
	var max_y: int = maxi(0, size.y - 1)

	match direction:
		RidgeDirection.W_TO_E:
			return Vector2i(
				clampi(anchor.x + rng.randi_range(-6, 6), margin, max(max_x - margin, margin)),
				0 if rng.randf() < 0.5 else max_y
			)
		RidgeDirection.N_TO_S:
			return Vector2i(
				0 if rng.randf() < 0.5 else max_x,
				clampi(anchor.y + rng.randi_range(-6, 6), margin, max(max_y - margin, margin))
			)
		RidgeDirection.SW_TO_NE:
			return Vector2i(
				max_x if rng.randf() < 0.5 else 0,
				clampi(anchor.y + rng.randi_range(-6, 6), margin, max(max_y - margin, margin))
			)
		_:
			return Vector2i(
				0 if rng.randf() < 0.5 else max_x,
				clampi(anchor.y + rng.randi_range(-6, 6), margin, max(max_y - margin, margin))
			)


func _build_polyline(control_points: Array, size: Vector2i) -> Array[Vector2i]:
	var ridge: Array[Vector2i] = []
	for index in range(control_points.size() - 1):
		for cell in _bresenham_line(control_points[index], control_points[index + 1]):
			var clamped: Vector2i = _clamp_cell(cell, size)
			if ridge.is_empty() or ridge[ridge.size() - 1] != clamped:
				ridge.append(clamped)
	return ridge


func _score_height_from_points(cell: Vector2i, ridge_points: Array[Vector2i], config, height_noise) -> float:
	var min_distance_sq: int = 2147483647
	for ridge_cell in ridge_points:
		var dx: int = cell.x - ridge_cell.x
		var dy: int = cell.y - ridge_cell.y
		var distance_sq: int = dx * dx + dy * dy
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
	var min_distance: float = sqrt(float(min_distance_sq)) if min_distance_sq != 2147483647 else 9999.0
	var ridge_width: float = maxf(1.0, float(config.ridge_width)) if config != null else 6.0
	var ridge_score: float = clampf(1.0 - min_distance / ridge_width, 0.0, 1.0)
	var noise_strength: float = float(config.noise_strength) if config != null else 0.2
	var noise_value: float = 0.0
	if height_noise != null:
		noise_value = height_noise.get_noise_2d(float(cell.x), float(cell.y)) * noise_strength
	else:
		noise_value = _fallback_noise(cell) * noise_strength
	return clampf(ridge_score + noise_value, 0.0, 1.0)


func _flatten_ridge_points(ridges: Array) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var seen: Dictionary = {}
	for ridge in ridges:
		for ridge_cell in ridge:
			var cell := Vector2i(ridge_cell)
			if seen.has(cell):
				continue
			seen[cell] = true
			points.append(cell)
	return points


func _pick_height_sample_step(size: Vector2i, config) -> int:
	if config != null:
		var configured_step: int = int(config.mountain_height_sample_step)
		if configured_step > 0:
			return configured_step
	var long_side: int = maxi(size.x, size.y)
	if long_side >= 1024:
		return 8
	if long_side >= 512:
		return 4
	if long_side >= 256:
		return 2
	return 1


func _build_sampled_height_field(size: Vector2i, ridge_points: Array[Vector2i], config, height_noise, sample_step: int) -> Array:
	var step: int = maxi(1, sample_step)
	var sample_width: int = int(ceil(float(maxi(0, size.x - 1)) / float(step))) + 1
	var sample_height: int = int(ceil(float(maxi(0, size.y - 1)) / float(step))) + 1
	var rows: Array = []
	rows.resize(sample_height)
	for sample_y in range(sample_height):
		var row := PackedFloat32Array()
		row.resize(sample_width)
		var world_y: int = mini(size.y - 1, sample_y * step)
		for sample_x in range(sample_width):
			var world_x: int = mini(size.x - 1, sample_x * step)
			row[sample_x] = _score_height_from_points(Vector2i(world_x, world_y), ridge_points, config, height_noise)
		rows[sample_y] = row
	return rows


func _sample_height_field(sampled_height_field: Array, cell: Vector2i, size: Vector2i, sample_step: int) -> float:
	var step: int = maxi(1, sample_step)
	if step == 1:
		var direct_rows: PackedFloat32Array = sampled_height_field[cell.y]
		return direct_rows[cell.x]
	var max_sample_x: int = int(sampled_height_field[0].size()) - 1
	var max_sample_y: int = sampled_height_field.size() - 1
	var sample_x0: int = clampi(int(floor(float(cell.x) / float(step))), 0, max_sample_x)
	var sample_y0: int = clampi(int(floor(float(cell.y) / float(step))), 0, max_sample_y)
	var sample_x1: int = mini(sample_x0 + 1, max_sample_x)
	var sample_y1: int = mini(sample_y0 + 1, max_sample_y)
	var world_x0: int = sample_x0 * step
	var world_y0: int = sample_y0 * step
	var world_x1: int = mini(size.x - 1, sample_x1 * step)
	var world_y1: int = mini(size.y - 1, sample_y1 * step)
	var tx: float = 0.0 if world_x1 == world_x0 else float(cell.x - world_x0) / float(world_x1 - world_x0)
	var ty: float = 0.0 if world_y1 == world_y0 else float(cell.y - world_y0) / float(world_y1 - world_y0)
	var row0: PackedFloat32Array = sampled_height_field[sample_y0]
	var row1: PackedFloat32Array = sampled_height_field[sample_y1]
	var top: float = lerpf(row0[sample_x0], row0[sample_x1], tx)
	var bottom: float = lerpf(row1[sample_x0], row1[sample_x1], tx)
	return clampf(lerpf(top, bottom, ty), 0.0, 1.0)


func _build_height_noise(rng: RandomNumberGenerator, config):
	if config == null or not bool(config.use_fast_noise_lite):
		return null
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = float(config.height_noise_frequency)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 3
	return noise


func _fallback_noise(cell: Vector2i) -> float:
	return sin(float(cell.x) * 0.17 + float(cell.y) * 0.09) * 0.5


func _clamp_cell(cell: Vector2i, size: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, max(0, size.x - 1)),
		clampi(cell.y, 0, max(0, size.y - 1))
	)


func _bresenham_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x0: int = from_cell.x
	var y0: int = from_cell.y
	var x1: int = to_cell.x
	var y1: int = to_cell.y
	var dx: int = absi(x1 - x0)
	var dy: int = absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy

	while true:
		points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var err2: int = err * 2
		if err2 > -dy:
			err -= dy
			x0 += sx
		if err2 < dx:
			err += dx
			y0 += sy

	return points
