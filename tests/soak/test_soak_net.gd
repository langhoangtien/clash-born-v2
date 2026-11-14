extends TestCase
## M9.4 soak (D-337 mục 8, chạy riêng: --soak): lockstep qua mạng giả ở nhiều điều kiện — RTT 20 / 50 / 100 / 150 ms,
## dao động 10–50 ms, mất gói 1–5 %, mỗi kiểu 30 giây trận 3v3 (2 người + 4 bot). Không máy nào lệch; in số đo
## (RTT, trễ bấm → hiệu lực, số khung chờ, hàng gói tối đa) để so khi đổi input_delay / kiểu kết nối.

const Lock = preload("res://tests/app/net/test_lockstep.gd")
const CASES: Array = [[20.0, 10.0, 0.01], [50.0, 20.0, 0.02], [100.0, 30.0, 0.03], [150.0, 50.0, 0.05]]


func test_M9_4_network_matrix_no_desync() -> void:
	var lock: Object = Lock.new()
	for k: int in CASES.size():
		var rtt: float = CASES[k][0]
		var h: Dictionary = lock._setup(rtt, CASES[k][1], CASES[k][2], 100 + k)
		lock._run(h, 30.0)
		var room: LockstepRoom = h["room"]
		assert_eq(room.desyncs.size(), 0, "RTT %.0f: không lệch" % rtt)
		assert_true(lock._same_hashes(h) > 0)
		for c: LockstepClient in h["clients"]:
			print("  RTT %3.0f ms ±%2.0f, mất %d%%: đo RTT %5.1f ±%4.1f ms, trễ bấm→hiệu lực %5.1f ms, đệm %d tick, đứng hình %d / chờ đệm %d khung (/1800), hàng gói tối đa %d" % [
				rtt, CASES[k][1], int(CASES[k][2] * 100), c.rtt_ms, c.jitter_ms, c.input_latency_ms, c.buffer_target, c.stalls, c.holds, c.max_backlog])
			assert_true(room.tick - c.world.tick <= 15, "theo kịp máy chủ")


## M9.7 soak (D-402, NET-16 / NET-17): trận 3v3 qua mạng giả (RTT 80 ± 20 ms, mất 2 %), 3 seed: một người mất mạng ở giây
## 40 → máy chủ coi rớt sau 5 giây im lặng, bot (SET_CONTROL) đánh thay; chạy tới phút thứ 3 — không máy nào lệch, hero
## của người rớt có bot trên mọi máy còn lại.
func test_NET_17_drop_mid_match_soak_no_desync() -> void:
	var lock: Object = Lock.new()
	for k: int in 3:
		var h: Dictionary = lock._setup(80.0, 20.0, 0.02, 300 + k)
		var room: LockstepRoom = h["room"]
		room.takeover = Command.set_control
		var drops: Array = []
		room.on_drop = func(peer: int, _e: int, reason: String) -> void: drops.append([peer, reason, room.tick])
		lock._run(h, 40.0)
		(h["clients"][1] as LockstepClient).transport.close()
		lock._run(h, 140.0)
		assert_eq(drops.size(), 1, "seed %d: một người rớt" % k)
		assert_eq(room.desyncs.size(), 0, "seed %d: không lệch" % k)
		assert_true(lock._same_hashes(h) >= 30, "seed %d: mốc mã băm chung (máy chủ giữ 40 mốc cuối; mọi mốc khác đã so trực tiếp — desyncs)" % k)
		var c0: LockstepClient = h["clients"][0]
		assert_true(c0.world.find_entity(h["heroes"][1]).bot != null, "seed %d: bot đánh thay trên máy còn lại" % k)
		assert_true(room.tick - c0.world.tick <= 15, "theo kịp máy chủ")
		print("  seed %d: rớt ở tick %d (%s), trận tới tick %d, không lệch" % [k, drops[0][2], drops[0][1], room.tick])


## M9.8 soak (D-406, NET-22 / NET-18): 3v3 mạng giả (RTT 80 ± 20 ms, mất 2 %), 3 seed: một người mất mạng ở giây 60, vào lại
## bằng kết nối mới sau 20 giây (tua nhật ký), chạy tới phút thứ 4 — không lệch, người vào lại cầm lại hero.
func test_NET_22_rejoin_soak_no_desync() -> void:
	var lock: Object = Lock.new()
	for k: int in 3:
		var h: Dictionary = lock._setup(80.0, 20.0, 0.02, 400 + k)
		var room: LockstepRoom = h["room"]
		room.takeover = Command.set_control
		lock._run(h, 60.0)
		var old: LockstepClient = h["clients"][1]
		old.transport.close()
		lock._run(h, 20.0)
		var cfg: MatchConfig = MatchConfig.make(3, Lock.SIX, Lock.HUMANS, BotState.Difficulty.NORMAL, 31)
		var ends: Array = (h["net"] as LoopbackNet).link(80.0, 20.0, 0.02)
		var c: LockstepClient = LockstepClient.new(ends[0])
		c.attach(lock._world(cfg), room.input_delay, 9)
		c.resume_to = room.tick
		room.rejoin_peer(9, ends[1], h["heroes"][1])
		h["clients"][1] = c
		var t0: int = room.tick
		for i: int in 120:
			if c.resume_to < 0:
				break
			lock._run(h, 0.5)
		assert_eq(c.resume_to, -1, "seed %d: tua kịp" % k)
		var caught: int = room.tick - t0
		lock._run(h, 240.0 - room.tick / 30.0)
		assert_eq(room.desyncs.size(), 0, "seed %d: không lệch" % k)
		assert_true(lock._same_hashes(h) >= 30)
		assert_true(c.world.find_entity(h["heroes"][1]).bot == null, "seed %d: cầm lại hero" % k)
		assert_true(room.tick - c.world.tick <= 15, "theo kịp máy chủ")
		print("  seed %d: vào lại ở tick %d, kịp sau %d tick máy chủ, trận tới tick %d, không lệch" % [k, t0, caught, room.tick])


## D-356 soak: trận 5v5 qua mạng giả (RTT 80 ± 20 ms, mất 2 %) — 2 người (ô đầu mỗi đội) + 8 bot, 60 giây trận, 10 tướng
## không trùng: không máy nào lệch, mọi mốc mã băm khớp máy chủ.
func test_D_356_five_v_five_network_soak_no_desync() -> void:
	var lock: Object = Lock.new()
	var ten: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh", &"huyet_cu_nhan", &"phong_tien",
		&"tho_san", &"thach_giap"]
	var humans: Array[int] = [0, 5]
	var cfg: MatchConfig = MatchConfig.make(5, ten, humans, BotState.Difficulty.NORMAL, 57)
	assert_eq(cfg.validate(ContentLibrary.load_dir()), "")
	var h: Dictionary = lock._setup(80.0, 20.0, 0.02, 211, cfg, humans)
	var t0: int = Time.get_ticks_msec()
	lock._run(h, 60.0)
	var room: LockstepRoom = h["room"]
	assert_eq(room.tick, 1800)
	assert_eq(room.desyncs.size(), 0, "5v5: không lệch")
	assert_true(lock._same_hashes(h) >= 2 * LockstepRoom.HASH_KEEP - 2, "mọi mốc máy chủ còn giữ (HASH_KEEP) đều khớp ở cả hai máy khách")
	assert_eq(room.world.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO).size(), 10)
	print("  5v5 mạng giả 60 s trận (3 bản SIM) trong %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
