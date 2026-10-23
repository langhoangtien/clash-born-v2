extends TestCase
## D-122: Gorran · Giả Kim — nội tại +sát thương, Q Vũng Axit, W Đuôi Rồng, R Cuồng Hóa, 3 talent.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Slot := AbilityDef.Slot

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(4, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _gorran(w: World, ranks: Array[int] = [0, 0, 0]) -> Entity:
	var g: Entity = UnitFactory.hero(w, _lib.heroes[&"gorran"], 0, w.navigation(32.0).nearest_clear(_center()))
	for i: int in range(3):
		if ranks[i] > 0:
			Abilities.set_rank(w, g, Abilities.of(g, [Slot.Q, Slot.W, Slot.R][i]), ranks[i])
	g.mana = 5000.0
	return g


func _gorran20(w: World, talent: int) -> Entity:
	var g: Entity = _gorran(w)
	Progression.add_xp(w, g, 100000.0)
	g.skill_points = 0
	for slot: int in [Slot.Q, Slot.W, Slot.R]:
		var a: AbilityInstance = Abilities.of(g, slot)
		Abilities.set_rank(w, g, a, a.def.expected_ranks())
	g.mana = 5000.0
	if talent >= 0:
		w.submit(Command.choose_talent(g.id, talent))
	w.step()
	return g


func _foe(w: World, at: Vector2) -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 1, w.navigation(32.0).nearest_clear(at))
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.recompute()
	e.health = e.stats.get_stat(StatId.Id.MAX_HP)
	return e


func _taken(w: World, e: Entity, n: int) -> float:
	var sum: float = 0.0
	for i: int in range(n):
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"damage_taken" and ev.target_id == e.id:
				sum += ev.amount
	return sum


func test_D_122_innate_adds_damage_by_level() -> void:
	var w: World = _world()
	var g: Entity = _gorran(w)
	w.step()
	var base: float = 52.0
	assert_true(g.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) >= base + 15.0 - 0.01, "cấp 1: +15")
	var lv1: float = g.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	Progression.add_xp(w, g, 100000.0)
	w.step()
	assert_true(g.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) - lv1 > 20.0 - 0.01, "cấp 20: nội tại +35 (cộng thêm chỉ số theo cấp)")


func test_D_122_acid_pool_ticks_damage_for_ten_seconds() -> void:
	var w: World = _world()
	var g: Entity = _gorran(w, [5, 0, 0])
	var foe: Entity = _foe(w, g.position + Vector2(300, 0))
	foe.stats.set_base(StatId.Id.MOVEMENT_SPEED, 0)
	foe.stats.recompute()
	w.submit(Command.cast(g.id, Slot.Q, -1, foe.position))
	var first: float = _taken(w, foe, 30 * 5)
	var rest: float = _taken(w, foe, 30 * 7)
	assert_true(first > 100.0, "đứng trong vũng: mỗi giây ~50 phép (sau kháng)")
	assert_true(rest > 0.0, "vũng còn sau 5 s")
	var after: float = _taken(w, foe, 30 * 3)
	assert_near(after, 0.0, 0.01, "hết 10 s: vũng tan")


func test_D_122_dragon_tail_stuns_from_700() -> void:
	var w: World = _world()
	var g: Entity = _gorran(w, [0, 5, 0])
	var foe: Entity = _foe(w, g.position + Vector2(650, 0))
	w.submit(Command.cast(g.id, Slot.W, foe.id))
	for i: int in range(10):
		w.step()
	assert_true(Rules.has_state(foe, UnitState.Id.STUNNED), "choáng ở tầm 650")
	for i: int in range(30 * 3):
		w.step()
	assert_false(Rules.has_state(foe, UnitState.Id.STUNNED), "cấp 5: 2.7 s")


func test_D_122_rage_cuts_bat_regen_and_speed() -> void:
	var w: World = _world()
	var g: Entity = _gorran(w, [0, 0, 3])
	w.step()
	var ms: float = g.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	var regen: float = g.stats.get_stat(StatId.Id.HP_REGEN)
	w.submit(Command.cast(g.id, Slot.R))
	for i: int in range(5):
		w.step()
	assert_near(g.stats.get_stat(StatId.Id.BASE_ATTACK_TIME), 1.2, 0.001, "BAT 1.7 → 1.2 (D-133)")
	assert_near(g.stats.get_stat(StatId.Id.HP_REGEN) - regen, 35.0, 0.01)
	assert_near(g.stats.get_stat(StatId.Id.MOVEMENT_SPEED) - ms, 50.0, 0.01)
	for i: int in range(30 * 25):
		w.step()
	assert_near(g.stats.get_stat(StatId.Id.BASE_ATTACK_TIME), 1.7, 0.001, "hết 25 s")


func test_D_122_talents_wider_acid_long_stun_rage_bat() -> void:
	var w: World = _world()
	var gq: Entity = _gorran20(w, Slot.Q)
	assert_near(Abilities.value(gq, Abilities.of(gq, Slot.Q), &"radius"), 500.0, 0.001, "talent Q: bán kính +100")
	assert_near(Abilities.value(gq, Abilities.of(gq, Slot.Q), &"dps"), 65.0, 0.001, "talent Q: +15 mỗi giây")
	var w2: World = _world()
	var gr: Entity = _gorran20(w2, Slot.R)
	var dmg: float = gr.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	w2.submit(Command.cast(gr.id, Slot.R))
	for i: int in range(5):
		w2.step()
	assert_near(gr.stats.get_stat(StatId.Id.BASE_ATTACK_TIME), 1.1, 0.001, "talent R: BAT 1.1 (D-133)")
	assert_near(gr.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) - dmg, 0.0, 0.01, "talent R: không còn +sát thương")
	var w3: World = _world()
	var gw: Entity = _gorran20(w3, Slot.W)
	assert_near(Abilities.value(gw, Abilities.of(gw, Slot.W), &"stun_duration"), 3.7, 0.001, "talent W: choáng +1 s")
