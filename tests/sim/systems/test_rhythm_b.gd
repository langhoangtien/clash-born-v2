extends TestCase
## D-274: nhịp theo tình huống (phương án B) — trụ rảnh quét thưa (STR-06), lính giao tranh nghĩ thưa (CRP-14),
## lính đẩy tách mỗi creep_separation_ticks (MOV-08), trại ngủ xét lại thưa + tầm nhìn lên quái ngủ (JGL-09).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(structures: bool, jungle: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	if structures:
		MatchSetup.spawn_structures(w, _lib)
	if jungle:
		MatchSetup.add_vision(w)
		MatchSetup.add_jungle(w, _lib)
	return w


func _unit(w: World, team: int, kind: Entity.Kind, at: Vector2, radius: float = 24.0) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = radius
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 5000)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.VISION_RANGE, 1200)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	return w.add_entity(e)


func _tower(w: World) -> Entity:
	for e: Entity in w.entities:
		if e.structure_id == &"red_mid_t1":
			return e
	return null


func test_STR_06_idle_tower_scans_every_idle_scan_time() -> void:
	var w: World = _world(true)
	var tower: Entity = _tower(w)
	var n: int = SimClock.seconds_to_ticks(w.balance.tower_idle_scan_time)
	while (w.tick + 1 + tower.id) % n != 1:  # tick vừa rồi là lượt quét
		w.step()
	_unit(w, 0, Entity.Kind.HERO, w.navigation(24.0).nearest_clear(tower.position + Vector2(250, 0)))
	for i: int in n - 2:
		w.step()
	assert_true(tower.order.type != Order.Type.ATTACK, "trụ rảnh chưa tới lượt quét: chưa thấy")
	for i: int in 3:
		w.step()
	assert_eq(tower.order.type, Order.Type.ATTACK, "tới lượt quét (≤ tower_idle_scan_time) thì nhắm")


func test_STR_06_target_lost_rescans_at_once() -> void:
	var w: World = _world(true)
	var tower: Entity = _tower(w)
	var a: Entity = _unit(w, 0, Entity.Kind.HERO, w.navigation(24.0).nearest_clear(tower.position + Vector2(250, 0)))
	for i: int in SimClock.seconds_to_ticks(w.balance.tower_idle_scan_time) + 2:
		w.step()
	assert_eq(tower.order.target_id, a.id)
	var b: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, w.navigation(24.0).nearest_clear(tower.position + Vector2(-300, 0)))
	a.position = tower.position + Vector2(3000, 0)
	w.step()
	w.step()
	assert_eq(tower.order.target_id, b.id, "mất mục tiêu: quét lại ngay, không chờ lượt")


func test_CRP_14_fighting_creep_thinks_every_fight_time() -> void:
	var n: int = SimClock.seconds_to_ticks(0.13)
	var due: Array[int] = []
	for t: int in range(1, 13):
		if LaneCreepController.think_due(t, 5, -1, n):
			due.append(t)
	assert_eq(due, [3, 7, 11], "giao tranh: mỗi creep_fight_think_time, so le theo id")
	assert_true(LaneCreepController.think_due(20, 5, 20, n), "đi đường (CRP-13): đúng tick hết chờ")
	assert_false(LaneCreepController.think_due(19, 5, 20, n))


func test_MOV_08_creeps_push_each_other_every_other_tick() -> void:
	var w: World = _world(false)
	var a: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, Vector2(4000, 4000))
	var b: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, Vector2(4010, 4000))
	if (w.tick + 1) % w.balance.creep_separation_ticks == 0:
		w.step()
	var d0: float = a.position.distance_to(b.position)
	w.step()  # tick lẻ
	assert_near(a.position.distance_to(b.position), d0, 0.001, "tick không phải lượt: lính không tự đẩy nhau")
	w.step()
	assert_true(a.position.distance_to(b.position) > d0, "tới lượt: đẩy tách (MOV-04)")


func test_MOV_08_hero_and_creep_push_every_tick() -> void:
	var w: World = _world(false)
	var creep: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, Vector2(4000, 4000))
	var hero: Entity = _unit(w, 0, Entity.Kind.HERO, Vector2(4010, 4000))  # hero id lớn hơn
	if (w.tick + 1) % w.balance.creep_separation_ticks == 0:
		w.step()
	var d0: float = creep.position.distance_to(hero.position)
	w.step()
	assert_true(creep.position.distance_to(hero.position) > d0, "cặp có hero: đẩy mỗi tick")


func _spawned(w: World) -> CampState:
	while w.tick < SimClock.seconds_to_ticks(w.balance.jungle_first_spawn) + 1:
		w.step()
	for c: CampState in w.camps:
		if not c.unit_ids.is_empty():
			return c
	return null


func test_JGL_09_sleep_rechecked_within_check_ticks() -> void:
	var w: World = _world(false, true)
	var camp: CampState = _spawned(w)
	var m: Entity = w.find_entity(camp.unit_ids[0])
	for i: int in w.balance.jungle_sleep_check_ticks:
		w.step()
	assert_true(m.asleep)
	_unit(w, 0, Entity.Kind.HERO, camp.center + Vector2(w.balance.jungle_sleep_radius - 60.0, 0))
	for i: int in w.balance.jungle_sleep_check_ticks:
		w.step()
	assert_false(m.asleep, "có người lại gần: thức trong ≤ jungle_sleep_check_ticks")


func test_JGL_09_sleeping_creep_seen_within_check_ticks() -> void:
	var w: World = _world(false, true)
	var camp: CampState = _spawned(w)
	var m: Entity = w.find_entity(camp.unit_ids[0])
	for i: int in w.balance.jungle_sleep_check_ticks:
		w.step()
	assert_eq(m.visible_mask & 1, 0, "chưa ai phe 0 thấy")
	var eye: Entity = _unit(w, 0, Entity.Kind.WARD, m.position + Vector2(700, 300))
	eye.stats.set_base(StatId.Id.VISION_RANGE, 1000)
	for i: int in w.balance.jungle_sleep_check_ticks + 1:
		w.step()
	assert_true(m.visible_mask & 1 != 0, "quái ngủ: tầm nhìn cập nhật trong ≤ jungle_sleep_check_ticks")


func test_CRP_14_chasing_creep_keeps_two_tick_rhythm() -> void:
	var w: World = _world(false)
	var c: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, Vector2(4000, 4000))
	var near: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2(4100, 4000))
	var far: Entity = _unit(w, 1, Entity.Kind.LANE_CREEP, Vector2(4900, 4000))
	var fight: int = SimClock.seconds_to_ticks(w.balance.creep_fight_think_time)
	c.order = Order.attack(near.id)
	assert_eq(LaneCreepController._cadence(w, c, fight), fight, "đứng đánh (trong tầm): nghĩ thưa")
	c.order = Order.attack(far.id)
	assert_eq(LaneCreepController._cadence(w, c, fight), LaneCreepController.CHASE_TICKS, "đang đuổi: nhịp D-108 để giữ leash / mép trước")
