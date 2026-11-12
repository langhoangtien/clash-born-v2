extends TestCase
## M7.3: 3 phút trận thật bot đấu bot — INV-06 (không ở chỗ không an toàn > 1 s, trừ
## ESCAPE_TOWER / RETREAT / bị ép — D-396) và BOT-11 (không đứng yên > 2 s ngoài RECOVER).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const Mode := BotState.Mode

static var _map: MapLayout
static var _lib: ContentLibrary


func _world(seed: int, a: StringName, b: StringName) -> World:
	return team_world(MatchConfig.make(1, [a, b] as Array[StringName], [], BotState.Difficulty.NORMAL, seed))


## Trận đầy đủ (công trình, tầm nhìn, rừng, shop, lính) dựng theo cấu hình trận (MATCH-01..05).
func team_world(cfg: MatchConfig) -> World:
	var seed: int = cfg.seed
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(seed, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(w, _lib, cfg)
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
			var forced: bool = e.duel != null or Rules.is_taunted(w, e)  # D-394 / D-396: bị ép (ST-19, ST-20), bot không ra lệnh được
			var exempt: bool = e.bot.mode == Mode.ESCAPE_TOWER or e.bot.mode == Mode.RETREAT or forced
			unsafe[e.id] = 0 if exempt or BotController.safe(w, e, e.position) else unsafe.get(e.id, 0) + 1
			stuck[e.id] = 0 if BotController.safe(w, e, e.position) else stuck.get(e.id, 0) + 1
			if stuck[e.id] > 300:
				return "%s bot đội %d kẹt ở chỗ không an toàn > 10 s (mode %s)" % [MatchHud.clock_text(w.tick), e.team, Mode.keys()[e.bot.mode]]
			if unsafe[e.id] > 30:
				return "%s INV-06: bot đội %d ở chỗ không an toàn > 1 s (mode %s)" % [MatchHud.clock_text(w.tick), e.team, Mode.keys()[e.bot.mode]]
			var moved: bool = e.position.distance_to(last.get(e.id, Vector2.INF)) > 0.5
			var busy: bool = e.attack_phase != Entity.AttackPhase.NONE or e.cast != null or not Rules.can_move(e) or e.recall_until_tick >= 0 \
				or forced
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


## Lỗi (D-391): bot đi tới đánh trụ, lính phe mình đi ngược chiều thẳng hàng trên đường → hai bên đẩy nhau, hero chỉ
## trôi ~0,3 / tick > 2 s (BOT-11). Hai trận thật, chạy quá mốc lỗi (1:29 và 1:59).
func test_BOT_11_attack_approach_blocked_head_on_by_own_creep() -> void:
	assert_eq(run_checks(_world(1, &"duy_anh", &"tho_san"), 2.0), "", "duy_anh:tho_san seed 1")
	assert_eq(run_checks(_world(1, &"duy_anh", &"vexa"), 2.5), "", "duy_anh:vexa seed 1")


## D-394: Quyết Đấu một hero đang GHOST — theo ST-19 cả hai đứng chờ, bot không ra lệnh được (IN_DUEL) nên BOT-11 miễn trừ.
## Trận thật duy_anh:brakk seed 3, trước đây báo "BOT-11 … ESCAPE_TOWER" ở 4:32.
func test_BOT_11_forced_by_duel_is_exempt() -> void:
	assert_eq(run_checks(_world(3, &"duy_anh", &"brakk"), 5.0), "", "duy_anh:brakk seed 3")


## Lỗi (D-396): Thiết Vệ khiêu khích (ST-20) kéo đối thủ vào tầm trụ — bot bị ép, lệnh bị từ chối; INV-06 miễn lúc bị ép,
## đếm lại từ 0 khi hết ép. Trận thật tho_san:thiet_ve seed 1 (ca lộ ra lúc 1:03), chạy quá mốc lỗi.
func test_INV_06_forced_by_taunt_is_exempt() -> void:
	assert_eq(run_checks(_world(1, &"tho_san", &"thiet_ve"), 2.0), "", "tho_san:thiet_ve seed 1")


## D-396: miễn trừ không che lỗi thật — hết khiêu khích mà đang ở chỗ không an toàn thì phải ra trong hạn INV-06 (1 s).
func test_INV_06_leaves_tower_after_taunt_ends() -> void:
	var w: World = _world(1, &"tho_san", &"thiet_ve")
	var was_taunted: Dictionary[int, bool] = {}
	var since_end: Dictionary[int, int] = {}
	var forced_unsafe: int = 0
	var worst: int = 0
	for t: int in range(SimClock.seconds_to_ticks(120.0)):
		w.step()
		for e: Entity in w.entities:
			if e.bot == null or not e.alive:
				continue
			var taunted: bool = Rules.is_taunted(w, e)
			var safe: bool = BotController.safe(w, e, e.position)
			if taunted and not safe:
				forced_unsafe += 1
			if was_taunted.get(e.id, false) and not taunted and not safe:
				since_end[e.id] = 0
			if since_end.has(e.id):
				if safe:
					worst = maxi(worst, since_end[e.id])
					since_end.erase(e.id)
				else:
					since_end[e.id] += 1
					worst = maxi(worst, since_end[e.id])
			was_taunted[e.id] = taunted
	assert_true(forced_unsafe > 0, "trận có ca bị ép vào chỗ không an toàn")
	assert_true(worst <= 30, "hết ép thì ra khỏi chỗ không an toàn trong 1 s (chậm nhất %d tick)" % worst)
