extends TestCase
## M2.2: STR-01 (trụ chọn mục tiêu), STR-02 (khóa), CMB-04 (hệ số lên công trình), D-47.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	return w


func _structure(w: World, structure_id: StringName) -> Entity:
	for e: Entity in w.entities:
		if e.structure_id == structure_id:
			return e
	return null


func _unit(w: World, team: int, kind: Entity.Kind, at: Vector2, damage: float = 50.0) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 5000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, damage)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 0)
	return w.add_entity(e)


func _destroy(w: World, s: Entity) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = s.id
	r.raw = 1.0e9
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()


## Điểm trong tầm trụ, cách tâm trụ `distance`, theo hướng `angle`, đứng được.
func _near(w: World, tower: Entity, distance: float, angle: float = 0.0) -> Vector2:
	return w.navigation(24.0).nearest_clear(tower.position + Vector2.from_angle(angle) * distance)


func test_D_47_structures_spawn_from_content_and_map() -> void:
	var w: World = _world()
	var towers: Array = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.TOWER)
	var cores: Array = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.CORE)
	assert_eq(towers.size(), 22)
	assert_eq(cores.size(), 2)
	var t1: Entity = _structure(w, &"blue_mid_t1")
	assert_eq(t1.position, _map.tower_point("blue_mid_t1"))
	assert_near(t1.health, 1800.0, EPS)
	assert_near(t1.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), 10.0, EPS)
	assert_near(_structure(w, &"core_1").health, 4000.0, EPS)


func test_STR_02_t1_open_t2_locked_until_t1_falls() -> void:
	var w: World = _world()
	var red_hero: Entity = _unit(w, 1, Entity.Kind.HERO, Vector2.ZERO)
	var t1: Entity = _structure(w, &"blue_mid_t1")
	var t2: Entity = _structure(w, &"blue_mid_t2")
	assert_true(Rules.is_targetable(red_hero, t1))
	assert_false(Rules.is_targetable(red_hero, t2), "T2 khóa khi T1 còn")
	_destroy(w, t1)
	assert_true(Rules.is_targetable(red_hero, t2), "T1 đổ → T2 mở")


func test_STR_02_locked_structure_takes_no_damage() -> void:
	var w: World = _world()
	var t2: Entity = _structure(w, &"blue_mid_t2")
	_destroy(w, t2)
	assert_true(t2.alive, "T2 đang khóa không nhận sát thương")
	assert_near(t2.health, 2200.0, EPS)


func test_STR_02_t4_opens_when_any_t3_falls_core_when_both_t4_fall() -> void:
	var w: World = _world()
	var blue_hero: Entity = _unit(w, 0, Entity.Kind.HERO, Vector2.ZERO)
	var t4s: Array = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.TOWER and e.team == 1 and e.tier == 4)
	assert_eq(t4s.size(), 2)
	var core: Entity = _structure(w, &"core_1")
	for lane: String in ["mid", "top"]:
		for tier: int in [1, 2]:
			_destroy(w, _structure(w, StringName("red_%s_t%d" % [lane, tier])))
	assert_false(Rules.is_targetable(blue_hero, t4s[0]))
	_destroy(w, _structure(w, &"red_mid_t3"))
	assert_true(Rules.is_targetable(blue_hero, t4s[0]) and Rules.is_targetable(blue_hero, t4s[1]), "một T3 đổ → cả hai T4 mở")
	assert_false(Rules.is_targetable(blue_hero, core))
	_destroy(w, t4s[0])
	assert_false(Rules.is_targetable(blue_hero, core), "nhà chính cần cả hai T4 đổ")
	_destroy(w, t4s[1])
	assert_true(Rules.is_targetable(blue_hero, core))


func test_STR_02_destroyed_structure_emits_event_and_is_removed() -> void:
	var w: World = _world()
	var t1: Entity = _structure(w, &"red_bot_t1")
	_destroy(w, t1)
	assert_eq(w.find_entity(t1.id), null)
	assert_true(w.events.any(func(e: GameEvent) -> bool: return e.type == &"structure_destroyed" and e.target_id == t1.id))


