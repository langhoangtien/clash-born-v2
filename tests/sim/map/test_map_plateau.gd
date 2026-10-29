extends TestCase
## D-178: trại chia theo rừng (MAP-02), rìa map ngoài lane chặn đường (MAP-12).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
## MAP-02: rừng carry (phía lane an toàn: Blue BOT, Red TOP) 5 trại, rừng lane khó 3; cách trụ ≥ 720.
const CARRY_CAMPS: int = 5
const OFFLANE_CAMPS: int = 3
const TOWER_GAP: float = 720.0
## MAP-12: rìa map bắt đầu cách tim lane nửa lane + 64; dò thêm 120 ra ngoài.
const EDGE_MARGIN: float = 64.0
const PROBE: float = 120.0
const STEP: float = 250.0

var map: MapLayout


func before_each() -> void:
	map = load(MAP_PATH) as MapLayout


func test_MAP_02_carry_jungle_has_five_camps_offlane_three() -> void:
	var safe: Dictionary = {0: "BOT", 1: "TOP"}
	var hard: Dictionary = {0: "TOP", 1: "BOT"}
	for team: int in 2:
		var carry: int = 0
		var off: int = 0
		for i: int in map.camp_ids.size():
			if map.camp_sides[i] != team:
				continue
			var p: Vector2 = map.camp_points[i]
			if _to_line(p, map.lanes[safe[team]]) < _to_line(p, map.lanes[hard[team]]):
				carry += 1
			else:
				off += 1
		assert_eq(carry, CARRY_CAMPS, "đội %d: trại rừng carry" % team)
		assert_eq(off, OFFLANE_CAMPS, "đội %d: trại rừng lane khó" % team)


func test_MAP_02_camps_out_of_tower_range() -> void:
	for i: int in map.camp_ids.size():
		for t: Vector2 in map.tower_points:
			assert_true(t.distance_to(map.camp_points[i]) >= TOWER_GAP, "trại %s cách trụ %.0f" % [map.camp_ids[i], t.distance_to(map.camp_points[i])])


func test_MAP_12_outside_lanes_is_blocked_except_bases() -> void:
	var center: Vector2 = map.world_size() * 0.5
	var reach: float = map.lane_width * 0.5 + EDGE_MARGIN + PROBE
	var checked: int = 0
	for lane: String in ["TOP", "BOT"]:
		for team: int in 2:
			var line: PackedVector2Array = map.route(lane, team)
			for i: int in line.size() - 1:
				var steps: int = maxi(1, int(line[i].distance_to(line[i + 1]) / STEP))
				var normal: Vector2 = (line[i + 1] - line[i]).normalized().orthogonal()
				for k: int in steps:
					var p: Vector2 = line[i].lerp(line[i + 1], (k + 0.5) / steps)
					var out: Vector2 = p + normal * reach
					if out.distance_to(center) < (p - normal * reach).distance_to(center):
						out = p - normal * reach
					if not map.world_rect().has_point(out) or map.is_in_base(out, 0) or map.is_in_base(out, 1):
						continue
					checked += 1
					assert_true(map.clearance_at(out) <= 0.0, "ngoài lane %s tại %s phải là rìa map" % [lane, out])
	assert_true(checked > 40, "đủ điểm dò (%d)" % checked)


func _to_line(p: Vector2, line: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in line.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best
