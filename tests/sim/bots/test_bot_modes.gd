extends TestCase
## M7.3: các state chính của bot (BOT-04..09, BOT-12) và farm rừng (D-94).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Mode := BotState.Mode

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(jungle: bool = false) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_vision(w)
	MatchSetup.add_lane_creeps(w, _lib, false)
	if jungle:
		MatchSetup.add_jungle(w, _lib)
	return w


func _mid() -> Vector2:
	return _map.world_size() * 0.5


func _toward_red() -> Vector2:
	return (_map.fountain_point(1) - _map.fountain_point(0)).normalized()


func _hero(w: World, team: int, at: Vector2, id: StringName = &"myra") -> Entity:
	return UnitFactory.hero(w, _lib.heroes[id], team, w.navigation(32.0).nearest_clear(at))


func _bot(w: World, at: Vector2, id: StringName = &"myra") -> Entity:
	var e: Entity = _hero(w, 1, at, id)
	MatchSetup.add_bot(w, e)
	return e


func _creep(w: World, team: int, at: Vector2) -> Entity:
	return MatchSetup.spawn_creep(w, _lib, &"creep_melee", team, "MID", at)


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _attacking(e: Entity, t: Entity) -> bool:
	return e.order.type == Order.Type.ATTACK and not e.order.finished and e.order.target_id == t.id


func test_BOT_04_trades_back_then_stops() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _mid() + _toward_red() * 200.0)
	var me: Entity = _hero(w, 0, _mid() - _toward_red() * 200.0, &"brakk")
	w.submit(Command.attack(me.id, bot.id))
	_steps(w, 30)
	assert_eq(bot.bot.mode, Mode.TRADE, "bị đánh thì đánh trả")
	assert_true(_attacking(bot, me))
	w.submit(Command.move_to(me.id, _map.fountain_point(0)))
	me.position = _map.fountain_point(0)
	_steps(w, 4 * 30)
	assert_true(bot.bot.mode != Mode.TRADE, "hết cửa sổ / mất dấu thì thôi")


func test_BOT_04_10_does_not_trade_into_enemy_tower() -> void:
	var w: World = _world()
	var tower: Vector2 = _map.tower_point("blue_mid_t1")
	var me: Entity = _hero(w, 0, tower + _toward_red() * 250.0, &"brakk")
	var bot: Entity = _bot(w, tower + _toward_red() * 1100.0, &"brakk")
	me.stats.set_base(StatId.Id.ATTACK_RANGE, 900.0)
	me.stats.recompute()
	w.submit(Command.attack(me.id, bot.id))
	_steps(w, 40)
	assert_true(bot.bot.mode != Mode.TRADE, "bot cận chiến, người chơi đứng dưới trụ: không đuổi vào (BOT-10)")
	assert_false(_attacking(bot, me))


func test_BOT_05_hunts_low_hp_hero_in_range() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _mid() + _toward_red() * 300.0)
	var me: Entity = _hero(w, 0, _mid() - _toward_red() * 300.0, &"brakk")
	me.health = me.stats.get_stat(StatId.Id.MAX_HP) * 0.3
	_steps(w, 10)
	assert_eq(bot.bot.mode, Mode.KILL)
	assert_true(_attacking(bot, me))


func test_BOT_12_does_not_hunt_what_it_cannot_see() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _mid() + _toward_red() * 300.0)
	var me: Entity = _hero(w, 0, _mid() - _toward_red() * 300.0, &"brakk")
	me.health = me.stats.get_stat(StatId.Id.MAX_HP) * 0.3
	Effects.apply(w, me, _lib.effects[&"shadow_veil"], me, {&"fade_in": 0.0, &"move_bonus": 0.0}, "20")
	_steps(w, 10)
	assert_true(bot.bot.mode != Mode.KILL, "tàng hình: bot không thấy thì không săn")


func test_BOT_06_defends_base() -> void:
	var w: World = _world()
	var core: Vector2 = _map.core_point(1)
	var bot: Entity = _bot(w, core + (_mid() - core).normalized() * 600.0)
	var intruder: Entity = _creep(w, 0, core + (_mid() - core).normalized() * 1000.0)
	assert_true(_map.is_in_base(intruder.position, 1))
	_steps(w, 10)
	assert_eq(bot.bot.mode, Mode.DEFEND_BASE)
	assert_true(_attacking(bot, intruder))


func test_BOT_07_farms_and_takes_last_hit_first() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _mid() + _toward_red() * 350.0)
	var a: Entity = _creep(w, 0, _mid() - _toward_red() * 100.0)
	var b: Entity = _creep(w, 0, _mid() - _toward_red() * 100.0 + _toward_red().orthogonal() * 80.0)
	a.health = 300.0
	b.health = 20.0
	_steps(w, 10)
	assert_eq(bot.bot.mode, Mode.FARM)
	assert_eq(bot.order.target_id, b.id, "con một đòn là chết: last hit trước")


func test_BOT_08_pushes_tower_when_creeps_tank() -> void:
	var w: World = _world()
	var tower: Entity = null
	for e: Entity in w.entities:
		if e.structure_id == &"blue_mid_t1":
			tower = e
	var dir: Vector2 = _toward_red()
	for i: int in range(3):
		var c: Entity = MatchSetup.spawn_creep(w, _lib, &"creep_melee", 1, "MID", tower.position + dir * (140.0 + i * 30.0))
		c.stats.set_base(StatId.Id.MAX_HP, 100000.0)
		c.stats.recompute()
		c.health = 100000.0
	var bot: Entity = _bot(w, tower.position + dir * 700.0)
	var pushed: bool = false
	for i: int in range(60):
		w.step()
		pushed = pushed or bot.bot.mode == Mode.PUSH
	assert_true(pushed, "trụ bắn lính, đủ lính đỡ → đánh trụ")
	assert_true(Rules.is_safe_for_hero(w, bot, bot.position) or bot.bot.mode == Mode.ESCAPE_TOWER)


func test_D_94_jungles_when_lane_empty() -> void:
	var w: World = _world(true)
	_steps(w, SimClock.seconds_to_ticks(w.balance.jungle_first_spawn) + 2)
	var camp: CampState = null
	for c: CampState in w.camps:
		if _map.camp_sides[c.index] == 1 and not c.unit_ids.is_empty():
			if camp == null or c.center.distance_to(_mid()) < camp.center.distance_to(_mid()):
				camp = c
	assert_true(camp != null)
	var bot: Entity = _bot(w, camp.center + (_mid() - camp.center).normalized() * 500.0)
	var jungled: bool = false
	for i: int in range(90):
		w.step()
		jungled = jungled or bot.bot.mode == Mode.JUNGLE
	assert_true(jungled, "lane trống thì đánh trại rừng phe mình")


func test_BOT_09_rallies_behind_own_creeps() -> void:
	var w: World = _world()
	var front: Entity = _creep(w, 1, _mid())
	front.stats.set_base(StatId.Id.MOVEMENT_SPEED, 0.0)
	front.stats.recompute()
	var bot: Entity = _bot(w, _map.fountain_point(1) + (_mid() - _map.fountain_point(1)).normalized() * 1500.0)
	_steps(w, 20 * 30)
	assert_eq(bot.bot.mode, Mode.RALLY)
	var route: LaneRoute = LaneRoute.of(w, "MID", 1)
	var gap: float = route.progress_of(front.position) - route.progress_of(bot.position)
	assert_true(gap > 150.0 and gap < 600.0, "đứng sau lính phe mình khoảng bot_lane_offset (gap %d)" % gap)
