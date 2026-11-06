extends TestCase
## D-268: bộ ghi hiệu năng — mẫu 0,5 s, khung giật > 33,3 ms kèm bối cảnh, mốc bật / tắt đồ họa, tóm tắt, CSV / JSON.


## Khung giả: µs theo phần như FrameProfile (frame = cả khung).
func _frame(frame_ms: float, sim_ms: float = 2.0, gpu_ms: float = 8.0) -> Dictionary:
	return {&"frame": int(frame_ms * 1000), &"process": 4000, &"sim": int(sim_ms * 1000), &"hud": 1000,
		&"draw2d": 3000, &"render": 2000, &"gpu": int(gpu_ms * 1000)}


func _recorder(ctx: Dictionary = {}) -> PerfRecorder:
	var r: PerfRecorder = PerfRecorder.new()
	var c: Dictionary = {&"tick": 900, &"heroes": 2, &"objects": 5000, &"entities": 100}
	c.merge(ctx, true)
	r.context = func() -> Dictionary: return c
	r.start(0)
	return r


## Chạy `n` khung đều `ms` mili giây, bắt đầu từ `t` µs; trả về thời điểm cuối.
func _run(r: PerfRecorder, t: int, n: int, ms: float, gpu_ms: float = 8.0) -> int:
	for i: int in n:
		t += int(ms * 1000)
		r.on_frame(_frame(ms, 2.0, gpu_ms), t)
	return t


func test_D_268_one_row_every_half_second_with_averages() -> void:
	var r: PerfRecorder = _recorder()
	_run(r, 0, 60, 20.0)  # 1,2 s
	assert_eq(r.rows.size(), 2, "mỗi 0,5 s một dòng")
	var row: Dictionary = r.row_dict(0)
	assert_near(float(row["frame_avg_ms"]), 20.0, 0.01)
	assert_near(float(row["fps"]), 50.0, 0.5)
	assert_near(float(row["sim_ms"]), 2.0, 0.01)
	assert_near(float(row["bones_ms"]), 2.0, 0.01, "xương = cuối khung 3 − HUD 1")
	assert_eq(row["heroes"], "2", "bối cảnh lấy lúc ghi dòng")
	assert_eq(r.hist.count, 60, "phân bố tính mọi khung")


func test_D_268_spike_recorded_with_context() -> void:
	var r: PerfRecorder = _recorder({&"lane_creeps": 40})
	var t: int = _run(r, 0, 10, 16.0)
	r.on_frame(_frame(50.0, 30.0), t + 50_000)
	assert_eq(r.spikes.size(), 1, "khung 50 ms > 33,3 ms")
	var s: Dictionary = r.spikes[0]
	assert_near(float(s["frame_ms"]), 50.0, 0.01)
	assert_near(float(s["sections"]["sim_ms"]), 30.0, 0.01, "ghi phần nào nặng trong chính khung đó")
	assert_eq(s["context"]["lane_creeps"], 40)


func test_D_268_spikes_capped() -> void:
	var r: PerfRecorder = _recorder()
	var t: int = 0
	for i: int in PerfRecorder.SPIKE_CAP + 20:
		t += 40_000
		r.on_frame(_frame(40.0), t)
	assert_eq(r.spikes.size(), PerfRecorder.SPIKE_CAP, "giữ tối đa SPIKE_CAP lần giật (bộ nhớ cố định)")
	assert_eq(r.spike_total, PerfRecorder.SPIKE_CAP + 20, "nhưng đếm đủ")


func test_D_268_markers_and_graphics_state_in_rows() -> void:
	var r: PerfRecorder = _recorder()
	var t: int = _run(r, 0, 30, 20.0)
	r.mark(&"fog", 0, t)
	_run(r, t, 30, 20.0)
	assert_eq(r.markers.size(), 1)
	assert_eq(r.markers[0]["key"], "fog")
	assert_eq(r.row_dict(r.rows.size() - 1)["graphics_off"], "fog", "dòng sau mốc ghi phần đang tắt")


func test_D_268_gpu_not_supported_is_na() -> void:
	var r: PerfRecorder = _recorder()
	_run(r, 0, 30, 20.0, 0.0)
	assert_eq(r.row_dict(0)["gpu_ms"], "N/A", "máy không đo được GPU: ghi N/A, không ghi 0")
	assert_eq(PerfReport.summary(r)["gpu_ms"], "N/A")


func test_D_268_missing_context_is_na() -> void:
	var r: PerfRecorder = _recorder()
	_run(r, 0, 30, 20.0)
	assert_eq(r.row_dict(0)["video_mem_mb"], "N/A")


func test_D_268_summary_thresholds_and_growth() -> void:
	var c: Dictionary = {&"tick": 0, &"objects": 5000, &"entities": 100}
	var r: PerfRecorder = PerfRecorder.new()
	r.context = func() -> Dictionary: return c
	r.start(0)
	var t: int = 0
	for second: int in 120:
		c[&"objects"] = 5000 + second * 10  # +600 / phút
		t = _run(r, t, 50, 20.0)
	var s: Dictionary = PerfReport.summary(r)
	assert_near(float(s["share_over_16_7"]), 1.0, 0.001)
	assert_near(float(s["share_over_33_3"]), 0.0, 0.001)
	assert_near(float(s["objects_per_min"]), 600.0, 15.0, "object tăng theo phút")
	assert_near(float(s["avg_fps"]), 50.0, 0.01)


func test_D_268_csv_header_and_rows_match() -> void:
	var r: PerfRecorder = _recorder()
	_run(r, 0, 60, 20.0)
	var lines: PackedStringArray = PerfReport.csv(r, 0).strip_edges().split("\n")
	assert_eq(lines.size(), 1 + r.rows.size(), "dòng tiêu đề + mỗi mẫu một dòng")
	assert_eq(lines[0].split(",").size(), lines[1].split(",").size(), "số cột khớp")
	assert_eq(PerfReport.csv(r, 1, false).strip_edges().split("\n").size(), 1, "ghi theo lô: chỉ dòng mới, không tiêu đề")


func test_D_268_json_has_meta_summary_rows() -> void:
	var r: PerfRecorder = _recorder()
	r.meta = {"version": "0.1.999"}
	_run(r, 0, 60, 20.0)
	var data: Variant = JSON.parse_string(PerfReport.json(r))
	assert_true(data is Dictionary)
	assert_eq(data["meta"]["version"], "0.1.999")
	assert_true(data["summary"].has("low_1pct_fps"))
	assert_eq(data["rows"].size(), r.rows.size())
	assert_eq(data["columns"].size(), PerfRecorder.COLUMNS.size())


func test_D_268_summary_text_is_short() -> void:
	var r: PerfRecorder = _recorder()
	r.meta = {"version": "0.1.999", "device": "Test"}
	_run(r, 0, 60, 20.0)
	var text: String = PerfReport.summary_text(r)
	assert_true(text.contains("0.1.999"))
	assert_true(text.contains("1% low"))
	assert_true(text.split("\n").size() <= 40, "đủ ngắn để dán vào chat")