func test_CMB_04_hero_deals_half_damage_to_structures() -> void:
	var w: World = _world()
	var t1: Entity = _structure(w, &"red_mid_t1")
	var hero: Entity = _unit(w, 0, Entity.Kind.HERO, _near(w, t1, 52 + 24 + 100), 100.0)
	w.submit(Command.attack(hero.id, t1.id))
	for t: int in range(12):
		w.step()
	assert_near(t1.health, 1800.0 - 100.0 / (1.0 + 0.06 * 10.0) * 0.5, EPS)


func test_STR_01_creep_before_hero() -> void:
	var w: World = _world()
	var tower: Entity = _structure(w, &"red_mid_t1")
	var hero: Entity = _unit(w, 0, Entity.Kind.HERO, _near(w, tower, 250, 0.0))
	var creep: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, _near(w, tower, 450, PI))
	w.step()
	w.step()
	assert_eq(tower.order.target_id, creep.id, "lính trước hero dù hero gần hơn")


func test_STR_01_hero_only_when_no_creep() -> void:
	var w: World = _world()
	var tower: Entity = _structure(w, &"red_mid_t1")
	var hero: Entity = _unit(w, 0, Entity.Kind.HERO, _near(w, tower, 250))
	w.step()
	w.step()
	assert_eq(tower.order.target_id, hero.id)
	var hp: float = hero.health
	for t: int in range(40):
		w.step()
	assert_true(hero.health < hp, "trụ bắn trúng hero")


func test_STR_01_keeps_current_target_in_range() -> void:
	var w: World = _world()
	var tower: Entity = _structure(w, &"red_mid_t1")
	var hero: Entity = _unit(w, 0, Entity.Kind.HERO, _near(w, tower, 250))
	w.step()
	w.step()
	_unit(w, 0, Entity.Kind.LANE_CREEP, _near(w, tower, 300, PI))
	for t: int in range(5):
		w.step()
	assert_eq(tower.order.target_id, hero.id, "giữ mục tiêu khi còn trong tầm")


func test_STR_01_defends_hero_attacked_under_tower() -> void:
	var w: World = _world()
	var tower: Entity = _structure(w, &"red_mid_t1")
	var creep: Entity = _unit(w, 0, Entity.Kind.LANE_CREEP, _near(w, tower, 300, PI))
	w.step()
	w.step()
	assert_eq(tower.order.target_id, creep.id)
	var victim: Entity = _unit(w, 1, Entity.Kind.HERO, _near(w, tower, 350, 0.0))
	var bully: Entity = _unit(w, 0, Entity.Kind.HERO, victim.position + Vector2(60, 0), 30.0)
	bully.position = w.navigation(24.0).nearest_clear(bully.position)
	w.submit(Command.attack(bully.id, victim.id))
	for t: int in range(14):
		w.step()
	assert_eq(tower.order.target_id, bully.id, "hero đánh hero phe trụ → trụ chuyển sang hero đó")


func test_STR_01_target_leaving_range_is_dropped() -> void:
	var w: World = _world()
	var tower: Entity = _structure(w, &"red_mid_t1")
	var hero: Entity = _unit(w, 0, Entity.Kind.HERO, _near(w, tower, 250))
	w.step()
	w.step()
	hero.position = _near(w, tower, 1200)
	w.step()
	w.step()
	assert_true(tower.order.type != Order.Type.ATTACK or tower.order.target_id != hero.id or tower.order.finished)


func test_towers_never_move_or_get_pushed() -> void:
	var w: World = _world()
	var tower: Entity = _structure(w, &"red_mid_t1")
	var at: Vector2 = tower.position
	_unit(w, 0, Entity.Kind.HERO, at)
	for t: int in range(30):
		w.step()
	assert_eq(tower.position, at)


func test_D_30_tower_fight_replays_identically() -> void:
	var hashes: Array[PackedByteArray] = []
	for run: int in range(2):
		var w: World = _world()
		var tower: Entity = _structure(w, &"red_mid_t1")
		var hero: Entity = _unit(w, 0, Entity.Kind.HERO, _near(w, tower, 300), 120.0)
		hero.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
		w.submit(Command.attack(hero.id, tower.id))
		for t: int in range(150):
			w.step()
			if run == 0:
				hashes.append(w.state_hash())
			elif w.state_hash() != hashes[t]:
				fail("lệch ở tick %d" % w.tick)
				return
