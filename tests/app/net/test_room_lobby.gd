extends TestCase
## NET-07..09 (D-338): phòng chờ — mã phòng, vào / rời, chủ phòng, đội, tướng không trùng, bắt đầu → MatchConfig.

const SIX: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]


func test_NET_07_code_and_join_rules() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var code: String = RoomLobby.new_code(rng)
	assert_eq(code.length(), 5)
	for ch: String in code:
		assert_true(RoomLobby.CODE_CHARS.contains(ch) and not "O0I1".contains(ch))
	var r: RoomLobby = RoomLobby.new(code, 1)
	assert_eq(r.join(10, 1, "An"), "")
	assert_eq(r.host, 10, "người tạo là chủ phòng")
	assert_eq(r.join(11, 1, "An"), "ALREADY", "một tài khoản một chỗ")
	assert_eq(r.join(12, 2, "Bình"), "")
	assert_eq([r.info[10]["team"], r.info[12]["team"]], [0, 1], "tự chia đội ít người hơn")
	assert_eq(r.join(13, 3, "Chi"), "FULL", "1v1: tối đa 2 người")
	assert_eq(RoomLobby.new("ABCDE", 9).team_size, 3, "NET-07: tối đa 3 người mỗi đội")


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
