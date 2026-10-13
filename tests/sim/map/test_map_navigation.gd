extends TestCase
## MAP-01: tìm đường theo bán kính, không xuyên vật cản. Chuyển từ test_map.gd v1.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
## Bán kính thân trụ dùng trong test (giá trị thật sẽ nằm trong content ở M2).
const TOWER_BODY: float = 52.0
const HERO_RADIUS: float = 32.0

static var _map: MapLayout
static var _nav: MapNavigation


func before_each() -> void:
	# Dựng lưới tìm đường tốn ~1 s; dùng chung cho cả file.
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_nav = MapNavigation.new(_map, HERO_RADIUS, TOWER_BODY)


func test_MAP_01_every_lane_navigable_both_teams() -> void:
	for lane: String in MapLayout.LANES:
		for team: int in range(2):
			var route: PackedVector2Array = _map.route(lane, team)
			var path: PackedVector2Array = _nav.lane_path(route[0], lane, team)
			assert_false(path.is_empty(), "%s đội %d đi được" % [lane, team])
			if path.is_empty():
				continue
			assert_eq(path[-1], route[-1])
			for i: int in range(1, path.size()):
				assert_true(_nav.has_line_of_walk(path[i - 1], path[i]), "đoạn %d của %s/%d không xuyên vật cản" % [i, lane, team])


func test_MAP_01_every_camp_reachable_from_blue_fountain() -> void:
	for i: int in range(_map.camp_points.size()):
		var target: Vector2 = _nav.nearest_clear(_map.camp_points[i])
		assert_false(_nav.path(_map.fountain_point(0), target).is_empty(), "tới được trại " + _map.camp_ids[i])


func test_MAP_01_both_bases_connected() -> void:
	assert_false(_nav.path(_map.fountain_point(0), _map.fountain_point(1)).is_empty())


func test_MAP_01_random_routes_never_clip_terrain() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2026
	var routed: int = 0
	var size: Vector2 = _map.world_size()
	for attempt: int in range(60):
		var a: Vector2 = Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		var b: Vector2 = Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y))
		if not _nav.point_is_clear(a) or not _nav.point_is_clear(b):
			continue
		var path: PackedVector2Array = _nav.path(a, b)
		if path.is_empty():
			continue
		routed += 1
		assert_true(path[0] == a and path[-1] == b, "đường %d giữ đúng điểm đầu/cuối" % attempt)
		for i: int in range(1, path.size()):
			assert_true(_nav.has_line_of_walk(path[i - 1], path[i]), "đường %d đoạn %d" % [attempt, i])
	assert_true(routed >= 15, "đủ số đường ngẫu nhiên (%d)" % routed)


func test_MAP_01_destination_inside_forest_rejected() -> void:
	var forest: Vector2 = _map.forest_shapes[0].outer[0]
	for shape: MapShape in _map.forest_shapes:
		var c: Vector2 = Vector2.ZERO
		for p: Vector2 in shape.outer:
			c += p
		c /= shape.outer.size()
		if _map.clearance_at(c) == 0.0 and Geometry2D.is_point_in_polygon(c, shape.outer):
			forest = c
			break
	assert_true(_nav.path(_map.fountain_point(0), forest).is_empty())


func test_MAP_01_out_of_map_destination_rejected() -> void:
	assert_true(_nav.path(_map.fountain_point(0), Vector2(-100, -100)).is_empty())


func test_MAP_01_no_diagonal_corner_cutting() -> void:
	assert_eq(_nav.grid.diagonal_mode, AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES)


func test_MAP_01_tower_body_blocks_standing() -> void:
	var tower: Vector2 = _map.tower_points[0]
	assert_false(_nav.point_is_clear(tower + Vector2(TOWER_BODY + HERO_RADIUS - 1, 0)))
	assert_true(_nav.nearest_clear(tower).distance_to(tower) >= TOWER_BODY + HERO_RADIUS - 0.001)


func test_MAP_01_exact_destination_retained() -> void:
	var exact: Vector2 = _nav.nearest_clear(_map.fountain_point(0) + Vector2(410, -370))
	var path: PackedVector2Array = _nav.path(_map.fountain_point(0), exact)
	assert_false(path.is_empty())
	assert_eq(path[-1], exact)


func test_MAP_01_larger_agent_can_cross_map() -> void:
	var big: MapNavigation = MapNavigation.new(_map, 70.0, TOWER_BODY)
	assert_false(big.path(_map.fountain_point(0), _map.fountain_point(1)).is_empty())


func test_MAP_01_same_query_same_path() -> void:
	# D-30: tìm đường xác định.
	var a: PackedVector2Array = _nav.path(_map.fountain_point(0), _map.fountain_point(1))
	var b: PackedVector2Array = _nav.path(_map.fountain_point(0), _map.fountain_point(1))
	assert_eq(a, b)
