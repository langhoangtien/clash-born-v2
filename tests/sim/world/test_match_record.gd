extends TestCase
## ST.1 (D-331): biên bản trận cho Clashborn Stats — đọc World + MatchConfig khi trận xong.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _match(cfg: MatchConfig) -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_shop(w, lib)
	return [w, MatchSetup.spawn_heroes(w, lib, cfg)]


func test_ST_1_record_has_match_players_items_and_buys() -> void:
	var cfg: MatchConfig = MatchConfig.duel(&"gorran", &"myra", BotState.Difficulty.NORMAL, 5)
	var made: Array = _match(cfg)
	var w: World = made[0]
	var me: Entity = made[1][0]
	for t: int in 45:
		w.step()
	w.submit(Command.buy(me.id, &"iron_branch"))
	w.step()
	w.step()
	me.kills = 3
	me.deaths = 1
	me.assists = 2
	w.winner = 0
	var r: Dictionary = MatchRecord.of(w, cfg, "0.1.999")
	assert_eq(r["schema"], MatchRecord.SCHEMA)
	assert_eq([r["version"], r["mode"], r["kind"], r["winner"], r["seed"]], ["0.1.999", "1v1", "pvb", 0, 5])
	assert_near(r["duration_s"], w.tick / 30.0, 0.001)
	var p: Array = r["players"]
	assert_eq(p.map(func(x: Dictionary) -> Array: return [x["hero"], x["team"], x["slot"], x["bot"], x["won"]]),
		[["gorran", 0, 0, false, true], ["myra", 1, 0, true, false]])
	assert_eq([p[0]["kills"], p[0]["deaths"], p[0]["assists"]], [3, 1, 2])
	assert_eq(p[0]["items"], ["iron_branch"], "đồ cuối trận")
	assert_eq(p[0]["buys"].size(), 1, "lịch sử mua")
	assert_eq(p[0]["buys"][0][1], "iron_branch")
	assert_near(p[0]["buys"][0][0], 1.5, 0.1, "giây mua")
	assert_false(r["cheats"])
	w.winner = -1  # trận xong thì World.step() không chạy nữa
	w.submit(Command.cheat_gold(me.id, 500))
	w.step()
	w.winner = 0
	assert_true(MatchRecord.of(w, cfg, "0.1.999")["cheats"], "CMD-06: dùng nút Test → đánh dấu, không tính thống kê")


func test_ST_1_kind_from_slots() -> void:
	var six: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]
	for case: Array in [[[], "bvb"], [[0], "pvb"], [[0, 3], "pvp"], [[0, 1, 2], "pvb"]]:
		var cfg: MatchConfig = MatchConfig.make(3, six, case[0], BotState.Difficulty.NORMAL, 1)
		assert_eq(MatchRecord.kind_of(cfg), case[1], "người ở ô %s" % [case[0]])
