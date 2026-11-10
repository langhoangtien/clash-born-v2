extends TestCase
## MATCH-01..05 (D-328, M9.1): trận dựng từ cấu hình — số ô mỗi đội, ô người / bot, tướng, seed.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const SIX: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]


func _world(cfg: MatchConfig) -> World:
	var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func test_MATCH_01_heroes_created_in_slot_order_human_or_bot() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var cfg: MatchConfig = MatchConfig.make(3, SIX, [0], BotState.Difficulty.HARD, 7)
	assert_eq(cfg.validate(lib), "")
	var w: World = _world(cfg)
	var heroes: Array[Entity] = MatchSetup.spawn_heroes(w, lib, cfg)
	assert_eq(heroes.map(func(e: Entity) -> int: return e.team), [0, 0, 0, 1, 1, 1], "đội 0 ô 0..2 rồi đội 1")
	assert_eq(heroes.map(func(e: Entity) -> StringName: return e.hero_def.id), SIX, "tướng theo ô")
	for k: int in range(1, heroes.size()):
		assert_true(heroes[k].id > heroes[k - 1].id, "id tăng theo thứ tự ô")
	assert_true(heroes[0].bot == null, "ô 0 là người")
	for k: int in range(1, 6):
		assert_true(heroes[k].bot != null and heroes[k].bot.difficulty == BotState.Difficulty.HARD, "ô %d là bot" % k)


func test_MATCH_01_bad_team_size_or_slot_count_rejected() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	assert_eq(MatchConfig.make(0, [], [], BotState.Difficulty.NORMAL, 1).validate(lib), "TEAM_SIZE")
	assert_eq(MatchConfig.make(6, SIX + SIX, [0], BotState.Difficulty.NORMAL, 1).validate(lib), "TEAM_SIZE")
	var cfg: MatchConfig = MatchConfig.make(3, SIX, [0], BotState.Difficulty.NORMAL, 1)
	cfg.slots.pop_back()
	assert_eq(cfg.validate(lib), "SLOT_COUNT")


func test_MATCH_02_duplicate_or_unknown_hero_rejected() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var mirror: Array[StringName] = [&"brakk", &"myra", &"vexa", &"brakk", &"gorran", &"duy_anh"]
	assert_eq(MatchConfig.make(3, mirror, [0], BotState.Difficulty.NORMAL, 1).validate(lib), "DUPLICATE_HERO",
		"không trùng cả hai đội")
	var unknown: Array[StringName] = [&"brakk", &"nobody"]
	assert_eq(MatchConfig.make(1, unknown, [0], BotState.Difficulty.NORMAL, 1).validate(lib), "UNKNOWN_HERO")


func test_MATCH_03_slots_spawn_apart_and_respawn_at_own_point() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var cfg: MatchConfig = MatchConfig.make(3, SIX, [], BotState.Difficulty.NORMAL, 7)
	var w: World = _world(cfg)
	var heroes: Array[Entity] = MatchSetup.spawn_heroes(w, lib, cfg)
	assert_true(heroes[0].position.distance_to(w.map.fountain_point(0)) < 40.0, "ô 0 ở fountain")
	for a: int in heroes.size():
		for b: int in range(a + 1, heroes.size()):
			if heroes[a].team == heroes[b].team:
				assert_true(heroes[a].position.distance_to(heroes[b].position) >= w.balance.hero_spawn_spread * 0.5,
					"ô %d và %d không đứng chồng" % [a, b])
	var e: Entity = heroes[2]
	var home: Vector2 = e.position
	e.position = w.map.fountain_point(1)
	e.alive = false
	e.respawn_tick = w.tick + 1
	w.step()
	w.step()
	assert_true(e.alive, "đã hồi sinh")
	assert_eq(e.position, home, "hồi sinh tại điểm của ô mình")


func test_MATCH_04_bots_get_lanes_by_slot() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var cfg: MatchConfig = MatchConfig.make(3, SIX, [], BotState.Difficulty.NORMAL, 7)
	var heroes: Array[Entity] = MatchSetup.spawn_heroes(_world(cfg), lib, cfg)
	assert_eq(heroes.map(func(e: Entity) -> String: return e.bot.lane), ["MID", "TOP", "BOT", "MID", "TOP", "BOT"])
	var duel: MatchConfig = MatchConfig.make(1, [&"brakk", &"myra"] as Array[StringName], [0], BotState.Difficulty.NORMAL, 7)
	assert_eq(MatchSetup.spawn_heroes(_world(duel), lib, duel)[1].bot.lane, "MID", "1v1: bot đi giữa")


func test_MATCH_05_seed_from_config_same_config_same_match() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var hashes: Array[PackedByteArray] = []
	for run: int in 2:
		var cfg: MatchConfig = MatchConfig.make(3, SIX, [], BotState.Difficulty.NORMAL, 4242)
		var w: World = _world(cfg)
		assert_eq(w.rng.seed, 4242, "seed lấy từ cấu hình")
		MatchSetup.spawn_structures(w, lib)
		MatchSetup.add_lane_creeps(w, lib, true)
		MatchSetup.spawn_heroes(w, lib, cfg)
		for t: int in 240:
			w.step()
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1], "cùng cấu hình → cùng trận")
