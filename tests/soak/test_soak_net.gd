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
