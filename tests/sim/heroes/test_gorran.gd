extends TestCase
## D-122: Gorran · Giả Kim — nội tại +sát thương, Q Vũng Axit, W Lọ Độc (D-321, trước: Đuôi Rồng), R Cuồng Hóa, 3 talent.

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


## D-321: W Lọ Độc — vung 0,3 s rồi ném tới điểm, bay 0,4 s rồi vỡ: kẻ địch trong 250 trúng độc 5 s (chậm 30%, 70 phép / giây ở cấp 5);
## ngoài vùng không dính; hết 5 s thì hết.
func test_D_321_poison_flask_slows_and_ticks_in_area() -> void:
	var w: World = _world()
	var g: Entity = _gorran(w, [0, 5, 0])
	var foe: Entity = _foe(w, g.position + Vector2(600, 0))
	var out: Entity = _foe(w, foe.position + Vector2(0, 450))
	w.step()
	var ms: float = foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	w.submit(Command.cast(g.id, Slot.W, -1, foe.position))
	for i: int in range(15):
		w.step()
	assert_false(_poisoned(foe), "vung tay 0,3 s + lọ bay 0,4 s: 0,5 s chưa trúng độc")
	for i: int in range(9):
		w.step()
	assert_true(_poisoned(foe), "lọ vỡ: trúng độc")
	assert_false(_poisoned(out), "ngoài bán kính 250: không dính")
	assert_near(foe.stats.get_stat(StatId.Id.MOVEMENT_SPEED), ms * 0.7, 0.5, "cấp 5: chậm 30%")
	var dealt: float = _taken(w, foe, 30 * 2)
	assert_true(dealt > 70.0 and dealt <= 140.0, "2 s độc: ~140 phép trước kháng (%.0f)" % dealt)
	_taken(w, foe, 30 * 3)
	assert_false(_poisoned(foe), "hết 5 s")


func _poisoned(e: Entity) -> bool:
	return e.effects.any(func(i: EffectInstance) -> bool: return i.def.id == &"gorran_poison")


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


func test_D_122_talents_wider_acid_strong_poison_rage_bat() -> void:
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
	assert_near(Abilities.value(gw, Abilities.of(gw, Slot.W), &"dps"), 95.0, 0.001, "talent W (D-321): +25 độc mỗi giây")
