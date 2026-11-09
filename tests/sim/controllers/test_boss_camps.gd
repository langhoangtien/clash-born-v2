extends TestCase
## D-307: trại boss (rồng → D-309 người đá, JGL-10..14) và trại tê giác (D-307b: thay trại khủng long).

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
	var c: CampState = _boss_camp(w, &"golem_moss", 2.0, 3.0)
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


func test_JGL_10_boss_content_first_spawn_and_respawn() -> void:
	_world()
	for kind: StringName in [&"golem_moss", &"golem_lava"]:
		var d: CampDef = _lib.camps[kind]
		assert_eq(d.first_spawn, 300.0, "%s: phút 5" % kind)
		assert_eq(d.respawn, 300.0, "%s: 5 phút sau khi hạ" % kind)
	var beast: CampDef = _lib.camps[&"beast"]
	assert_eq(beast.units.map(func(u: UnitDef) -> StringName: return u.id), [&"rhino", &"rhino_small", &"rhino_small"], "D-307c: 1 tê giác to + 2 tê giác con")
	assert_true(beast.units[0].stats.base_hp > _lib.camps[&"large"].units[0].stats.base_hp, "bãi mạnh hơn bãi lớn")


func test_JGL_11_team_reward_every_hero_of_killer_team() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"golem_lava", 0.1, 300.0)
	_to(w, 0.2)
	var boss: Entity = _alive(w, c)[0]
	var killer: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, c.center + Vector2(150, 0))
	var far: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 0, w.map.fountain_point(0))
	var dead: Entity = UnitFactory.hero(w, _lib.heroes[&"vexa"], 0, w.map.fountain_point(0))
	dead.alive = false
	dead.respawn_tick = w.tick + 9999
	var foe: Entity = UnitFactory.hero(w, _lib.heroes[&"noctis"], 1, c.center + Vector2(-150, 0))
	var before: Array[int] = [killer.gold, far.gold, dead.gold, foe.gold]
	var foe_gold: int = foe.gold
	var ref: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 1, w.map.fountain_point(1))
	_kill(w, boss, killer)
	w.step()
	var d: UnitDef = _lib.camps[&"golem_lava"].units[0]
	assert_eq(killer.gold - before[0], d.team_gold + d.bounty_gold, "kẻ hạ: thưởng đội + vàng kết liễu")
	assert_eq(far.gold - before[1], d.team_gold, "ở xa vẫn nhận")
	assert_eq(dead.gold - before[2], d.team_gold, "đang chết vẫn nhận")
	assert_eq(foe.gold - before[3], 0, "phe kia không nhận")
	Progression.add_xp(w, ref, float(d.team_xp))
	assert_eq([far.stats.level(), far.xp], [ref.stats.level(), ref.xp], "mỗi người đủ team_xp")


func test_JGL_12_growth_stacks_by_minute_and_heals_the_gain() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"golem_moss", 0.1, 300.0)
	_to(w, 0.2)
	var boss: Entity = _alive(w, c)[0]
	var base_hp: float = boss.stats.get_stat(StatId.Id.MAX_HP)
	var def: UnitDef = _lib.camps[&"golem_moss"].units[0]
	var per: float = _growth_hp(def)  # D-318: số lấy từ content (cân bằng đổi không phải sửa test)
	assert_near(base_hp, def.stats.base_hp, 0.01, "phút 0: chưa mạnh thêm")
	_to(w, 60.1)
	assert_near(boss.stats.get_stat(StatId.Id.MAX_HP), base_hp + per, 0.01, "phút 1: 1 tầng")
	assert_near(boss.health, base_hp + per, 0.01, "máu hiện tại tăng đúng phần máu tối đa tăng")
	_to(w, 180.1)
	assert_near(boss.stats.get_stat(StatId.Id.MAX_HP), base_hp + 3.0 * per, 0.01, "phút 3: 3 tầng")
	assert_near(boss.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), 160.0 + 24.0, 0.01)


func test_JGL_12_late_spawn_starts_with_minutes_stacks() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"golem_lava", 600.0, 300.0)
	_to(w, 600.1)
	var boss: Entity = _alive(w, c)[0]
	var def: UnitDef = _lib.camps[&"golem_lava"].units[0]
	assert_near(boss.stats.get_stat(StatId.Id.MAX_HP), def.stats.base_hp + 10.0 * _growth_hp(def), 0.01, "sinh ở phút 10: 10 tầng")
	assert_near(boss.health, boss.stats.get_stat(StatId.Id.MAX_HP), 0.01, "sinh ra đầy máu")


static func _growth_hp(def: UnitDef) -> float:
	for m: ModifierDef in def.growth.modifiers:
		if m.stat == &"max_hp":
			return float(m.value)
	return 0.0


func test_JGL_13_passives_attached_on_spawn() -> void:
	var w: World = _world()
	var c: CampState = _boss_camp(w, &"golem_moss", 0.1, 300.0)
	_to(w, 0.2)
	var ids: Array = _alive(w, c)[0].effects.map(func(i: EffectInstance) -> StringName: return i.def.id)
	assert_true(ids.has(&"golem_stomp"), "dậm đất gắn lúc sinh")
	var fire: Entity = UnitFactory.unit(w, _lib.camps[&"golem_lava"].units[0], Entity.Kind.NEUTRAL, 2, Vector2(100, 100))
	assert_eq(fire.effects.size(), 0, "UnitFactory không tự gắn: JungleSpawner gắn khi sinh trại")


