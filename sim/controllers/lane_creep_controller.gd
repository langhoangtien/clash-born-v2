class_name LaneCreepController
extends SimSystem
## Pha 5: lính đường (CRP-01..09), sinh Command cho tick sau. Ưu tiên: (1) hero địch vừa
## đánh hero phe mình gần đó; (2) lính địch; (3) công trình kế tiếp; (4) hero địch gần;
## (5) đi theo lane tới mép trước. Cùng dòng thì giữ mục tiêu cũ (CRP-06). Vượt leash
## hoặc mép trước → về lane (CRP-07), lúc về không nhận mục tiêu.


## Hằng số kỹ thuật: cách điểm đích chừng này coi như đã tới (lính bị đẩy lệch khi tới góc lane).
const ARRIVE: float = 16.0

var _next_tick: int = -1
var _next_cache: Dictionary[int, Entity] = {}


func run(world: World) -> void:
	for c: Entity in world.entities:
		if c.kind == Entity.Kind.LANE_CREEP and c.alive:
			_remember_aggro(world, c)
			_think(world, c)


func _remember_aggro(world: World, c: Entity) -> void:
	for ev: GameEvent in world.previous_hero_fights():
		var attacker: Entity = world.find_entity(ev.source_id)
		var victim: Entity = world.find_entity(ev.target_id)
		if attacker != null and victim != null and victim.team == c.team \
				and c.position.distance_to(victim.position) <= world.balance.creep_hero_aggro_range:
			c.aggro_target_id = attacker.id
			c.aggro_until_tick = world.tick + SimClock.seconds_to_ticks(world.balance.creep_hero_aggro_time)


func _think(world: World, c: Entity) -> void:
	var route: LaneRoute = LaneRoute.of(world, c.lane, c.team)
	if c.returning:
		if route.distance_to_route(c.position) <= c.radius + 16.0 or (c.order.type == Order.Type.MOVE and c.order.finished):
			c.returning = false
			c.has_origin = false
		else:
			_move(world, c, c.return_point)
			return
	var target: Entity = _pick(world, c)
	if target == null:
		c.has_origin = false
		_advance(world, c, route)
		return
	if not c.has_origin:
		c.has_origin = true
		c.chase_origin = c.position  # DEF-08
	var limit: float = LaneRoute.limit(world, c)
	var too_far: bool = c.position.distance_to(c.chase_origin) > world.balance.creep_chase_leash
	if too_far or route.progress_of(c.position) > limit + world.balance.creep_front_margin:
		c.returning = true
		c.aggro_target_id = -1
		c.return_point = world.navigation(c.radius).nearest_clear(route.point_at(minf(route.progress_of(c.position), limit)))
		_move(world, c, c.return_point)
		return
	if c.order.type != Order.Type.ATTACK or c.order.target_id != target.id or c.order.finished:
		world.submit(Command.attack(c.id, target.id))


func _pick(world: World, c: Entity) -> Entity:
	if world.tick <= c.aggro_until_tick:
		var bully: Entity = world.find_entity(c.aggro_target_id)
		if Rules.is_targetable(c, bully):
			return bully  # CRP-01
	var current: Entity = world.find_entity(c.order.target_id) if c.order.type == Order.Type.ATTACK and not c.order.finished else null
	if current != null and Rules.is_targetable(c, current) and current.kind == Entity.Kind.LANE_CREEP:
		return current  # CRP-02 + CRP-06
	var nearest: Array[Entity] = _nearest_creep_and_hero(world, c)
	if nearest[0] != null:
		return nearest[0]
	var structure: Entity = _next_structure(world, c)
	if structure != null and Rules.is_targetable(c, structure) \
			and (Rules.edge_distance(c, structure) <= world.balance.creep_acquire_range or Rules.in_attack_range(c, structure)):
		return structure  # CRP-03
	if current != null and Rules.is_targetable(c, current) and current.kind == Entity.Kind.HERO \
			and Rules.edge_distance(c, current) <= world.balance.creep_acquire_range:
		return current  # CRP-04 + CRP-06
	return nearest[1]


## DEF-06, nhớ theo (đội, lane) trong một tick để khỏi duyệt lại danh sách đơn vị.
func _next_structure(world: World, c: Entity) -> Entity:
	var key: int = c.team * 10 + ["TOP", "MID", "BOT"].find(c.lane)
	if _next_tick != world.tick:
		_next_tick = world.tick
		_next_cache.clear()
	if not _next_cache.has(key):
		_next_cache[key] = Objectives.next_for_lane(world, c.team, c.lane)
	return _next_cache[key]


## Lính địch và hero địch gần nhất trong `creep_acquire_range` (một lần tra lưới cho cả hai).
func _nearest_creep_and_hero(world: World, c: Entity) -> Array[Entity]:
	var best: Array[Entity] = [null, null]
	var best_d: Array[float] = [INF, INF]
	var acquire: float = world.balance.creep_acquire_range
	for e: Entity in world.spatial_near(c.position, acquire + c.radius, World.Phase.CONTROLLER, false):
		var slot: int = 0 if e.kind == Entity.Kind.LANE_CREEP else (1 if e.kind == Entity.Kind.HERO else -1)
		if slot < 0 or not Rules.is_targetable(c, e):
			continue
		var d: float = Rules.edge_distance(c, e)
		if d <= acquire and (d < best_d[slot] or (d == best_d[slot] and e.id < best[slot].id)):
			best[slot] = e
			best_d[slot] = d
	return best


## CRP-05: đi tới điểm route kế tiếp, không quá mép trước (DEF-07).
func _advance(world: World, c: Entity, route: LaneRoute) -> void:
	var progress: float = route.progress_of(c.position)
	var limit: float = LaneRoute.limit(world, c)
	if progress >= limit - 1.0:
		if c.order.type != Order.Type.IDLE:
			world.submit(Command.stop(c.id))
		return
	var goal: float = minf(route.next_vertex_after(progress), limit)
	if goal < limit and c.position.distance_to(route.point_at(goal)) <= ARRIVE:
		goal = minf(route.next_vertex_after(goal), limit)  # đã tới góc (bị đẩy lệch) → góc kế
	_move(world, c, route.point_at(goal))


func _move(world: World, c: Entity, point: Vector2) -> void:
	if c.order.type == Order.Type.MOVE and not c.order.finished and c.order.point.distance_to(point) < 1.0:
		return
	if c.order.type == Order.Type.MOVE and c.order.finished and c.order.point.distance_to(point) < 1.0 \
			and c.position.distance_to(point) <= ARRIVE:
		return  # đã tới; bị đẩy lệch xa hơn ARRIVE thì gửi lại để đi tiếp
	world.submit(Command.move_to(c.id, point))
