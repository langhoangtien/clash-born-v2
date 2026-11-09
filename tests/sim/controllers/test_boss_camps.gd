extends TestCase
## D-307: trại boss (rồng, JGL-10..14) và trại khủng long.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(3, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	return w


## Trại boss thử, đặt tay ở chỗ trống giữa map (không phụ thuộc vị trí hang trên map).
func _boss_camp(w: World, kind: StringName, first: float, respawn: float) -> CampState:
	var src: CampDef = _lib.camps[kind]
	var def: CampDef = src.duplicate()
	def.first_spawn = first
	def.respawn = respawn
	var c: CampState = CampState.new()
	c.index = 0
	c.kind = kind
	c.def = def
	c.center = w.navigation(64.0).nearest_clear(_map.world_size() * 0.5)
	w.camps.append(c)
	w.add_system(JungleSpawner.new(), World.Phase.SPAWN)
	return c


func _kill(w: World, e: Entity, by: Entity) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = by.id
	r.target_id = e.id
	r.raw = 1.0e6
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)


func _to(w: World, seconds: float) -> void:
	while w.tick < SimClock.seconds_to_ticks(seconds):
		w.step()


func _alive(w: World, c: CampState) -> Array[Entity]:
	var out: Array[Entity] = []
	for id: int in c.unit_ids:
		var e: Entity = w.find_entity(id)
		if e != null and e.alive:
			out.append(e)
	return out


func test_JGL_10_boss_first_spawn_and_respawn_after_empty() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"dragon_ice", 2.0, 3.0)
	_to(w, 1.9)
	assert_eq(_alive(w, c).size(), 0, "chưa tới first_spawn")
	_to(w, 2.05)
	assert_eq(_alive(w, c).size(), 1, "xuất hiện ở first_spawn, không theo jungle_first_spawn")
	var hero: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, c.center + Vector2(900, 0))
	_kill(w, _alive(w, c)[0], hero)
	w.step()
	var dead_at: float = w.tick * SimClock.TICK_SECONDS
	_to(w, dead_at + 2.9)
	assert_eq(_alive(w, c).size(), 0, "chưa đủ `respawn` giây sau khi trống")
	_to(w, dead_at + 3.1)
	assert_eq(_alive(w, c).size(), 1, "hồi lại sau `respawn` giây")


func test_JGL_10_dragon_content_first_spawn_and_respawn() -> void:
	_world()
	for kind: StringName in [&"dragon_ice", &"dragon_fire"]:
		var d: CampDef = _lib.camps[kind]
		assert_eq(d.first_spawn, 300.0, "%s: phút 5" % kind)
		assert_eq(d.respawn, 300.0, "%s: 5 phút sau khi hạ" % kind)
	var dino: CampDef = _lib.camps[&"dino"]
	assert_eq(dino.units.map(func(u: UnitDef) -> StringName: return u.id), [&"dino_big", &"dino_small", &"dino_small"])
	assert_true(dino.units[0].stats.base_hp > _lib.camps[&"large"].units[0].stats.base_hp, "bãi mạnh hơn bãi lớn")


func test_JGL_11_team_reward_every_hero_of_killer_team() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"dragon_fire", 0.1, 300.0)
	_to(w, 0.2)
	var dragon: Entity = _alive(w, c)[0]
	var killer: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, c.center + Vector2(150, 0))
	var far: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 0, w.map.fountain_point(0))
	var dead: Entity = UnitFactory.hero(w, _lib.heroes[&"vexa"], 0, w.map.fountain_point(0))
	dead.alive = false
	dead.respawn_tick = w.tick + 9999
	var foe: Entity = UnitFactory.hero(w, _lib.heroes[&"noctis"], 1, c.center + Vector2(-150, 0))
	var before: Array[int] = [killer.gold, far.gold, dead.gold, foe.gold]
	var foe_gold: int = foe.gold
	var ref: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 1, w.map.fountain_point(1))
	_kill(w, dragon, killer)
	w.step()
	var d: UnitDef = _lib.camps[&"dragon_fire"].units[0]
	assert_eq(killer.gold - before[0], d.team_gold + d.bounty_gold, "kẻ hạ: thưởng đội + vàng kết liễu")
	assert_eq(far.gold - before[1], d.team_gold, "ở xa vẫn nhận")
	assert_eq(dead.gold - before[2], d.team_gold, "đang chết vẫn nhận")
	assert_eq(foe.gold - before[3], 0, "phe kia không nhận")
	Progression.add_xp(w, ref, float(d.team_xp))
	assert_eq([far.stats.level(), far.xp], [ref.stats.level(), ref.xp], "mỗi người đủ team_xp")


