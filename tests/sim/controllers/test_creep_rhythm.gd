extends TestCase
## D-265: nhịp nghĩ theo tình huống — lính đi đường nghĩ thưa (CRP-13), phe trung lập chỉ nhìn khi trại đánh
## (VIS-09), trại rừng ngủ khi không ai lại gần (JGL-08).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(jungle: bool) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(3, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	MatchSetup.add_lane_creeps(w, _lib, false)
	if jungle:
		MatchSetup.add_jungle(w, _lib)
	return w


func _creep(w: World, team: int, progress: float) -> Entity:
	var route: LaneRoute = LaneRoute.of(w, "MID", team)
	return MatchSetup.spawn_creep(w, _lib, &"creep_melee", team, "MID", route.point_at(progress))


func _hero(w: World, team: int, at: Vector2) -> Entity:
	return UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))


func _steps(w: World, n: int) -> void:
	for i: int in n:
		w.step()


## Chạy tới lúc lính vừa nghĩ "đi đường" (calm_until_tick vừa đặt mới), trả về tick đó.
func _until_calm_think(w: World, c: Entity) -> int:
	var before: int = c.calm_until_tick
	for i: int in 60:
		w.step()
		if c.calm_until_tick != before and c.calm_until_tick > w.tick:
			return w.tick
		before = c.calm_until_tick
	fail("lính không vào nhịp đi đường")
	return -1


func test_CRP_13_walking_creep_notices_enemy_within_calm_time() -> void:
	var w: World = _world(false)
	var c: Entity = _creep(w, 0, 2000)
	_steps(w, 10)
	var t0: int = _until_calm_think(w, c)
	var calm: int = SimClock.seconds_to_ticks(w.balance.creep_calm_think_time)
	assert_eq(c.calm_until_tick, t0 + calm, "đi đường: lần nghĩ sau cách creep_calm_think_time")
	var foe: Entity = _hero(w, 1, c.position + c.facing * 300.0)
	_steps(w, calm - 1)
	assert_true(c.order.type != Order.Type.ATTACK, "chưa tới lượt nghĩ: chưa thấy địch")
	_steps(w, 2)
	assert_eq(c.order.target_id, foe.id, "tới lượt nghĩ (≤ 0,2 s) thì đánh hero địch gần (CRP-04)")
	assert_eq(c.calm_until_tick, -1, "đang có mục tiêu: về nhịp thường")


func test_CRP_13_damage_wakes_walking_creep() -> void:
	var w: World = _world(false)
	var c: Entity = _creep(w, 0, 2000)
	_steps(w, 10)
	_until_calm_think(w, c)
	var far: Entity = _hero(w, 1, c.position + Vector2(3000, 0))
	var r: DamageRequest = DamageRequest.new()
	r.source_id = far.id
	r.target_id = c.id
	r.raw = 10.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	var hit_tick: int = w.tick + 1
	var old: int = c.calm_until_tick
	_steps(w, 4)
	assert_ne(c.calm_until_tick, old, "bị đánh: nghĩ lại ngay (≤ 2 tick sau), không chờ hết nhịp đi đường")
	assert_true(c.calm_until_tick <= hit_tick + 3 + SimClock.seconds_to_ticks(w.balance.creep_calm_think_time))


func test_CRP_13_fighting_creep_keeps_normal_rhythm() -> void:
	var w: World = _world(false)
	var route: LaneRoute = LaneRoute.of(w, "MID", 0)
	var mid: float = route.length() * 0.5
	var blue: Entity = _creep(w, 0, mid - 200)
	var red: Entity = _creep(w, 1, route.length() - mid - 200)
	_steps(w, SimClock.seconds_to_ticks(3.0))
	assert_eq(blue.order.target_id, red.id)
	assert_eq(blue.calm_until_tick, -1, "giao tranh: nghĩ mỗi 2 tick như D-108")


func _spawned(w: World) -> void:
	while w.tick < SimClock.seconds_to_ticks(w.balance.jungle_first_spawn):
		w.step()


func _first_camp(w: World) -> CampState:
	for c: CampState in w.camps:
		if not c.unit_ids.is_empty():
			return c
	return null


func test_VIS_09_neutral_sees_nobody_while_no_camp_fights() -> void:
	var w: World = _world(true)
	_spawned(w)
	var camp: CampState = _first_camp(w)
	var me: Entity = _hero(w, 0, camp.center + Vector2(250, 0))
	_steps(w, 2)
	assert_eq(me.visible_mask & (1 << 2), 0, "không trại nào đánh: phe trung lập không cần thấy ai")


func test_VIS_09_hit_camp_sees_and_fights_attacker() -> void:
	var w: World = _world(true)
	_spawned(w)
	var camp: CampState = _first_camp(w)
	var me: Entity = _hero(w, 0, camp.center + Vector2(250, 0))
	var victim: Entity = w.find_entity(camp.unit_ids[0])
	var r: DamageRequest = DamageRequest.new()
	r.source_id = me.id
	r.target_id = victim.id
	r.raw = 5.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	_steps(w, 4)
	assert_eq(camp.target_id, me.id, "JGL-01 vẫn đúng: trại nhận kẻ đánh")
	assert_true(not camp.returning, "thấy kẻ đánh nên không bỏ về")
	assert_true(me.visible_mask & (1 << 2) != 0, "trại đang đánh: phe trung lập thấy")
	assert_eq(victim.order.target_id, me.id)


func test_JGL_08_camp_sleeps_until_someone_comes_near() -> void:
	var w: World = _world(true)
	_spawned(w)
	var camp: CampState = _first_camp(w)
	var members: Array[Entity] = []
	for id: int in camp.unit_ids:
		members.append(w.find_entity(id))
	w.step()
	assert_true(members[0].asleep, "không ai trong jungle_sleep_radius: trại ngủ")
	_hero(w, 0, camp.center + Vector2(w.balance.jungle_sleep_radius - 60.0, 0))
	w.step()
	assert_true(not members[0].asleep, "có người lại gần: thức ngay tick đó")


func test_JGL_08_sleeping_creeps_do_not_push_each_other() -> void:
	var w: World = _world(true)
	_spawned(w)
	var camp: CampState = _first_camp(w)
	if camp.unit_ids.size() < 2:
		fail("cần trại có ≥ 2 quái")
		return
	var a: Entity = w.find_entity(camp.unit_ids[0])
	var b: Entity = w.find_entity(camp.unit_ids[1])
	b.position = a.position + Vector2(5, 0)
	_steps(w, 3)
	assert_near(a.position.distance_to(b.position), 5.0, 0.01, "đang ngủ: không đẩy tách")
	_hero(w, 0, camp.center + Vector2(300, 0))
	_steps(w, 10)
	assert_true(a.position.distance_to(b.position) > 5.0, "thức: đẩy tách như MOV-04")
