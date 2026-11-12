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


## Lỗi (D-353): lính phe mình bị ép về đầu lane (tiến độ 0) thì hai điểm đứng chờ trùng nhau → bot đứng im.
func test_BOT_11_rally_at_lane_start_still_alternates() -> void:
	var w: World = _world()
	var bot: Entity = _bot(w, _map.fountain_point(1))
	var route: LaneRoute = LaneRoute.of(w, bot.bot.lane, bot.team)
	var creep: Entity = UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 1, route.point_at(0.0))
	creep.lane = bot.bot.lane
	var c: BotController = BotController.new()
	w.tick = 0
	var a: Vector2 = c.rally_point(w, bot)
	w.tick = SimClock.seconds_to_ticks(BotController.RALLY_STEP_SECONDS)
	var b: Vector2 = c.rally_point(w, bot)
	assert_true(a.distance_to(b) > 20.0, "hai điểm đứng chờ phải khác nhau: %s / %s" % [a, b])
	assert_true(BotController.safe(w, bot, a) and BotController.safe(w, bot, b), "BOT-10: cả hai điểm an toàn")


## Lỗi (D-380): điểm thoát "lùi thẳng về phía nhà" rơi vào sau một vách → không có đường tới, lệnh đi xong
## ngay, bot đứng im trong vùng trụ. Toạ độ lấy từ trận brakk:noctis seed 2 phút 27:02.
func test_BOT_11_escape_point_behind_wall_still_moves() -> void:
	var w: World = _world()
	for t: Entity in w.entities:  # trụ đỏ đã đổ trong trận đó
		if t.kind == Entity.Kind.TOWER and String(t.structure_id) in ["red_mid_t1", "red_mid_t2", "red_mid_t3", "red_bot_t1", "red_bot_t2", "red_top_t1", "red_top_t2"]:
			t.alive = false
	var bot: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, Vector2(8956.053, 2406.312))
	MatchSetup.add_bot(w, bot)
	var start: Vector2 = bot.position
	assert_false(BotController.safe(w, bot, start), "chỗ đứng trong vùng trụ địch")
	var p: Vector2 = BotController.new().escape_point(w, bot)
	assert_false(w.navigation(bot.radius).path(start, p).is_empty(), "BOT-01: điểm thoát phải có đường tới: %s" % p)
	_steps(w, 60)
	assert_true(bot.position.distance_to(start) > 100.0, "BOT-11: 2 s phải rời chỗ, mới đi %.0f" % bot.position.distance_to(start))


## Lỗi (D-397): bot đứng ở điểm lùi, đợt lính lùi lại đúng một bước nên điểm đứng chờ mới trùng chỗ đang đứng →
## cả một nhịp không có lệnh đi, bot đứng im > 2 s (trận phao_thu:brakk seed 2 phút 18:37, mode RALLY).
func test_BOT_11_rally_point_shifted_onto_spot_still_moves() -> void:
	var w: World = _world()
	var route: LaneRoute = LaneRoute.of(w, "MID", 1)
	var creep: Entity = UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 1, route.point_at(3000.0))
	creep.lane = "MID"
	var bot: Entity = _bot(w, route.point_at(2000.0))
	var c: BotController = BotController.new()
	var step: int = SimClock.seconds_to_ticks(BotController.RALLY_STEP_SECONDS)
	w.tick = step  # nhịp lùi: tới điểm lùi
	var back: Vector2 = c.rally_point(w, bot)
	bot.position = back
	w.tick = step + 1
	c.rally_point(w, bot)
	creep.position = route.point_at(route.progress_of(creep.position) - BotController.RALLY_STEP_BACK)  # lính lùi một bước
	w.tick = 2 * step  # nhịp đứng: điểm đứng chờ mới ≈ chỗ đang đứng
	var next: Vector2 = c.rally_point(w, bot)
	assert_true(next.distance_to(bot.position) > BotController.ARRIVE * 0.5, "BOT-11: nhịp mới phải có chỗ đi tới: %s / %s" % [next, bot.position])
	assert_true(BotController.safe(w, bot, next), "BOT-10")
