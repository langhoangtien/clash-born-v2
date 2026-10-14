extends TestCase
## M2.3: lính đường — CRP-01..10, DEF-06/07/08, INV-03/04, D-48.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(with_structures: bool = true, waves: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	if with_structures:
		MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_lane_creeps(w, _lib, waves)
	return w


func _creep(w: World, team: int, lane: String, kind: StringName, progress: float) -> Entity:
	var route: LaneRoute = LaneRoute.of(w, lane, team)
	return MatchSetup.spawn_creep(w, _lib, kind, team, lane, route.point_at(progress))


func _hero(w: World, team: int, at: Vector2, damage: float = 40.0) -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, damage)
	return e


func _run(w: World, ticks: int) -> void:
	for t: int in range(ticks):
		w.step()


func _creeps(w: World) -> Array[Entity]:
	var out: Array[Entity] = []
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.LANE_CREEP:
			out.append(e)
	return out


func test_D_48_creep_stats_from_content() -> void:
	var w: World = _world(false)
	var melee: Entity = _creep(w, 0, "MID", &"creep_melee", 0)
	var siege: Entity = _creep(w, 0, "MID", &"creep_siege", 0)
	assert_near(melee.health, 450.0, EPS)
	assert_near(melee.stats.get_stat(StatId.Id.BASE_ATTACK_TIME), 1.0, EPS)
	assert_near(siege.stats.get_stat(StatId.Id.BASE_ATTACK_TIME), 2.7, EPS)
	assert_true(siege.siege and not melee.siege)
	assert_eq(melee.lane, "MID")


func test_CRP_08_first_wave_at_15s_then_every_30s_siege_every_5th() -> void:
	var w: World = _world(false, true)
	# Lính đứng yên cho test nhanh: chỉ đếm số lính sinh ra.
	w.balance = w.balance.duplicate()
	w.balance.creep_acquire_range = 0.0
	_run(w, SimClock.seconds_to_ticks(15.0) - 1)
	assert_eq(_creeps(w).size(), 0)
	w.step()
	assert_eq(_creeps(w).size(), 2 * 3 * 4, "đợt 1: 2 đội × 3 lane × (3+1)")
	assert_eq(_creeps(w).filter(func(e: Entity) -> bool: return e.siege).size(), 0)
	var spawned_at: Array[int] = []
	var last: int = _creeps(w).size()
	for t: int in range(SimClock.seconds_to_ticks(4 * 30.0)):
		w.step()
		var now: int = _creeps(w).size()
		if now > last:
			spawned_at.append(w.tick)
		last = now
	assert_eq(spawned_at.size(), 4)
	assert_eq(spawned_at[0] - SimClock.seconds_to_ticks(15.0), SimClock.seconds_to_ticks(30.0))
	assert_eq(_creeps(w).filter(func(e: Entity) -> bool: return e.siege).size(), 6, "đợt 5 có 1 xe mỗi lane mỗi đội")


func test_CRP_05_advance_follows_lane_and_stops_at_front_edge() -> void:
	var w: World = _world(true)
	var c: Entity = _creep(w, 0, "TOP", &"creep_melee", 0)
	var route: LaneRoute = LaneRoute.of(w, "TOP", 0)
	var nav: MapNavigation = w.navigation(c.radius)
	for t: int in range(SimClock.seconds_to_ticks(40.0)):
		w.step()
		assert_true(route.distance_to_route(c.position) < 260.0, "tick %d lệch lane %.0f" % [w.tick, route.distance_to_route(c.position)])
		assert_true(nav.point_is_clear(c.position))
	var limit: float = LaneRoute.limit(w, c)
	assert_true(route.progress_of(c.position) <= limit + w.balance.creep_front_margin, "INV-03")


func test_CRP_03_attacks_next_structure_when_no_creeps() -> void:
	var w: World = _world(true)
	var tower: Entity = Objectives.next_for_lane(w, 0, "MID")
	assert_eq(tower.structure_id, &"red_mid_t1", "DEF-06")
	var c: Entity = _creep(w, 0, "MID", &"creep_ranged", LaneRoute.of(w, "MID", 0).progress_of(tower.position) - 900)
	_run(w, SimClock.seconds_to_ticks(8.0))
	assert_eq(c.order.target_id, tower.id)
	assert_true(tower.health < 1800.0)



## M2.6 (soak tìm ra): lính công thành tầm 690 đứng ở mép trước của nó, trụ ngoài 500 vẫn phải đánh.
func test_CRP_03_siege_attacks_structure_beyond_acquire_range_but_in_attack_range() -> void:
	var w: World = _world(true)
	var tower: Entity = Objectives.next_for_lane(w, 0, "MID")
	var siege: Entity = _creep(w, 0, "MID", &"creep_siege", 0)
	var route: LaneRoute = LaneRoute.of(w, "MID", 0)
	siege.position = w.navigation(siege.radius).nearest_clear(route.point_at(LaneRoute.limit(w, siege)))
	assert_true(Rules.edge_distance(siege, tower) > w.balance.creep_acquire_range, "ngoài tầm nhận mục tiêu")
	_run(w, 3)
	assert_eq(siege.order.type, Order.Type.ATTACK)
	assert_eq(siege.order.target_id, tower.id)


