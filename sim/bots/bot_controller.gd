class_name BotController
extends SimSystem
## Pha CONTROLLER (BOT-01..15): mỗi hero có Entity.bot gửi Command như người chơi. Chọn state
## theo thứ tự ưu tiên của bảng BOT; mọi điểm tới / đứng đánh qua Rules.is_safe_for_hero
## (BOT-10); chỉ dùng đơn vị đội mình đang thấy (BOT-12).

const Mode := BotState.Mode
## Tới gần điểm đích chừng này thì coi như đã tới.
const ARRIVE: float = 60.0


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.kind != Entity.Kind.HERO or e.bot == null or not e.alive or e.reincarnate_tick >= 0:
			continue
		if (world.tick + e.id) % e.bot.think_ticks() != 0:
			continue
		think(world, e)


## Một lần nghĩ: chọn state rồi làm.
func think(world: World, e: Entity) -> void:
	var b: BotState = e.bot
	b.mode = choose(world, e)
	match b.mode:
		Mode.ESCAPE_TOWER:
			_go(world, e, escape_point(world, e))
		Mode.RETREAT:
			_go(world, e, world.map.fountain_point(e.team))
		Mode.RECOVER:
			_hold(world, e)
		_:
			_go(world, e, rally_point(world, e))


## Thứ tự ưu tiên của bảng BOT.
func choose(world: World, e: Entity) -> Mode:
	var b: BotState = e.bot
	var hp: float = _hp(e)
	if _targeted_by_structure(world, e) or Rules.in_enemy_fountain(world, e.team, e.position, e.radius):
		return Mode.ESCAPE_TOWER  # BOT-01
	var home: Vector2 = world.map.fountain_point(e.team)
	var at_home: bool = e.position.distance_to(home) <= world.balance.fountain_radius * 0.6
	if at_home and (hp < world.balance.bot_recover_hp or (b.mode == Mode.RETREAT and hp < 0.999)) :
		return Mode.RECOVER  # BOT-03
	if b.mode == Mode.RECOVER and at_home and hp < world.balance.bot_recover_hp:
		return Mode.RECOVER
	if hp < world.balance.bot_retreat_hp or (b.mode == Mode.RETREAT and not at_home):
		return Mode.RETREAT  # BOT-02
	return Mode.RALLY


## BOT-01: điểm an toàn gần nhất phía nhà (lùi ra khỏi vùng mọi trụ đang đe dọa, rồi về nhà).
func escape_point(world: World, e: Entity) -> Vector2:
	var home: Vector2 = world.map.fountain_point(e.team)
	var nav: MapNavigation = world.navigation(e.radius)
	var step: Vector2 = (home - e.position).normalized()
	for d: float in [300.0, 500.0, 700.0, 900.0, 1200.0, 1600.0]:
		var p: Vector2 = nav.nearest_clear(e.position + step * d)
		if Rules.is_safe_for_hero(world, e, p) and not _threatened_by_targeting(world, e, p):
			return p
	return home


## BOT-09 (tạm ở M7.2, đủ ở M7.3): điểm xa nhất trên route lane còn an toàn, tính từ công
## trình kế tiếp của địch lùi về.
func rally_point(world: World, e: Entity) -> Vector2:
	var route: LaneRoute = LaneRoute.of(world, e.bot.lane, e.team)
	var next: Entity = Objectives.next_for_lane(world, e.team, e.bot.lane)
	var p: float = route.progress_of(next.position) if next != null else route.length()
	return _safe_along(world, e, route, p)


## Lùi dọc route từ tiến độ `p` tới điểm đầu tiên an toàn (BOT-10).
func _safe_along(world: World, e: Entity, route: LaneRoute, p: float) -> Vector2:
	var nav: MapNavigation = world.navigation(e.radius)
	while p > 0.0:
		var q: Vector2 = nav.nearest_clear(route.point_at(p))
		if Rules.is_safe_for_hero(world, e, q):
			return q
		p -= 100.0
	return nav.nearest_clear(route.point_at(0.0))


## Lùi điểm `p` về phía nhà tới khi an toàn (BOT-10).
func _safe_back(world: World, e: Entity, p: Vector2) -> Vector2:
	var home: Vector2 = world.map.fountain_point(e.team)
	var nav: MapNavigation = world.navigation(e.radius)
	var q: Vector2 = p
	for i: int in range(12):
		if Rules.is_safe_for_hero(world, e, q):
			return q
		q = nav.nearest_clear(q + (home - q).normalized() * 200.0)
	return home


func _go(world: World, e: Entity, point: Vector2) -> void:
	var b: BotState = e.bot
	if e.position.distance_to(point) <= ARRIVE * 0.5 and e.order.type != Order.Type.MOVE:
		b.goal = point
		return
	var moving: bool = e.order.type == Order.Type.MOVE and not e.order.finished
	if moving and b.goal.is_finite() and b.goal.distance_to(point) < ARRIVE:
		return
	b.goal = point
	b.target_id = -1
	world.submit(Command.move_to(e.id, point))


func _hold(world: World, e: Entity) -> void:
	if e.order.type != Order.Type.IDLE:
		world.submit(Command.stop(e.id))
	e.bot.goal = Vector2.INF
	e.bot.target_id = -1


func _hp(e: Entity) -> float:
	return e.health / maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP))


## BOT-01: trụ địch đang nhắm bot (mục tiêu lệnh đánh của trụ).
func _targeted_by_structure(world: World, e: Entity) -> bool:
	for t: Entity in Rules.tower_threat_at(world, e.team, e.position, e.radius):
		if t.order.type == Order.Type.ATTACK and not t.order.finished and t.order.target_id == e.id:
			return true
	return false


## Điểm `p` còn trong vùng một trụ đang nhắm bot.
func _threatened_by_targeting(world: World, e: Entity, p: Vector2) -> bool:
	for t: Entity in Rules.tower_threat_at(world, e.team, p, e.radius):
		if t.order.target_id == e.id:
			return true
	return false
