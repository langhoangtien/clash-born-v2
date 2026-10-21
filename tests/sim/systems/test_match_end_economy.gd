extends TestCase
## M2.5: STR-05 (phá nhà chính → thua, trận dừng), ECO-01 (last hit, vàng thụ động), ECO-07 (vàng trụ).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(structures: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	if structures:
		MatchSetup.spawn_structures(w, _lib)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5


func _hit(w: World, source_id: int, target: Entity, amount: float = 1.0e9) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source_id
	r.target_id = target.id
	r.raw = amount
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)


func _structure(w: World, structure_id: StringName) -> Entity:
	for e: Entity in w.entities:
		if e.structure_id == structure_id:
			return e
	return null


func _brakk(w: World, team: int, at: Vector2) -> Entity:
	var h: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, at)
	h.gold = 0  # đo vàng kiếm được, bỏ vàng khởi đầu (D-106)
	return h


func test_STR_05_core_destroyed_ends_match_and_sim_stops() -> void:
	var w: World = _world(true)
	var core: Entity = _structure(w, &"core_1")
	core.locked = false
	_hit(w, -1, core)
	w.step()
	assert_eq(w.winner, 0, "Red mất nhà chính → Blue thắng")
	assert_true(w.events.any(func(ev: GameEvent) -> bool: return ev.type == &"match_ended"))
	var tick: int = w.tick
	var hash_before: PackedByteArray = w.state_hash()
	for t: int in range(10):
		w.step()
	assert_eq(w.tick, tick, "trận đã xong thì không chạy nữa")
	assert_eq(w.state_hash(), hash_before)


func test_STR_05_no_winner_while_cores_stand() -> void:
	var w: World = _world(true)
	_hit(w, -1, _structure(w, &"blue_mid_t1"))
	w.step()
	assert_eq(w.winner, -1)


func test_ECO_01_last_hit_gives_bounty_to_killer_only() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	var ally: Entity = _brakk(w, 0, _center() + Vector2(0, 200))
	var creep: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_ranged", 1, "MID", _center() + Vector2(150, 0))
	_hit(w, ally.id, creep, 200.0)
	w.step()
	assert_eq(ally.gold, 0, "gây sát thương mà không kết liễu thì không có vàng")
	_hit(w, me.id, creep)
	w.step()
	assert_eq(me.gold, 45)
	assert_eq(me.last_hits, 1)
	assert_eq(ally.gold, 0)


func test_ECO_01_creep_or_tower_kill_gives_no_gold() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	var mine: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 0, "MID", _center() + Vector2(-150, 0))
	var creep: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 1, "MID", _center() + Vector2(150, 0))
	_hit(w, mine.id, creep)
	w.step()
	assert_eq(me.gold, 0)
	assert_eq(me.last_hits, 0)


func test_ECO_01_passive_gold_every_interval_even_when_dead() -> void:
	var w: World = _world()
	var me: Entity = _brakk(w, 0, _center())
	var every: int = SimClock.seconds_to_ticks(w.balance.passive_gold_interval)
	assert_eq(every, 60)
	for t: int in range(every - 1):
		w.step()
	assert_eq(me.gold, 0)
	w.step()
	assert_eq(me.gold, 1)
	_hit(w, -1, me)
	for t: int in range(every):
		w.step()
	assert_false(me.alive)
	assert_eq(me.gold, 1, "chết mất 25 × cấp (còn 0, ECO-05) rồi vẫn nhận vàng thụ động")


func test_ECO_07_tower_gold_to_every_enemy_hero_whoever_kills() -> void:
	var w: World = _world(true)
	var blue: Entity = _brakk(w, 0, _center())
	var red: Entity = _brakk(w, 1, _center() + Vector2(300, -300))
	_hit(w, -1, _structure(w, &"red_mid_t1"))
	w.step()
	assert_eq(blue.gold, 150)
	assert_eq(red.gold, 0)
	assert_eq(blue.last_hits, 0, "trụ không tính last hit")


func test_D_53_bounties_from_content() -> void:
	if _lib == null:
		_world()
	assert_eq(_lib.units[&"creep_melee"].bounty_gold, 36)
	assert_eq(_lib.units[&"creep_siege"].bounty_gold, 70)
	assert_eq(_lib.units[&"tower_t4"].bounty_gold, 250)
	assert_eq(_lib.units[&"core"].bounty_gold, 0)
