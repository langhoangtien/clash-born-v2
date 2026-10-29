extends TestCase
## MAP-01, MAP-02: dữ liệu map đã build (tools/map_build) nạp đúng và hợp lệ.
## Chuyển từ test_map.gd của v1 (phần dữ liệu).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const SIDES: PackedStringArray = ["blue", "red"]
const LANE_NAMES: PackedStringArray = ["top", "mid", "bot"]

var map: MapLayout


func before_each() -> void:
	map = load(MAP_PATH) as MapLayout


func test_MAP_01_map_data_validates() -> void:
	assert_true(map != null, "nạp được " + MAP_PATH)
	assert_true(map.validation_errors().is_empty(), "; ".join(map.validation_errors()))


func test_MAP_02_world_size() -> void:
	assert_eq(map.world_size(), Vector2(9216, 9216))  # D-172: lớn hơn 9%


func test_MAP_02_blue_bottom_left_red_top_right() -> void:
	var size: Vector2 = map.world_size()
	assert_true(map.fountain_point(0).x < size.x * 0.2 and map.fountain_point(0).y > size.y * 0.8, "Blue dưới–trái")
	assert_true(map.fountain_point(1).x > size.x * 0.8 and map.fountain_point(1).y < size.y * 0.2, "Red trên–phải")


func test_MAP_02_eleven_towers_per_team() -> void:
	assert_eq(map.tower_points.size(), 22)
	assert_eq(map.tower_teams.count(0), 11)
	assert_eq(map.tower_teams.count(1), 11)


func test_MAP_02_every_lane_has_t1_t2_t3_ordered_toward_base() -> void:
	for team: int in range(2):
		for lane: String in LANE_NAMES:
			for tier: int in range(1, 4):
				assert_true(map.tower_index("%s_%s_t%d" % [SIDES[team], lane, tier]) >= 0, "có trụ %s %s T%d" % [SIDES[team], lane, tier])
			var t1: Vector2 = map.tower_point("%s_%s_t1" % [SIDES[team], lane])
			var t3: Vector2 = map.tower_point("%s_%s_t3" % [SIDES[team], lane])
			var home: Vector2 = map.fountain_point(team)
			assert_true(t3.distance_to(home) < t1.distance_to(home), "T3 gần nhà hơn T1: %s %s" % [SIDES[team], lane])


func test_MAP_02_core_and_fountain_inside_own_base() -> void:
	for team: int in range(2):
		assert_true(map.is_in_base(map.core_point(team), team), "nhà chính trong base %d" % team)
		assert_true(map.is_in_base(map.fountain_point(team), team), "fountain trong base %d" % team)


func test_MAP_02_tower_prerequisites() -> void:
	assert_eq(map.tower_prerequisites[map.tower_index("blue_mid_t2")], PackedStringArray(["blue_mid_t1"]))
	assert_eq(map.tower_prerequisites[map.tower_index("red_base_guard_left")].size(), 3, "T4 cần một trong ba T3")


func test_MAP_02_six_camps_per_side_no_boss() -> void:
	assert_eq(map.camp_points.size(), 12)
	assert_eq(map.camp_kinds.count("boss"), 0, "D-171: bỏ boss")
	assert_eq(Array(map.camp_sides).count(0), 6)
	assert_eq(Array(map.camp_sides).count(1), 6)


func test_MAP_02_three_distinct_lanes_from_spawn_to_enemy_spawn() -> void:
	assert_ne(map.route("TOP", 0), map.route("MID", 0))
	assert_ne(map.route("MID", 0), map.route("BOT", 0))
	for lane: String in MapLayout.LANES:
		for team: int in range(2):
			var route: PackedVector2Array = map.route(lane, team)
			assert_eq(route[0], map.lane_spawn_point(team, lane), "%s đội %d bắt đầu ở điểm sinh lính" % [lane, team])
			assert_eq(route[-1], map.lane_spawn_point(1 - team, lane), "%s đội %d kết thúc ở điểm sinh lính địch" % [lane, team])


func test_MAP_01_drawn_forest_is_blocked_in_clearance() -> void:
	assert_ne(_forest_center(), Vector2.ZERO, "có rừng vẽ ra cũng là vật cản")


func test_MAP_01_clearance_outside_map_is_zero() -> void:
	assert_eq(map.clearance_at(Vector2(-100, -100)), 0.0)
	assert_eq(map.clearance_at(Vector2(INF, 0)), 0.0)


func test_MAP_01_nearest_walkable_respects_radius() -> void:
	var point: Vector2 = map.nearest_walkable(_forest_center(), 40.0)
	assert_true(map.clearance_at(point) >= 40.0)


func test_empty_layout_reports_errors() -> void:
	assert_false(MapLayout.new().validation_errors().is_empty())


func _forest_center() -> Vector2:
	for shape: MapShape in map.forest_shapes + map.rock_shapes:  # D-171: khối đá cũng là vật cản vẽ ra
		var center: Vector2 = Vector2.ZERO
		for point: Vector2 in shape.outer:
			center += point
		center /= shape.outer.size()
		if Geometry2D.is_point_in_polygon(center, shape.outer) and map.clearance_at(center) == 0.0:
			return center
	return Vector2.ZERO


