class_name LaneRoute
extends RefCounted
## Route một lane theo hướng một đội, đo bằng "tiến độ" = quãng đường dọc route (DEF-07).

var points: PackedVector2Array
var _cumulative: PackedFloat64Array = PackedFloat64Array()
## Mép trước đã tính; khóa gồm số công trình đã đổ nên tự hết hạn khi có trụ đổ.
var _limit_cache: Dictionary[int, float] = {}


static func of(world: World, lane: String, team: int) -> LaneRoute:
	var key: String = "%s:%d" % [lane, team]
	if not world.lane_routes.has(key):
		var r: LaneRoute = LaneRoute.new()
		r.points = world.map.route(lane, team)
		r._build()
		world.lane_routes[key] = r
	return world.lane_routes[key]


## Hằng số kỹ thuật: bước dò dọc route khi tìm mép trước, và độ chừa để chắc chắn trong tầm.
const LIMIT_STEP: float = 8.0
const LIMIT_SLACK: float = 4.0


## DEF-07: mép trước của lane cho lính `creep` = điểm route đầu tiên (đi về phía trước) mà
## từ đó công trình kế tiếp nằm trong tầm đánh của lính. Không còn công trình → cuối route.
static func limit(world: World, creep: Entity) -> float:
	var route: LaneRoute = of(world, creep.lane, creep.team)
	var key: int = (world.destroyed_structures.size() * 100000 + roundi(creep.stats.get_stat(StatId.Id.ATTACK_RANGE))) * 1000 \
		+ roundi(creep.radius)
	if route._limit_cache.has(key):
		return route._limit_cache[key]
	var value: float = _compute_limit(world, creep, route)
	route._limit_cache[key] = value
	return value


static func _compute_limit(world: World, creep: Entity, route: LaneRoute) -> float:
	var target: Entity = Objectives.next_for_lane(world, creep.team, creep.lane)
	if target == null:
		return route.length()
	var reach: float = creep.stats.get_stat(StatId.Id.ATTACK_RANGE) + creep.radius + target.radius - LIMIT_SLACK
	var p: float = route.progress_of(target.position)
	while p > 0.0 and route.point_at(p - LIMIT_STEP).distance_to(target.position) <= reach:
		p -= LIMIT_STEP
	return p


func _build() -> void:
	_cumulative.append(0.0)
	for i: int in range(1, points.size()):
		_cumulative.append(_cumulative[i - 1] + points[i - 1].distance_to(points[i]))


func length() -> float:
	return _cumulative[-1]


func progress_of(p: Vector2) -> float:
	var best_d: float = INF
	var best: float = 0.0
	for i: int in range(1, points.size()):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, points[i - 1], points[i])
		var d: float = q.distance_to(p)
		if d < best_d:
			best_d = d
			best = _cumulative[i - 1] + points[i - 1].distance_to(q)
	return best


func distance_to_route(p: Vector2) -> float:
	return point_at(progress_of(p)).distance_to(p)


func point_at(progress: float) -> Vector2:
	var t: float = clampf(progress, 0.0, length())
	for i: int in range(1, points.size()):
		if t <= _cumulative[i]:
			var seg: float = _cumulative[i] - _cumulative[i - 1]
			return points[i - 1].lerp(points[i], 0.0 if seg <= 0.0 else (t - _cumulative[i - 1]) / seg)
	return points[-1]


## Tiến độ của điểm route kế tiếp sau `progress` (để đi lần lượt qua các điểm, không tắt).
func next_vertex_after(progress: float) -> float:
	for c: float in _cumulative:
		if c > progress + 1.0:
			return c
	return length()
