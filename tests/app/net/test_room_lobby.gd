extends TestCase
## NET-07..09 (D-338): phòng chờ — mã phòng, vào / rời, chủ phòng, đội, tướng không trùng, bắt đầu → MatchConfig.

const SIX: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]


func test_NET_07_code_and_join_rules() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var code: String = RoomLobby.new_code(rng, 1)
	assert_eq(code.length(), 6, "NET-15 (D-401): 6 chữ số")
	assert_true(code.is_valid_int(), "D-345: mã chỉ có số (nhập nhanh bằng bàn phím số): " + code)
	var r: RoomLobby = RoomLobby.new(code, 1)
	assert_eq(r.join(10, 1, "An"), "")
	assert_eq(r.host, 10, "người tạo là chủ phòng")
	assert_eq(r.join(11, 1, "An"), "ALREADY", "một tài khoản một chỗ")
	assert_eq(r.join(12, 2, "Bình"), "")
	assert_eq([r.info[10]["team"], r.info[12]["team"]], [0, 1], "tự chia đội ít người hơn")
	assert_eq(r.join(13, 3, "Chi"), "FULL", "1v1: tối đa 2 người")
	assert_eq(RoomLobby.new("ABCDE", 9).team_size, 5, "NET-07 (D-356): tối đa 5 người mỗi đội")


func test_NET_08_team_hero_and_start() -> void:
	var r: RoomLobby = RoomLobby.new("ABCDE", 3)
	r.join(1, 100, "An")
	r.join(2, 200, "Bình")
	r.join(3, 300, "Chi")
	assert_eq(r.choose_team(3, 0), "")
	assert_eq(r.pick(1, &"gorran", SIX), "")
	assert_eq(r.pick(2, &"gorran", SIX), "HERO_TAKEN", "MATCH-02: không trùng tướng")
	assert_eq(r.pick(2, &"nobody", SIX), "UNKNOWN_HERO")
	assert_eq(r.pick(2, &"myra", SIX), "")
	assert_eq(r.can_start(2), "NOT_HOST")
	assert_eq(r.can_start(1), "NOT_READY", "còn người chưa chọn tướng")
	r.pick(3, &"vexa", SIX)
	assert_eq(r.can_start(1), "")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var made: Dictionary = r.build(SIX, rng)
	var cfg: MatchConfig = made["config"]
	assert_eq(cfg.validate(ContentLibrary.load_dir()), "", "cấu hình hợp lệ, không trùng tướng")
	assert_eq(made["seats"], {1: 0, 3: 1, 2: 3}, "người ở ô đầu mỗi đội theo thứ tự vào phòng")
	assert_eq(cfg.slots.map(func(s: MatchSlot) -> bool: return s.is_bot), [false, false, true, false, true, true])
	assert_eq([cfg.slots[0].hero_id, cfg.slots[1].hero_id, cfg.slots[3].hero_id], [&"gorran", &"vexa", &"myra"])
	assert_eq(r.join(4, 400, "Dũng"), "STARTED", "NET-09: vào trận rồi không nhận thêm")


func test_NET_09_leave_moves_host_and_frees() -> void:
	var r: RoomLobby = RoomLobby.new("ABCDE", 2)
	r.join(1, 100, "An")
	r.join(2, 200, "Bình")
	r.pick(1, &"brakk", SIX)
	r.leave(1)
	assert_eq(r.host, 2, "chủ rời → người vào sớm nhất còn lại")
	assert_eq(r.pick(2, &"brakk", SIX), "", "tướng của người rời được giải phóng")
	assert_eq(r.set_size(2, 1), "")
	r.leave(2)
	assert_true(r.empty())


## NET-07 / NET-08 (D-356): phòng 5v5 — 3 người + 7 bot đủ 10 ô, 10 tướng không trùng (MATCH-02), vào trận được; bot ô 3–4
## (ô thứ 4–5 mỗi đội) đi đúng `bot_lane_order`.
func test_NET_07_five_v_five_room_fills_ten_slots_and_starts() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var heroes: Array[StringName] = []
	heroes.assign(lib.heroes.keys())
	assert_true(heroes.size() >= 10, "đủ tướng cho 5v5 không trùng")
	var r: RoomLobby = RoomLobby.new("123456", 5)
	for k: int in 3:
		assert_eq(r.join(k + 1, 100 + k, "P%d" % k), "")
		assert_eq(r.pick(k + 1, heroes[k], heroes), "")
	assert_eq(r.pick(2, heroes[0], heroes), "HERO_TAKEN", "MATCH-02")
	assert_eq(r.can_start(1), "")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var cfg: MatchConfig = r.build(heroes, rng)["config"]
	assert_eq(cfg.team_size, 5)
	assert_eq(cfg.slots.size(), 10, "10 ô")
	assert_eq(cfg.slots.filter(func(s: MatchSlot) -> bool: return not s.is_bot).size(), 3, "3 người")
	var ids: Dictionary = {}
	for s: MatchSlot in cfg.slots:
		ids[s.hero_id] = true
	assert_eq(ids.size(), 10, "10 tướng không trùng")
	assert_eq(cfg.validate(lib), "", "cấu hình hợp lệ")
	var w: World = World.new(cfg.seed, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = load("res://data/maps/clashborn.tres") as MapLayout
	var made: Array = MatchSetup.build(w, lib, cfg)
	assert_eq(made.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO).size(), 10, "vào trận: 10 hero")
	var order: PackedStringArray = w.balance.bot_lane_order
	for e: Entity in made:
		if e.kind == Entity.Kind.HERO and e.bot != null:
			assert_eq(e.bot.lane, order[e.slot_index % order.size()], "bot ô %d đi đường theo bot_lane_order" % e.slot_index)
	assert_true(made.any(func(e: Entity) -> bool: return e.bot != null and e.slot_index == 4), "có bot ở ô thứ 5")
