extends TestCase
## M7.2: bot thoát trụ, rút về nhà, đứng hồi (BOT-01..03).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Mode := BotState.Mode

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_vision(w)
	return w


## Bot đội 1 đặt ở `at`.
func _bot(w: World, at: Vector2) -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 1, w.navigation(32.0).nearest_clear(at))
	MatchSetup.add_bot(w, e)
	return e


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


## Trụ T1 giữa của đội 0.
func _mid_t1(w: World) -> Entity:
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.TOWER and e.team == 0 and e.tier == 1 and String(e.structure_id) == "blue_mid_t1":
			return e
	return null


func test_BOT_01_escapes_tower_that_targets_it() -> void:
	var w: World = _world()
	var tower: Entity = _mid_t1(w)
	assert_true(tower != null)
	var bot: Entity = _bot(w, tower.position + (_map.fountain_point(1) - tower.position).normalized() * 400.0)
	var targeted: bool = false
	for i: int in range(30):
		w.step()
		targeted = targeted or (tower.order.type == Order.Type.ATTACK and tower.order.target_id == bot.id)
	assert_true(targeted, "trụ bắn bot")
	assert_eq(bot.bot.mode, Mode.ESCAPE_TOWER)
	_steps(w, 5 * 30)
	assert_true(bot.alive)
	assert_true(Rules.tower_threat_at(w, 1, bot.position, bot.radius).is_empty(), "đã ra khỏi vùng trụ")
	assert_true(bot.bot.mode != Mode.ESCAPE_TOWER, "an toàn thì thoát state")


func test_BOT_02_03_retreat_then_recover_until_80() -> void:
	var w: World = _world()
	var home: Vector2 = _map.fountain_point(1)
	var bot: Entity = _bot(w, home + (_map.world_size() * 0.5 - home).normalized() * 1500.0)
	bot.health = bot.stats.get_stat(StatId.Id.MAX_HP) * 0.2
	_steps(w, 10)
	assert_eq(bot.bot.mode, Mode.RETREAT, "máu < 30% thì rút")
	var recovered: bool = false
	for i: int in range(40 * 30):
		w.step()
		if bot.bot.mode == Mode.RECOVER:
			recovered = true
			assert_true(bot.position.distance_to(home) <= w.balance.fountain_radius, "đứng hồi ở fountain")
		if recovered and bot.bot.mode != Mode.RECOVER:
			break
	assert_true(recovered, "tới fountain thì đứng hồi")
	assert_true(bot.health >= bot.stats.get_stat(StatId.Id.MAX_HP) * 0.8 - 1.0, "đi khi đủ 80%")


func test_BOT_02_mid_hp_does_not_retreat_and_hash() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _map.fountain_point(1) + Vector2(-1500, 0))
	bot.health = bot.stats.get_stat(StatId.Id.MAX_HP) * 0.5
	_steps(w, 10)
	assert_eq(bot.bot.mode, Mode.RALLY, "50% máu: vẫn ra lane")
	var h: PackedByteArray = w.state_hash()
	bot.bot.trade_until_tick += 7
	assert_true(w.state_hash() != h, "D-30: trạng thái bot trong hash")


func test_BOT_21_recalls_when_far_and_quiet() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _map.world_size() * 0.5)
	bot.health = bot.stats.get_stat(StatId.Id.MAX_HP) * 0.2
	var started: bool = false
	for i: int in range(12 * 30):
		w.step()
		started = started or bot.recall_until_tick >= 0
	assert_true(started, "xa nhà, yên tĩnh: về thành")
	assert_true(bot.position.distance_to(_map.fountain_point(1)) < 700.0, "đã về fountain")
