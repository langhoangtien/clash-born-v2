extends TestCase
## MAP-07, MAP-11 (D-176): bờ sông là đá, rừng giữa map là rừng cây thưa có lối rộng và khe.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
## Vùng rừng để đo: cách mép map JUNGLE_INSET, cách tim lane quá nửa lane + LANE_MARGIN, ngoài base.
const JUNGLE_INSET: float = 1100.0
const LANE_MARGIN: float = 250.0
## Bước lấy mẫu (điểm ảnh khoảng trống).
const STEP: int = 2
## MAP-11: vật cản ≤ 25% vùng rừng; bề rộng lối (gấp đôi khoảng trống ở sống lối) trung vị ≥ 450,
## lối hẹp hơn 300 ≤ 10%; khối rừng giữa map > 360 000 đơn vị² phải có khe, trừ khối ôm trại.
const MAX_BLOCKED: float = 0.25
const MIN_MEDIAN_WIDTH: float = 450.0
const NARROW_WIDTH: float = 300.0
const MAX_NARROW: float = 0.10
const GAP_AREA: float = 360000.0
const HOOK_REACH: float = 400.0
const EDGE: float = 96.0
## Đá cách nước dưới chừng này là đá bờ sông.
const BANK_REACH: float = 250.0

var map: MapLayout


func before_each() -> void:
	map = load(MAP_PATH) as MapLayout


func test_MAP_07_river_bank_obstacles_are_rock() -> void:
	var rock: int = 0
	var blocked: int = 0
	for shape: MapShape in map.water_shapes:
		var ring: PackedVector2Array = shape.outer + PackedVector2Array([shape.outer[0]])
		for i: int in shape.outer.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[i + 1]
			for side: float in [1.0, -1.0]:
				var probe: Vector2 = a.lerp(b, 0.5) + (b - a).normalized().orthogonal() * 60.0 * side
				if map.clearance_at(probe) > 0.0 or Geometry2D.is_point_in_polygon(probe, shape.outer):
					continue
				blocked += 1
				rock += 1 if _in_shapes(map.rock_shapes, probe) else 0
	assert_true(blocked > 0, "có vật cản sát bờ sông")
	assert_true(rock >= blocked * 0.9, "vật cản sát bờ sông là đá (%d/%d)" % [rock, blocked])


func test_MAP_11_jungle_obstacles_at_most_25_percent() -> void:
	var blocked: int = 0
	var total: int = 0
	for p: Vector2 in _jungle_points():
		total += 1
		blocked += 1 if map.clearance_at(p) <= 0.0 else 0
	assert_true(total > 1000, "vùng rừng đủ mẫu (%d)" % total)
	assert_true(blocked <= total * MAX_BLOCKED, "vật cản %.1f%% vùng rừng" % (100.0 * blocked / total))


func test_MAP_11_jungle_obstacles_are_forest() -> void:
	var blocked: int = 0
	var forest: int = 0
	for p: Vector2 in _jungle_points():
		if map.clearance_at(p) > 0.0 or (_in_shapes(map.rock_shapes, p) and _water_distance(p) < BANK_REACH):
			continue  # trống / đá ven sông (MAP-07)
		blocked += 1
		forest += 1 if _in_shapes(map.forest_shapes, p) else 0
	# 0,8: khoảng trống lấy min theo từng ô guide nên điểm ảnh sát mép khối bị tính chặn mà nằm ngoài polygon
	assert_true(forest >= blocked * 0.8, "vật cản trong rừng (ngoài bờ sông) là rừng cây (%d/%d)" % [forest, blocked])


func test_MAP_11_jungle_paths_wide() -> void:
	var widths: PackedFloat32Array = PackedFloat32Array()
	for p: Vector2 in _jungle_points():
		var c: float = map.clearance_at(p)
		if c > 0.0 and _is_ridge(p, c):
			widths.append(c * 2.0)
	widths.sort()
	assert_true(widths.size() > 100, "đủ mẫu sống lối (%d)" % widths.size())
	var narrow: int = 0
	for w: float in widths:
		narrow += 1 if w < NARROW_WIDTH else 0
	var median: float = widths[widths.size() / 2]
	assert_true(median >= MIN_MEDIAN_WIDTH, "lối rừng rộng trung vị %.0f" % median)
	assert_true(narrow <= widths.size() * MAX_NARROW, "lối hẹp hơn %.0f: %d/%d" % [NARROW_WIDTH, narrow, widths.size()])


func test_MAP_11_big_forest_blocks_have_gaps() -> void:
	var rect: Rect2 = map.world_rect().grow(-EDGE)
	for shape: MapShape in map.forest_shapes:
		var box: Rect2 = Rect2(shape.outer[0], Vector2.ZERO)
		for q: Vector2 in shape.outer:
			box = box.expand(q)
		if not rect.encloses(box) or _near_camp(shape.outer):
			continue  # rìa map / khối ôm trại (MAP-08)
		var area: float = absf(_area(shape.outer))
		assert_true(area <= GAP_AREA, "khối rừng quanh %s rộng %.0f phải có khe" % [box.get_center(), area])


## Điểm lấy mẫu trong vùng rừng (giữa map, ngoài lane, ngoài base).
func _jungle_points() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var rect: Rect2 = map.world_rect().grow(-JUNGLE_INSET)
	var px: float = map.clearance_pixel
	for y: int in range(0, map.clearance_size.y, STEP):
		for x: int in range(0, map.clearance_size.x, STEP):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5) * px
			if rect.has_point(p) and not _near_lane(p) and not map.is_in_base(p, 0) and not map.is_in_base(p, 1):
				out.append(p)
	return out


## Sống lối: khoảng trống lớn nhất trong ô 5 × 5 điểm ảnh quanh `p`.
func _is_ridge(p: Vector2, c: float) -> bool:
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if map.clearance_at(p + Vector2(dx, dy) * map.clearance_pixel) > c:
				return false
	return true


func _near_lane(p: Vector2) -> bool:
	for lane: String in MapLayout.LANES:
		var line: PackedVector2Array = map.lanes[lane]
		for i: int in line.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])) < map.lane_width * 0.5 + LANE_MARGIN:
				return true
	return false


func _near_camp(poly: PackedVector2Array) -> bool:
	for c: Vector2 in map.camp_points:
		for q: Vector2 in poly:
			if q.distance_to(c) < HOOK_REACH:
				return true
	return false


func _water_distance(p: Vector2) -> float:
	var best: float = INF
	for shape: MapShape in map.water_shapes:
		if Geometry2D.is_point_in_polygon(p, shape.outer):
			return 0.0
		for i: int in shape.outer.size():
			var a: Vector2 = shape.outer[i]
			var b: Vector2 = shape.outer[(i + 1) % shape.outer.size()]
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


func _in_shapes(shapes: Array[MapShape], p: Vector2) -> bool:
	for shape: MapShape in shapes:
		if Geometry2D.is_point_in_polygon(p, shape.outer):
			return true
	return false


func _area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	for i: int in poly.size():
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return s * 0.5
