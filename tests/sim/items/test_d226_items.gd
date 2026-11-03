extends TestCase
## D-226: Kiếm Băng (chậm theo mục tiêu cận chiến EFF-08 `target_is_melee`), Giày Tốc Biến (ABL-24), Cự Kiếm,
## Ngọc Băng Sương 1 / 2 (giảm hồi máu ABL-23), chỉ số `heal_reduction`.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(7, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	return w


func _hero(w: World, team: int, offset: Vector2, id: StringName = &"brakk") -> Entity:
	var at: Vector2 = _map.world_size() * 0.5 + Vector2(-900, 900) + offset
	var h: Entity = UnitFactory.hero(w, _lib.heroes[id], team, at)
	h.stats.set_base(StatId.Id.MAX_HP, 100000)
	h.stats.recompute()
	h.health = 100000
	return h


func _first_hit(w: World, me: Entity, target: Entity) -> void:
	w.submit(Command.attack(me.id, target.id, true))
	for i: int in range(150):
		w.step()
		if target.health < 100000:
			return


func test_ABL_23_heal_reduction_takes_highest_source_and_scales_heals() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	me.stats.add_modifier(StatModifier.make(StatId.Id.HEAL_REDUCTION, ModifierDef.Op.ADD, 0.3, 1))
	me.stats.add_modifier(StatModifier.make(StatId.Id.HEAL_REDUCTION, ModifierDef.Op.ADD, 0.75, 2))
	me.stats.recompute()
	assert_near(me.stats.get_stat(StatId.Id.HEAL_REDUCTION), 0.75, 0.0001, "30% và 75% → lấy 75%")
	me.health = 1000
	ActionRunner.heal(w, me, 400.0, me.id)
	assert_near(me.health, 1100.0, 0.01, "hồi 400 còn 100")


func test_ABL_23_regen_reduced_only_when_positive() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	me.stats.set_base(StatId.Id.HP_REGEN, 30.0)
	me.stats.add_modifier(StatModifier.make(StatId.Id.HEAL_REDUCTION, ModifierDef.Op.ADD, 0.5, 1))
	me.stats.recompute()
	me.health = 1000
	for i: int in SimClock.seconds_to_ticks(1.0):
		w.step()
	assert_near(me.health - 1000.0, 15.0, 0.6, "hồi 30/s còn 15/s")


func test_EFF_08_frost_blade_slow_depends_on_target_melee() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO, &"myra")
	var melee: Entity = _hero(w, 1, Vector2(400, 0), &"brakk")
	Items.give(w, me, _lib.items[&"frost_blade"])
	w.step()
	var base_ms: float = melee.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	var base_as: float = melee.stats.get_stat(StatId.Id.ATTACK_SPEED)
	_first_hit(w, me, melee)
	for i: int in 30:
		w.step()
	assert_near(melee.stats.get_stat(StatId.Id.MOVEMENT_SPEED), base_ms * 0.75, 1.0, "mục tiêu cận chiến: chậm 25%")
	assert_near(melee.stats.get_stat(StatId.Id.ATTACK_SPEED), base_as - 0.4, 0.001, "giảm 40% tốc đánh")
	var w2: World = _world()
	var me2: Entity = _hero(w2, 0, Vector2.ZERO, &"brakk")
	var ranged: Entity = _hero(w2, 1, Vector2(120, 0), &"myra")
	Items.give(w2, me2, _lib.items[&"frost_blade"])
	w2.step()
	var base_ms2: float = ranged.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	_first_hit(w2, me2, ranged)
	w2.step()
	assert_near(ranged.stats.get_stat(StatId.Id.MOVEMENT_SPEED), base_ms2 * 0.5, 1.0, "mục tiêu đánh xa: chậm 50%")


func test_D_226_frost_blade_and_crossbow_stats_buy_direct() -> void:
	_world()
	for pair: Array in [[&"frost_blade", 4800, 70.0], [&"breaker_crossbow", 5100, 175.0]]:
		var d: ItemDef = _lib.items[pair[0]]
		assert_eq(d.cost, pair[1], "%s: giá" % pair[0])
		assert_true(d.components.is_empty(), "%s: mua thẳng" % pair[0])
		var w: World = _world()
		var me: Entity = _hero(w, 0, Vector2.ZERO)
		var before: float = me.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
		Items.give(w, me, d)
		me.stats.recompute()
		assert_near(me.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE) - before, pair[2], 0.01, "%s: sát thương" % pair[0])