## MAP-03 (D-43): không có khe trông như lối đi mà hero không lọt.
func test_MAP_03_no_misleading_narrow_gaps() -> void:
	const VISIBLE_GAP: float = 12.0
	const HERO: float = 32.0
	const REACH_PX: int = 3  # 48 đơn vị thế giới
	var size: Vector2i = map.clearance_size
	var bad: Array[Vector2i] = []
	for y: int in range(size.y):
		for x: int in range(size.x):
			var c: float = _pixel(x, y)
			if c >= VISIBLE_GAP and c < HERO and not _standable_near(x, y, REACH_PX, HERO):
				bad.append(Vector2i(x, y))
	assert_true(bad.is_empty(), "%d điểm khe hẹp, vd %s" % [bad.size(), bad.slice(0, 5).map(func(p: Vector2i) -> Vector2: return Vector2(p) * map.clearance_pixel)])


func _pixel(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= map.clearance_size.x or y >= map.clearance_size.y:
		return 0.0
	return float(map.clearance_bytes[y * map.clearance_size.x + x]) * map.clearance_unit


func _standable_near(x: int, y: int, reach: int, need: float) -> bool:
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			if dx * dx + dy * dy <= reach * reach and _pixel(x + dx, y + dy) >= need:
				return true
	return false


## MAP-04 (D-49): map đối xứng xoay 180° quanh tâm; lane an toàn Blue (BOT) ↔ Red (TOP).
func test_MAP_04_rotational_symmetry() -> void:
	var size: Vector2 = map.world_size()
	var rot: Callable = func(p: Vector2) -> Vector2: return size - p
	assert_true(map.fountain_point(1).distance_to(rot.call(map.fountain_point(0))) < 1.0)
	assert_true(map.core_point(1).distance_to(rot.call(map.core_point(0))) < 1.0)
	var swap: Dictionary = {"top": "bot", "mid": "mid", "bot": "top"}
	for lane: String in ["top", "mid", "bot"]:
		for tier: int in [1, 2, 3]:
			var blue: Vector2 = map.tower_point("blue_%s_t%d" % [lane, tier])
			var red: Vector2 = map.tower_point("red_%s_t%d" % [swap[lane], tier])
			assert_true(red.distance_to(rot.call(blue)) < 1.0, "trụ %s T%d đối xứng" % [lane, tier])
	for i: int in range(1, 40):
		var p: Vector2 = Vector2(size.x * i / 40.0, size.y * (i * 7 % 40) / 40.0)
		# Sai số làm tròn khi vẽ polygon và gộp pixel: tối đa 2 bậc (8 đơn vị).
		assert_near(map.clearance_at(p), map.clearance_at(rot.call(p) - Vector2(0.01, 0.01)), 8.0, "địa hình đối xứng tại %s" % p)


## MAP-04: đợt lính đầu gặp nhau ngoài tầm mọi trụ 1; trụ cách rừng/vách đủ xa.
func test_MAP_04_first_meeting_point_out_of_tower_range() -> void:
	var reach: float = 550.0 + 52.0 + 22.0
	for lane: String in MapLayout.LANES:
		var route: PackedVector2Array = map.route(lane, 0)
		var meet: Vector2 = _midpoint(route)
		for i: int in range(map.tower_ids.size()):
			if map.tower_lanes[i] == lane and map.tower_tiers[i] == 1:
				assert_true(map.tower_points[i].distance_to(meet) > reach + 50.0, "%s cách điểm gặp %.0f" % [map.tower_ids[i], map.tower_points[i].distance_to(meet)])


func test_MAP_04_towers_clear_of_forest_and_cliffs() -> void:
	for i: int in range(map.tower_ids.size()):
		assert_true(map.clearance_at(map.tower_points[i]) >= 160.0, "%s chỉ cách vật cản %.0f" % [map.tower_ids[i], map.clearance_at(map.tower_points[i])])



## MAP-05 (D-50): chỗ mid cắt sông không còn vách lồi; quanh tâm map trống.
func test_MAP_05_mid_river_crossing_is_open() -> void:
	var c: Vector2 = map.world_size() * 0.5
	for x: int in range(-3, 4):
		for y: int in range(-3, 4):
			var p: Vector2 = c + Vector2(x, y) * 100.0
			if p.distance_to(c) <= 300.0:
				assert_true(map.clearance_at(p) >= 120.0, "giữa sông bị chắn tại %s (%.0f)" % [p, map.clearance_at(p)])

func _midpoint(route: PackedVector2Array) -> Vector2:
	var total: float = 0.0
	for i: int in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	var half: float = total * 0.5
	for i: int in range(1, route.size()):
		var seg: float = route[i - 1].distance_to(route[i])
		if half <= seg:
			return route[i - 1].lerp(route[i], half / seg)
		half -= seg
	return route[-1]


## Khoảng cách từ điểm tới đường gấp khúc.
func _to_line(p: Vector2, line: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in line.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


func test_MAP_06_lane_towers_beside_lane_edge_same_offset() -> void:
	var m: MapLayout = map
	for i: int in m.tower_ids.size():
		if m.tower_lanes[i] == "BASE":
			continue
		var d: float = _to_line(m.tower_points[i], m.lanes[m.tower_lanes[i]])
		assert_near(d, 192.0, 4.0, "trụ %s cách tim lane 192" % m.tower_ids[i])


func _water_distance(m: MapLayout, p: Vector2) -> float:
	var best: float = INF
	for shape: MapShape in m.water_shapes:
		if Geometry2D.is_point_in_polygon(p, shape.outer):
			return 0.0
		best = minf(best, _to_line(p, shape.outer + PackedVector2Array([shape.outer[0]])))
	return best


func test_MAP_07_river_edge_is_rock_with_few_openings() -> void:
	var m: MapLayout = map
	var open_spots: Array[Vector2] = []
	var samples: int = 0
	var blocked: int = 0
	for shape: MapShape in m.water_shapes:
		var ring: PackedVector2Array = shape.outer + PackedVector2Array([shape.outer[0]])
		for i: int in shape.outer.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[i + 1]
			var steps: int = int(a.distance_to(b) / 80.0)
			for k: int in steps:
				var p: Vector2 = a.lerp(b, (k + 0.5) / steps)
				var out: Vector2 = p + (b - a).normalized().orthogonal() * 90.0
				if _water_distance(m, out) < 40.0:
					out = p - (b - a).normalized().orthogonal() * 90.0
				if _near_lane(m, out, 600.0) or out.distance_to(m.world_size() * 0.5) < 700.0:
					continue
				samples += 1
				if m.clearance_at(out) < 32.0:
					blocked += 1
				elif open_spots.all(func(q: Vector2) -> bool: return q.distance_to(out) > 400.0):
					open_spots.append(out)
	assert_true(blocked > samples * 0.6, "bờ sông phần lớn là khối đá (%d/%d)" % [blocked, samples])
	var blue: int = open_spots.filter(func(q: Vector2) -> bool: return q.y > q.x).size()
	assert_true(blue >= 2 and open_spots.size() - blue >= 2, "mỗi nửa có lối xuống sông (%d / %d)" % [blue, open_spots.size() - blue])


func test_MAP_08_every_camp_sits_in_rock_or_forest_hook() -> void:
	var m: MapLayout = map
	for i: int in m.camp_ids.size():
		var wall: int = 0
		for k: int in 24:
			var probe: Vector2 = m.camp_points[i] + Vector2.from_angle(TAU * k / 24.0) * 330.0
			wall += 1 if m.clearance_at(probe) < 32.0 else 0
		assert_true(wall >= 10 and wall < 24, "trại %s nằm trong hốc đá / rừng có cửa (%d/24 hướng chặn)" % [m.camp_ids[i], wall])


func _near_lane(m: MapLayout, p: Vector2, reach: float) -> bool:
	for lane: String in MapLayout.LANES:
		if _to_line(p, m.lanes[lane]) < reach:
			return true
	return false


func _near_tower(m: MapLayout, p: Vector2, reach: float) -> bool:
	for t: Vector2 in m.tower_points:
		if t.distance_to(p) < reach:
			return true
	return false


func test_MAP_09_base_fence_open_only_at_lanes() -> void:
	var m: MapLayout = map
	for team: int in 2:
		var poly: PackedVector2Array = Geometry2D.offset_polygon(m.base_polygons[team], -32.0)[0]
		for k: int in poly.size():
			var a: Vector2 = poly[k]
			var b: Vector2 = poly[(k + 1) % poly.size()]
			for t: float in [0.25, 0.5, 0.75]:
				var p: Vector2 = a.lerp(b, t)
				if not m.world_rect().grow(-80.0).has_point(p) or _near_lane(m, p, m.lane_width * 0.5 + 40.0) or _near_tower(m, p, 220.0):
					continue  # cổng = chỗ lane đi qua (kể cả khoảng trống quanh trụ cạnh cổng, MAP-04)
				assert_true(m.clearance_at(p) < 32.0, "rào base đội %d chặn ở %s" % [team, p])


func test_MAP_10_fountain_fence_has_one_gate_toward_core() -> void:
	var m: MapLayout = map
	for team: int in 2:
		var f: Vector2 = m.fountain_point(team)
		var toward: float = (m.core_point(team) - f).angle()
		var open: int = 0
		for k: int in 72:
			var a: float = TAU * k / 72.0
			var p: Vector2 = f + Vector2.from_angle(a) * 600.0
			if not m.world_rect().grow(-80.0).has_point(p):
				continue
			var gate: bool = absf(angle_difference(a, toward)) < deg_to_rad(20.0)
			if gate:
				assert_true(m.clearance_at(p) >= 32.0, "cổng fountain đội %d đi được" % team)
				open += 1
			elif absf(angle_difference(a, toward)) > deg_to_rad(40.0):
				assert_true(m.clearance_at(p) < 32.0, "rào fountain đội %d chặn ở góc %d°" % [team, rad_to_deg(a)])
		assert_true(open > 0, "có cổng")
