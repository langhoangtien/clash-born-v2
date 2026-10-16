extends TestCase
## M7.3: 3 phút trận thật bot đấu bot — INV-06 (không ở chỗ không an toàn > 1 s, trừ
## ESCAPE_TOWER / RETREAT) và BOT-11 (không đứng yên > 2 s ngoài RECOVER).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const Mode := BotState.Mode

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(seed: int, a: StringName, b: StringName) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(seed, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	MatchSetup.add_vision(w)
	MatchSetup.add_jungle(w, _lib)
	MatchSetup.add_shop(w, _lib)
	MatchSetup.add_lane_creeps(w, _lib, true)
	for team: int in range(2):
		var h: Entity = UnitFactory.hero(w, _lib.heroes[a if team == 0 else b], team, _map.fountain_point(team))
		MatchSetup.add_bot(w, h)
	return w


## Lỗi đầu tiên vi phạm INV-06 / BOT-11 trong `minutes` phút, "" nếu không có.
static func run_checks(w: World, minutes: float) -> String:
	var unsafe: Dictionary[int, int] = {}
	var stuck: Dictionary[int, int] = {}
	var still: Dictionary[int, int] = {}
	var last: Dictionary[int, Vector2] = {}
	for t: int in range(SimClock.seconds_to_ticks(minutes * 60.0)):
		w.step()
		if w.winner >= 0:
			return ""
		for e: Entity in w.entities:
			if e.bot == null or not e.alive or e.reincarnate_tick >= 0:
				unsafe.erase(e.id)
				still.erase(e.id)
				stuck.erase(e.id)
				continue
			var exempt: bool = e.bot.mode == Mode.ESCAPE_TOWER or e.bot.mode == Mode.RETREAT
			unsafe[e.id] = 0 if exempt or Rules.is_safe_for_hero(w, e, e.position) else unsafe.get(e.id, 0) + 1
			stuck[e.id] = 0 if Rules.is_safe_for_hero(w, e, e.position) else stuck.get(e.id, 0) + 1
			if stuck[e.id] > 150:
				return "%s bot đội %d kẹt ở chỗ không an toàn > 5 s (mode %s)" % [MatchHud.clock_text(w.tick), e.team, Mode.keys()[e.bot.mode]]
			if unsafe[e.id] > 30:
				return "%s INV-06: bot đội %d ở chỗ không an toàn > 1 s (mode %s)" % [MatchHud.clock_text(w.tick), e.team, Mode.keys()[e.bot.mode]]
			var moved: bool = e.position.distance_to(last.get(e.id, Vector2.INF)) > 0.5
			var busy: bool = e.attack_phase != Entity.AttackPhase.NONE or e.cast != null
			still[e.id] = 0 if moved or busy or e.bot.mode == Mode.RECOVER else still.get(e.id, 0) + 1
			last[e.id] = e.position
			if still[e.id] > 60:
				return "%s BOT-11: bot đội %d đứng yên > 2 s (mode %s)" % [MatchHud.clock_text(w.tick), e.team, Mode.keys()[e.bot.mode]]
	return ""


func test_INV_06_BOT_11_three_minutes_bot_vs_bot() -> void:
	var w: World = _world(3, &"brakk", &"myra")
	var problem: String = run_checks(w, 3.0)
	assert_eq(problem, "")
	var lh: int = 0
	for e: Entity in w.entities:
		if e.bot != null:
			lh += e.last_hits
	assert_true(lh > 0, "bot có farm được lính")
