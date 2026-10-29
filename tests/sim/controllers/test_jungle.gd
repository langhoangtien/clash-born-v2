extends TestCase
## M5.5: trại rừng (JGL-01..07), kéo quái (pull, D-76).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(lanes: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(3, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	if lanes:
		MatchSetup.add_lane_creeps(w, _lib, false)
	MatchSetup.add_jungle(w, _lib)
	return w


func _spawned(w: World) -> void:
	while w.tick < SimClock.seconds_to_ticks(w.balance.jungle_first_spawn):
		w.step()


func _camp(w: World, id: String) -> CampState:
	for c: CampState in w.camps:
		if w.map.camp_ids[c.index] == id:
			return c
	return null


func _members(w: World, c: CampState) -> Array[Entity]:
	var out: Array[Entity] = []
	for id: int in c.unit_ids:
		var e: Entity = w.find_entity(id)
		if e != null and e.alive:
			out.append(e)
	return out


func _hero(w: World, team: int, at: Vector2) -> Entity:
	return UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(at))


func _hit(w: World, source: Entity, target: Entity, amount: float) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target.id
	r.raw = amount
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func test_JGL_05_06_first_spawn_by_kind() -> void:
	var w: World = _world()
	_steps(w, SimClock.seconds_to_ticks(w.balance.jungle_first_spawn) - 2)
	assert_eq(w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.NEUTRAL).size(), 0, "chưa tới giây 30")
	_spawned(w)
	assert_eq(w.camps.size(), 16, "MAP-02: 8 trại mỗi phe, không boss (D-178)")
	var sizes: Dictionary = {&"small": 2, &"medium": 2, &"large": 3}
	for c: CampState in w.camps:
		var m: Array[Entity] = _members(w, c)
		assert_eq(m.size(), sizes[c.kind], "trại %s" % c.kind)
		for e: Entity in m:
			assert_eq(e.team, 2)
			assert_true(e.position.distance_to(c.center) < 150.0)
			assert_true(w.navigation(e.radius).point_is_clear(e.position))


func test_JGL_03_04_idle_never_starts_a_fight() -> void:
	var w: World = _world()
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_03")
	var hero: Entity = _hero(w, 0, c.center + Vector2(120, 0))
	var hp: float = hero.health
	_steps(w, 150)
	assert_near(hero.health, hp, 0.5, "đứng cạnh trại không bị đánh")
	for e: Entity in _members(w, c):
		assert_eq(e.order.type, Order.Type.IDLE)


func test_JGL_01_whole_camp_attacks_latest_attacker() -> void:
	var w: World = _world()
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_01")
	var a: Entity = _hero(w, 0, c.center + Vector2(200, 0))
	var b: Entity = _hero(w, 1, c.center + Vector2(-200, 0))
	var m: Array[Entity] = _members(w, c)
	_hit(w, a, m[0], 10.0)
	_steps(w, 3)
	assert_eq(c.target_id, a.id)
	for e: Entity in m:
		assert_eq(e.order.target_id, a.id, "cả trại đánh kẻ gây sát thương")
	_hit(w, b, m[1], 10.0)
	_steps(w, 3)
	assert_eq(c.target_id, b.id, "đổi sang kẻ đánh gần đây nhất")


func test_JGL_01_02_leash_return_heal_and_ignore_hits() -> void:
	var w: World = _world()
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_01")
	var hero: Entity = _hero(w, 0, c.center + Vector2(200, 0))
	var m: Array[Entity] = _members(w, c)
	_hit(w, hero, m[0], 100.0)
	_steps(w, 3)
	hero.position = w.navigation(32.0).nearest_clear(c.center + Vector2(900, 0))
	_steps(w, 2)
	assert_true(c.returning, "mục tiêu ra ngoài 600 từ tâm trại thì về")
	_hit(w, hero, m[1], 10.0)
	_steps(w, 2)
	assert_eq(c.target_id, -1, "đang về thì không nhận mục tiêu")
	for i: int in range(300):
		w.step()
		if not c.returning:
			break
	assert_false(c.returning)
	for e: Entity in _members(w, c):
		assert_near(e.health, e.stats.get_stat(StatId.Id.MAX_HP), EPS, "về tới nơi thì hồi đầy máu")


func test_JGL_01_gives_up_after_aggro_time() -> void:
	var w: World = _world()
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_02")
	var hero: Entity = _hero(w, 0, c.center + Vector2(250, 0))
	hero.stats.set_base(StatId.Id.MAX_HP, 100000)
	hero.stats.recompute()
	hero.health = 100000.0
	_hit(w, hero, _members(w, c)[0], 10.0)
	_steps(w, 3)
	assert_eq(c.target_id, hero.id)
	_steps(w, SimClock.seconds_to_ticks(w.balance.jungle_aggro_time) + 2)
	assert_true(c.returning or c.target_id == -1, "5 s không bị đánh thì bỏ")


func test_JGL_05_respawn_only_when_empty_and_clear() -> void:
	var w: World = _world()
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_03")
	var killer: Entity = _hero(w, 0, c.center + Vector2(600, 0))
	for e: Entity in _members(w, c):
		_hit(w, killer, e, 10000.0)
	_steps(w, 2)
	assert_eq(_members(w, c).size(), 0)
	var guard: Entity = _hero(w, 1, c.center + Vector2(100, 0))
	var next_check: int = SimClock.seconds_to_ticks(w.balance.jungle_first_spawn + w.balance.jungle_respawn_check)
	_steps(w, next_check - w.tick + 1)
	assert_eq(_members(w, c).size(), 0, "có người đứng trong 300 quanh tâm thì không hồi")
	guard.position = c.center + Vector2(900, 0)
	_steps(w, SimClock.seconds_to_ticks(w.balance.jungle_respawn_check))
	assert_eq(_members(w, c).size(), 2, "trống và không ai đứng gần thì hồi ở lần kiểm tra sau")