func test_JGL_12_growth_stacks_by_minute_and_heals_the_gain() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"dragon_ice", 0.1, 300.0)
	_to(w, 0.2)
	var dragon: Entity = _alive(w, c)[0]
	var base_hp: float = dragon.stats.get_stat(StatId.Id.MAX_HP)
	assert_near(base_hp, 4500.0, 0.01, "phút 0: chưa mạnh thêm")
	_to(w, 60.1)
	assert_near(dragon.stats.get_stat(StatId.Id.MAX_HP), base_hp + 120.0, 0.01, "phút 1: 1 tầng")
	assert_near(dragon.health, base_hp + 120.0, 0.01, "máu hiện tại tăng đúng phần máu tối đa tăng")
	_to(w, 180.1)
	assert_near(dragon.stats.get_stat(StatId.Id.MAX_HP), base_hp + 360.0, 0.01, "phút 3: 3 tầng")
	assert_near(dragon.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), 75.0 + 12.0, 0.01)


func test_JGL_12_late_spawn_starts_with_minutes_stacks() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"dragon_fire", 600.0, 300.0)
	_to(w, 600.1)
	var dragon: Entity = _alive(w, c)[0]
	assert_near(dragon.stats.get_stat(StatId.Id.MAX_HP), 5000.0 + 10 * 140.0, 0.01, "sinh ở phút 10: 10 tầng")
	assert_near(dragon.health, dragon.stats.get_stat(StatId.Id.MAX_HP), 0.01, "sinh ra đầy máu")


func test_JGL_13_passives_attached_on_spawn() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"dragon_ice", 0.1, 300.0)
	_to(w, 0.2)
	var ids: Array = _alive(w, c)[0].effects.map(func(i: EffectInstance) -> StringName: return i.def.id)
	assert_true(ids.has(&"dragon_ice_passive"), "đòn đánh làm chậm gắn lúc sinh")
	var fire: Entity = UnitFactory.unit(w, _lib.camps[&"dragon_fire"].units[0], Entity.Kind.NEUTRAL, 2, Vector2(100, 100))
	assert_eq(fire.effects.size(), 0, "UnitFactory không tự gắn: JungleSpawner gắn khi sinh trại")


func test_JGL_13_fire_burn_damages_over_time_and_ice_slows() -> void:
	var w: World = _world()
	var dragon: Entity = UnitFactory.unit(w, _lib.camps[&"dragon_fire"].units[0], Entity.Kind.NEUTRAL, 2, Vector2(100, 100))
	var hero: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, w.map.fountain_point(0) + Vector2(2000, -2000))
	var hp: float = hero.health
	Effects.apply(w, hero, load("res://content/effects/dragon_fire_burn.tres") as EffectDef, dragon)
	for i: int in SimClock.seconds_to_ticks(3.2):
		w.step()
	assert_true(hp - hero.health > 30.0, "đốt máu suốt 3 s (mất %.0f)" % (hp - hero.health))
	assert_eq(hero.effects.size(), 0, "hết 3 s thì hết đốt")
	var speed: float = hero.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	Effects.apply(w, hero, load("res://content/effects/dragon_ice_slow.tres") as EffectDef, dragon)
	hero.stats.recompute()
	assert_near(hero.stats.get_stat(StatId.Id.MOVEMENT_SPEED), speed * 0.7, 1.0, "Rồng Băng làm chậm 30%")