## M2.6 (soak tìm ra): tới góc lane rồi bị đẩy lệch thì vẫn đi tiếp, không đứng mãi.
func test_CRP_05_pushed_off_finished_point_keeps_walking() -> void:
	var w: World = _world(false)
	var route: LaneRoute = LaneRoute.of(w, "BOT", 0)
	var corner: float = route.next_vertex_after(route.length() * 0.4)
	var c: Entity = _creep(w, 0, "BOT", &"creep_melee", corner)
	c.order = Order.move(route.point_at(corner))
	c.order.finished = true
	c.position = w.navigation(c.radius).nearest_clear(route.point_at(corner) + Vector2(30, 30))
	var start: float = route.progress_of(c.position)
	_run(w, SimClock.seconds_to_ticks(2.0))
	assert_true(route.progress_of(c.position) > start + 200.0, "lính đi tiếp dọc lane")

func test_CRP_02_creeps_fight_each_other_and_keep_target() -> void:
	var w: World = _world(false)
	var route: LaneRoute = LaneRoute.of(w, "MID", 0)
	var mid: float = route.length() * 0.5
	var blue: Entity = _creep(w, 0, "MID", &"creep_melee", mid - 200)
	var red_a: Entity = _creep(w, 1, "MID", &"creep_melee", route.length() - mid - 200)
	_run(w, SimClock.seconds_to_ticks(3.0))
	assert_eq(blue.order.target_id, red_a.id)
	var red_b: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 1, "MID", w.navigation(22.0).nearest_clear(blue.position + Vector2(50, 0)))
	_run(w, 10)
	assert_eq(blue.order.target_id, red_a.id, "CRP-06: không đổi chỉ vì có lính gần hơn")
	assert_ne(red_b, null)


func test_CRP_04_attacks_enemy_hero_when_nothing_else() -> void:
	var w: World = _world(false)
	var c: Entity = _creep(w, 0, "MID", &"creep_melee", 2000)
	var hero: Entity = _hero(w, 1, c.position + Vector2(250, -250))
	_run(w, SimClock.seconds_to_ticks(2.0))
	assert_eq(c.order.target_id, hero.id)


func test_CRP_01_creeps_defend_their_hero() -> void:
	var w: World = _world(false)
	var route: LaneRoute = LaneRoute.of(w, "MID", 0)
	var blue: Entity = _creep(w, 0, "MID", &"creep_melee", 2500)
	var red_creep: Entity = _creep(w, 1, "MID", &"creep_melee", route.length() - 2500 - 150)
	_run(w, SimClock.seconds_to_ticks(1.0))
	var victim: Entity = _hero(w, 0, blue.position + Vector2(-150, 150))
	var bully: Entity = _hero(w, 1, victim.position + Vector2(-90, 0))
	w.submit(Command.attack(bully.id, victim.id))
	_run(w, SimClock.seconds_to_ticks(2.0))
	assert_eq(blue.order.target_id, bully.id, "hero địch đánh hero phe mình → lính đánh hero đó")
	assert_ne(red_creep, null)


func test_INV_04_chase_respects_leash_and_returns_to_route() -> void:
	var w: World = _world(false)
	var c: Entity = _creep(w, 0, "MID", &"creep_melee", 2500)
	var route: LaneRoute = LaneRoute.of(w, "MID", 0)
	var hero: Entity = _hero(w, 1, c.position + Vector2(200, 200))
	var away: Vector2 = w.navigation(32.0).nearest_clear(hero.position + (hero.position - c.position).normalized() * 3000)
	_run(w, SimClock.seconds_to_ticks(1.5))
	w.submit(Command.move_to(hero.id, away))
	var chased: bool = false
	for t: int in range(SimClock.seconds_to_ticks(12.0)):
		w.step()
		if c.has_origin:
			chased = true
			if c.position.distance_to(c.chase_origin) > w.balance.creep_chase_leash + 100.0:
				fail("tick %d INV-04: cách origin %.0f" % [w.tick, c.position.distance_to(c.chase_origin)])
				return
	assert_true(chased, "lính có đuổi hero")
	assert_true(route.distance_to_route(c.position) < 260.0, "về lại lane")


func test_CRP_10_siege_deals_bonus_to_structures() -> void:
	var w: World = _world(true)
	var tower: Entity = Objectives.next_for_lane(w, 0, "MID")
	var siege: Entity = _creep(w, 0, "MID", &"creep_siege", LaneRoute.of(w, "MID", 0).progress_of(tower.position) - 700)
	var expected: float = 40.0 * 1.25 / (1.0 + 0.06 * 10.0)
	_run(w, SimClock.seconds_to_ticks(6.0))
	assert_true(siege.alive)
	var lost: float = 1800.0 - tower.health
	assert_near(fmod(lost, expected), 0.0, 0.05, "mỗi phát %.2f" % expected)


func test_D_30_first_wave_replays_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world(true, true)
		for t: int in range(SimClock.seconds_to_ticks(22.0)):
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return
