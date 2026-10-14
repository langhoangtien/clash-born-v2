extends TestCase
## M2.4: ECO-04 (hero chết chờ rồi hồi sinh ở fountain), STR-04 (fountain hồi máu, bắn hero địch).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _kill(w: World, e: Entity) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = e.id
	r.raw = 1.0e9
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()


func _brakk(w: World, team: int, at: Vector2, level: int = 1) -> Entity:
	return UnitFactory.hero(w, _lib.heroes[&"brakk"], team, at, level)


func _center() -> Vector2:
	return _map.world_size() * 0.5


func test_ECO_04_dead_hero_waits_then_respawns_at_fountain() -> void:
	var w: World = _world()
	var hero: Entity = _brakk(w, 0, _center(), 3)
	var enemy: Entity = _brakk(w, 1, _center() + Vector2(100, 0))
	hero.lock_target_id = enemy.id
	_kill(w, hero)
	assert_false(hero.alive)
	assert_eq(w.find_entity(hero.id), hero, "hero chết vẫn ở trong trận")
	assert_false(Rules.is_targetable(enemy, hero))
	assert_eq(hero.lock_target_id, -1, "chết thì hết khóa")
	var wait: int = SimClock.seconds_to_ticks(w.balance.respawn_base + w.balance.respawn_per_level * 3)
	assert_eq(wait, 11 * 30)
	for t: int in range(wait - 1):
		w.step()
	assert_false(hero.alive, "chưa đủ thời gian")
	w.step()
	assert_true(hero.alive)
	assert_eq(hero.position, _map.fountain_point(0))
	assert_near(hero.health, hero.stats.get_stat(StatId.Id.MAX_HP), EPS)
	assert_near(hero.mana, hero.stats.get_stat(StatId.Id.MAX_MANA), EPS)
	assert_eq(hero.order.type, Order.Type.IDLE)


func test_ECO_04_events_and_dead_hero_does_not_block_or_move() -> void:
	var w: World = _world()
	var hero: Entity = _brakk(w, 0, _center())
	var other: Entity = _brakk(w, 1, _center() + Vector2(10, 0))
	hero.health = 1.0
	var seen: Array[StringName] = []
	_kill(w, hero)
	for ev: GameEvent in w.events:
		seen.append(ev.type)
	assert_true(seen.has(&"hero_died"))
	var spot: Vector2 = hero.position
	var before: Vector2 = other.position
	for t: int in range(10):
		w.step()
	assert_eq(hero.position, spot, "xác không bị đẩy")
	assert_eq(other.position, before, "xác không đẩy ai")
	for t: int in range(SimClock.seconds_to_ticks(7.0)):
		w.step()
		for ev: GameEvent in w.events:
			seen.append(ev.type)
	assert_true(seen.has(&"hero_respawned"))


func test_ECO_04_creeps_still_removed_on_death() -> void:
	var w: World = _world()
	var creep: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "MID", _center())
	_kill(w, creep)
	assert_eq(w.find_entity(creep.id), null)


func test_STR_04_fountain_heals_own_units_five_percent_per_second() -> void:
	var w: World = _world()
	var hero: Entity = _brakk(w, 0, _map.fountain_point(0))
	var max_hp: float = hero.stats.get_stat(StatId.Id.MAX_HP)
	var max_mana: float = hero.stats.get_stat(StatId.Id.MAX_MANA)
	hero.health = max_hp * 0.5
	hero.mana = 0.0
	for t: int in range(30):
		w.step()
	assert_near(hero.health, max_hp * 0.55, 0.5)
	assert_near(hero.mana, max_mana * 0.05, 0.5)
	for t: int in range(30 * 20):
		w.step()
	assert_near(hero.health, max_hp, EPS, "không quá máu tối đa")


func test_STR_04_no_heal_outside_radius_or_for_enemies() -> void:
	var w: World = _world()
	var f: Vector2 = _map.fountain_point(0)
	var outside: Entity = _brakk(w, 0, w.navigation(24.0).nearest_clear(f + Vector2(1, -1).normalized() * (w.balance.fountain_radius + 60.0)))
	outside.health = 100.0
	for t: int in range(30):
		w.step()
	assert_near(outside.health, 100.0, EPS)


func test_STR_04_fountain_shoots_enemy_heroes_in_radius() -> void:
	var w: World = _world()
	var f: Vector2 = _map.fountain_point(1)
	var enemy: Entity = _brakk(w, 0, f + Vector2(-100, 100))
	var hp: float = enemy.health
	enemy.stats.set_base(StatId.Id.MAX_HP, 5000)
	enemy.stats.recompute()
	enemy.health = 5000.0
	var shots: int = 0
	for t: int in range(60):
		w.step()
		for ev: GameEvent in w.events:
			shots += int(ev.type == &"fountain_shot" and ev.target_id == enemy.id)
	assert_eq(shots, 2, "mỗi giây một phát")
	assert_near(enemy.health, 5000.0 - 2.0 * w.balance.fountain_damage, EPS, "sát thương thuần")
	assert_true(hp > 0.0)


func test_STR_04_fountain_kills_and_hero_respawns_home() -> void:
	var w: World = _world()
	var enemy: Entity = _brakk(w, 0, _map.fountain_point(1) + Vector2(-100, 100))
	for t: int in range(30 * 4):
		w.step()
	assert_false(enemy.alive, "Brakk cấp 1 không trụ nổi 4 giây ở fountain địch")
	for t: int in range(30 * 7):
		w.step()
	assert_true(enemy.alive)
	assert_eq(enemy.position, _map.fountain_point(0))