## D-309 (người chơi: người đá dậm đất làm choáng): đòn đánh trúng thì dậm đất — sát thương phép + choáng mọi kẻ địch
## trong 350 quanh mình, hồi 7 s (trigger `cooldown`); đơn vị ngoài vùng không dính.
func test_JGL_13_golem_stomp_stuns_enemies_around_with_cooldown() -> void:
	var w: World = _world()
	var golem: Entity = UnitFactory.unit(w, _lib.camps[&"golem_moss"].units[0], Entity.Kind.NEUTRAL, 2, Vector2(3000, 3000))
	golem.position = w.navigation(golem.radius).nearest_clear(w.map.world_size() * 0.5 + Vector2(0, 900))
	Effects.apply(w, golem, load("res://content/effects/golem_stomp.tres") as EffectDef, golem)
	var near: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, golem.position + Vector2(150, 0))
	var side: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 0, golem.position + Vector2(-250, 0))
	var far: Entity = UnitFactory.hero(w, _lib.heroes[&"vexa"], 0, golem.position + Vector2(0, 700))
	var hp: float = side.health
	w.emit(&"attack_landed", golem.id, near.id, 100.0)
	for i: int in 3:
		w.step()
	assert_true(Rules.has_state(near, UnitState.Id.STUNNED), "mục tiêu bị choáng")
	assert_true(Rules.has_state(side, UnitState.Id.STUNNED), "kẻ địch trong 350 cũng bị choáng")
	assert_true(side.health < hp, "dậm đất gây sát thương")
	assert_false(Rules.has_state(far, UnitState.Id.STUNNED), "ngoài vùng không dính")
	for i: int in SimClock.seconds_to_ticks(2.0):
		w.step()
	w.emit(&"attack_landed", golem.id, near.id, 100.0)
	for i: int in 3:
		w.step()
	assert_false(Rules.has_state(near, UnitState.Id.STUNNED), "trong 7 s hồi: không dậm lại")



## D-307c (người chơi: rồng yếu quá, cấp 5 đã đánh được): một tướng cấp 5 đứng đánh tay đôi với rồng phút 5 thì chết
## trước khi rồng mất một nửa máu.
func test_JGL_12_boss_beats_a_level_5_hero_alone() -> void:
	var w: World = _world()
	for kind: StringName in [&"golem_moss", &"golem_lava"]:
		var d: UnitDef = _lib.camps[kind].units[0]
		var dps_boss: float = (d.stats.base_damage + 5 * 8.0) / d.stats.base_attack_time
		var hero: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, Vector2(100, 100))
		while hero.stats.level() < 5:
			Progression.add_xp(w, hero, Progression.xp_to_next(w, hero.stats.level()))
		hero.stats.recompute()
		var hero_hp: float = hero.stats.get_stat(StatId.Id.MAX_HP)
		var hero_dps: float = hero.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) * hero.stats.attacks_per_second() \
			* DamageFormulas.armor_multiplier(d.stats.physical_armor, w.balance.armor_coefficient)
		var hero_alive: float = hero_hp / (dps_boss * DamageFormulas.armor_multiplier(hero.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), w.balance.armor_coefficient))
		assert_true(hero_alive * hero_dps < d.stats.base_hp * 0.5, "%s: tướng cấp 5 sống %.0f s, gây %.0f / %.0f máu" % [kind, hero_alive, hero_alive * hero_dps, d.stats.base_hp])


## D-320: trigger Dậm Đất chạy → phát `effect_triggered` (chủ = người đá, mang hiệu ứng golem_stomp) để VIEW vẽ sóng dậm
## đất; đang hồi 7 s thì đòn sau không phát.
func test_EVT_effect_triggered_emitted_when_stomp_fires_not_on_cooldown() -> void:
	var w: World = _world()
	var golem: Entity = UnitFactory.unit(w, _lib.camps[&"golem_moss"].units[0], Entity.Kind.NEUTRAL, 2, Vector2(3000, 3000))
	golem.position = w.navigation(golem.radius).nearest_clear(w.map.world_size() * 0.5 + Vector2(0, 900))
	Effects.apply(w, golem, load("res://content/effects/golem_stomp.tres") as EffectDef, golem)
	var near: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, golem.position + Vector2(150, 0))
	var fired: Array[int] = []
	for round: int in 2:
		w.emit(&"attack_landed", golem.id, near.id, 100.0)
		for i: int in 3:
			w.step()
			for ev: GameEvent in w.previous_events + w.events:
				if ev.type == &"effect_triggered" and ev.source_id == golem.id and not fired.has(ev.seq):
					assert_eq(ev.effect.def.id, &"golem_stomp", "mang hiệu ứng Dậm Đất")
					assert_eq(ev.target_id, near.id, "đối tượng = kẻ bị đánh")
					fired.append(ev.seq)
	assert_eq(fired.size(), 1, "lần đầu phát, lần sau đang hồi 7 s thì không")