func test_ABL_24_blink_boots_teleport_fixed_distance() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	var base_ms: float = me.stats.get_stat(StatId.Id.MOVEMENT_SPEED)
	Items.give(w, me, _lib.items[&"blink_boots"])
	w.step()
	assert_true(me.stats.get_stat(StatId.Id.MOVEMENT_SPEED) > base_ms, "+tốc chạy")
	var dist: float = _lib.items[&"blink_boots"].ability.values[&"distance"][0]
	var start: Vector2 = me.position
	w.submit(Command.cast(me.id, Items.SLOT_BASE, -1, Vector2.INF, Vector2.LEFT))
	for i: int in 3:
		w.step()
	assert_near(me.position.distance_to(start), dist, 2.0, "đi đủ quãng cố định")
	assert_true((me.position - start).normalized().dot(Vector2.LEFT) > 0.99, "đúng hướng")
	assert_eq(_lib.items[&"blink_boots"].ability.values[&"cooldown"][0], 25.0, "hồi 25 s")


func test_ABL_24_blink_into_wall_stops_at_walkable() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	me.position = _map.fountain_point(0) + Vector2(0, -10)
	var ctx: ExprContext = ExprContext.make(me, me, {&"distance": 20000.0})
	ctx.direction = Vector2.LEFT
	var a: TeleportAction = TeleportAction.new()
	a.distance = "distance"
	ActionRunner.run(w, [a] as Array[ActionDef], ctx, me.id)
	assert_true(_map.clearance_at(me.position) > 0.0, "không đứng trong vật cản / ngoài map")
	assert_true(me.position.x < _map.fountain_point(0).x - 10.0, "vẫn đi được về phía nhắm")


func test_D_226_frost_orb_buy_direct_all_stats() -> void:
	var w: World = _world()
	var d: ItemDef = _lib.items[&"frost_orb"]
	assert_true(d.components.is_empty(), "Ngọc 1 mua thẳng")
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	var s: float = me.stats.get_stat(StatId.Id.STRENGTH)
	Items.give(w, me, d)
	me.stats.recompute()
	assert_near(me.stats.get_stat(StatId.Id.STRENGTH) - s, 12.0, 0.01, "+12 mọi thuộc tính")
	var d2: ItemDef = _lib.items[&"frost_orb_ii"]
	assert_eq(d2.components, [&"frost_orb", &"frost_orb"] as Array[StringName], "Ngọc 2 = 2 Ngọc 1 + công thức")
	assert_eq(d2.cost, 5300, "giá 5300")


func test_ABL_23_frost_orb_ii_frostbite_then_active_75() -> void:
	var w: World = _world()
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	var foe: Entity = _hero(w, 1, Vector2(120, 0))
	Items.give(w, me, _lib.items[&"frost_orb_ii"])
	w.step()
	var dmg: float = foe.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	_first_hit(w, me, foe)
	w.step()
	assert_near(foe.stats.get_stat(StatId.Id.HEAL_REDUCTION), 0.3, 0.0001, "Tê Cóng: giảm 30% hồi máu")
	assert_near(foe.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), dmg * 0.9, 0.5, "Tê Cóng: giảm 10% sát thương vật lý")
	w.submit(Command.cast(me.id, Items.SLOT_BASE))
	w.step()
	foe.health = 100000
	_first_hit(w, me, foe)
	w.step()
	assert_near(foe.stats.get_stat(StatId.Id.HEAL_REDUCTION), 0.75, 0.0001, "kích hoạt: đòn đánh giảm 75% hồi máu")


## D-227: Giày Tốc Biến ghép từ giày thường + phí; bị trói không tốc biến được.
func test_ABL_24_blink_blocked_when_rooted_and_recipe() -> void:
	var w: World = _world()
	assert_eq(_lib.items[&"blink_boots"].components, [&"boots"] as Array[StringName], "giày thường + phí")
	var me: Entity = _hero(w, 0, Vector2.ZERO)
	Items.give(w, me, _lib.items[&"blink_boots"])
	w.step()
	var root: EffectDef = EffectDef.new()
	root.id = &"test_root"
	root.states = [UnitState.Id.ROOTED] as Array[UnitState.Id]
	Effects.apply(w, me, root, me, {}, "3")
	w.step()
	var start: Vector2 = me.position
	w.submit(Command.cast(me.id, Items.SLOT_BASE, -1, Vector2.INF, Vector2.LEFT))
	for i: int in 3:
		w.step()
	assert_near(me.position.distance_to(start), 0.0, 1.0, "bị trói: không tốc biến")
