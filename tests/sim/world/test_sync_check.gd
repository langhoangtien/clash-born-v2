extends TestCase
## M9.3 (D-336): kiểm tra tất định — cùng cấu hình chạy hai lần ra cùng chuỗi mã băm từng giây, từng đơn vị.


func test_M9_3_sync_check_same_chain_twice() -> void:
	var a: SyncCheck = SyncCheck.new(4)
	var b: SyncCheck = SyncCheck.new(4)
	while not a.done():
		a.advance(37)  # đoạn lẻ: cách chia đoạn không đổi kết quả
	while not b.done():
		b.advance(120)
	assert_eq(a.seconds.size(), 4, "mỗi giây một mốc")
	assert_eq(a.seconds.map(func(s: Dictionary) -> String: return s["hash"]), b.seconds.map(func(s: Dictionary) -> String: return s["hash"]))
	assert_eq(a.seconds[3]["units"], b.seconds[3]["units"])
	assert_true(a.seconds[3]["units"].size() > 20, "có mã băm từng đơn vị (công trình, hero, lính)")
	assert_eq(a.result({"device": "x"})["meta"]["seed"], SyncCheck.SEED)
