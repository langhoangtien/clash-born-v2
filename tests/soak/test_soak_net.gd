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
