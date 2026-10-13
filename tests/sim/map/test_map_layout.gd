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
	assert_eq(map.world_size(), Vector2(8448, 8448))


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


func test_MAP_02_thirteen_camps_plus_boss_pit() -> void:
	assert_eq(map.camp_points.size(), 14)
	assert_eq(map.camp_kinds.count("boss"), 1)


func test_MAP_02_three_distinct_lanes_from_spawn_to_enemy_spawn() -> void:
	assert_ne(map.route("TOP", 0), map.route("MID", 0))
	assert_ne(map.route("MID", 0), map.route("BOT", 0))
	for lane: String in MapLayout.LANES:
		for team: int in range(2):
			var route: PackedVector2Array = map.route(lane, team)
			assert_eq(route[0], map.lane_spawn_point(team, lane), "%s đội %d bắt đầu ở điểm sinh lính" % [lane, team])
			assert_eq(route[-1], map.lane_spawn_point(1 - team, lane), "%s đội %d kết thúc ở điểm sinh lính địch" % [lane, team])


func test_MAP_02_ramps_walkable_for_hero() -> void:
	assert_true(map.ramp_points.size() > 0)
	for index: int in range(map.ramp_points.size()):
		assert_true(map.clearance_at(map.ramp_points[index]) >= 32.0, "dốc %d đi được" % index)


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
	for shape: MapShape in map.forest_shapes:
		var center: Vector2 = Vector2.ZERO
		for point: Vector2 in shape.outer:
			center += point
		center /= shape.outer.size()
		if Geometry2D.is_point_in_polygon(center, shape.outer) and map.clearance_at(center) == 0.0:
			return center
	return Vector2.ZERO
