extends TestCase
## D-268: phân bố thời gian từng khung — FPS trung bình / thấp nhất, 1% low, P95 / P99, % khung vượt ngưỡng.


func _hist(values: Array) -> FrameHistogram:
	var h: FrameHistogram = FrameHistogram.new()
	for v: float in values:
		h.add(v)
	return h


func test_D_268_average_and_min_fps_from_every_frame() -> void:
	var h: FrameHistogram = _hist([10.0, 10.0, 20.0, 40.0])
	assert_eq(h.count, 4)
	assert_near(h.avg_fps(), 4000.0 / 80.0, 0.001, "FPS trung bình = số khung / tổng thời gian")
	assert_near(h.min_fps(), 25.0, 0.001, "khung chậm nhất 40 ms")


func test_D_268_percentiles_within_one_bin() -> void:
	var values: Array = []
	for i: int in 100:
		values.append(10.0 + i * 0.1)  # 10,0 … 19,9 ms
	var h: FrameHistogram = _hist(values)
	assert_near(h.percentile(0.5), 15.0, FrameHistogram.BIN_MS, "P50")
	assert_near(h.percentile(0.95), 19.5, FrameHistogram.BIN_MS, "P95")
	assert_near(h.percentile(0.99), 19.9, FrameHistogram.BIN_MS, "P99")


func test_D_268_one_percent_low_is_slowest_frames_not_samples() -> void:
	var values: Array = []
	for i: int in 990:
		values.append(16.0)
	for i: int in 10:
		values.append(50.0)  # 1% khung chậm nhất
	var h: FrameHistogram = _hist(values)
	assert_near(h.low_fps(0.01), 20.0, 0.3, "1% low = 1000 / trung bình 1% khung chậm nhất")
	assert_near(h.share_over(33.3), 0.01, 0.0001, "1% khung vượt 33,3 ms")
	assert_near(h.share_over(16.7), 0.01, 0.0001)


func test_D_268_frames_beyond_last_bin_kept_exact() -> void:
	var h: FrameHistogram = _hist([16.0, 500.0])
	assert_near(h.min_fps(), 2.0, 0.001, "khung 500 ms (vượt bảng) vẫn đúng")
	assert_near(h.percentile(1.0), 500.0, 0.001)
	assert_near(h.share_over(250.0), 0.5, 0.0001)


func test_D_268_empty_histogram_reports_zero() -> void:
	var h: FrameHistogram = FrameHistogram.new()
	assert_eq(h.avg_fps(), 0.0)
	assert_eq(h.low_fps(0.01), 0.0)
	assert_eq(h.share_over(16.7), 0.0)