func test_JGL_07_rewards_hero_and_creep_kills() -> void:
	var w: World = _world()
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_03")
	var me: Entity = _hero(w, 0, c.center + Vector2(200, 0))
	var mate: Entity = _hero(w, 0, c.center + Vector2(300, 100))
	var enemy: Entity = _hero(w, 1, c.center + Vector2(-300, 0))
	var m: Array[Entity] = _members(w, c)
	var gold: int = me.gold
	_hit(w, me, m[0], 10000.0)
	_steps(w, 2)
	assert_eq(me.gold - gold, 30, "hero kết liễu: vàng của Sói con")
	assert_eq(me.last_hits, 1)
	assert_true(mate.xp > 0.0 and enemy.xp == 0.0, "XP cho hero cùng phe kẻ hạ")
	var creep: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "BOT", c.center + Vector2(150, 0))
	var mate_xp: float = mate.xp
	var all_gold: int = me.gold + mate.gold + enemy.gold
	_hit(w, creep, m[1], 10000.0)
	_steps(w, 2)
	assert_eq(me.gold + mate.gold + enemy.gold, all_gold, "lính hạ: không ai được vàng")
	assert_true(mate.xp > mate_xp and enemy.xp == 0.0, "XP cho hero phe của lính")


func test_D_76_lane_creeps_and_attack_buttons_target_neutrals() -> void:
	var w: World = _world(true)
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_03")
	var m: Array[Entity] = _members(w, c)
	var hero: Entity = _hero(w, 0, c.center + Vector2(150, 0))
	hero.stats.set_base(StatId.Id.ATTACK_RANGE, 300)
	hero.stats.recompute()
	assert_true(m.has(w.find_entity(Rules.pick_attack_target(w, hero, Rules.AttackMode.CREEP))), "nút Lính chọn quái")
	var creep: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 1, "TOP", c.center + Vector2(-250, 0))
	var fought: bool = false
	var answered: bool = false
	for i: int in range(150):
		w.step()
		for ev: GameEvent in w.events:
			fought = fought or (ev.type == &"damage_taken" and ev.source_id == creep.id and m.any(func(e: Entity) -> bool: return e.id == ev.target_id))
			answered = answered or (ev.type == &"damage_taken" and ev.target_id == creep.id)
	assert_true(fought, "lính đường đánh quái trong tầm tìm")
	assert_true(answered, "quái đánh lại lính đường")


func test_D_76_pull_camp_6_into_passing_wave() -> void:
	var w: World = _world(true)
	MatchSetup.spawn_structures(w, _lib)
	_spawned(w)
	var c: CampState = _camp(w, "camp_blue_06")
	var route: LaneRoute = LaneRoute.of(w, "BOT", 0)
	var lane: Vector2 = route.point_at(route.progress_of(c.center))
	# Pull: đánh trại rồi lùi theo lối đi ra lane, dừng khi cách tâm trại 560 (trong leash 600).
	var nav: MapNavigation = w.navigation(32.0)
	var path: PackedVector2Array = nav.path(c.center, nav.nearest_clear(lane))
	var spot: Vector2 = path[0]
	for i: int in range(path.size() - 1):
		var step: Vector2 = path[i]
		while step.distance_to(path[i + 1]) > 8.0 and step.distance_to(c.center) < 560.0:
			step = step.move_toward(path[i + 1], 8.0)
		spot = step
		if step.distance_to(c.center) >= 560.0:
			break
	var hero: Entity = _hero(w, 0, c.center.lerp(spot, 0.4))
	var creeps: Array[Entity] = []
	var back: float = route.progress_of(spot) - 450.0
	for k: int in range(3):
		creeps.append(MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "BOT", route.point_at(back - 40.0 * k)))
	_hit(w, hero, _members(w, c)[0], 10.0)
	w.submit(Command.move_to(hero.id, spot))
	var fought: bool = false
	var answered: bool = false
	for i: int in range(30 * 20):
		w.step()
		for ev: GameEvent in w.events:
			var t: Entity = w.find_entity(ev.target_id)
			var s: Entity = w.find_entity(ev.source_id)
			if ev.type == &"damage_taken" and t != null and s != null:
				fought = fought or (t.kind == Entity.Kind.NEUTRAL and creeps.has(s))
				answered = answered or (s.kind == Entity.Kind.NEUTRAL and creeps.has(t))
	assert_true(fought, "quái đuổi hero tới miệng lối ra lane, lính lao vào đánh quái")
	assert_true(answered, "quái quay sang đánh lính")
	for i: int in range(30 * 90):
		if _members(w, c).is_empty() or not creeps.any(func(e: Entity) -> bool: return e.alive):
			break
		w.step()
	_steps(w, 30 * 10)
	for e: Entity in creeps:
		if e.alive:
			assert_true(route.distance_to_route(e.position) < 400.0, "đánh xong thì lính về lane (cách %d, lệnh %d → %d, về %s, quái còn %d)" % [route.distance_to_route(e.position), e.order.type, e.order.target_id, e.returning, _members(w, c).size()])


func test_D_30_camps_in_hash() -> void:
	var w: World = _world()
	_spawned(w)
	var h: PackedByteArray = w.state_hash()
	w.camps[0].aggro_until_tick += 1
	assert_true(w.state_hash() != h)
