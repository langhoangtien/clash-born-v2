extends TestCase
## D-261: FrameProfile đo µs mỗi khung theo từng phần, công bố trung bình / đỉnh mỗi cửa sổ 1 giây.


func test_D_261_sections_add_up_within_a_frame() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.add(&"sim", 100, 600)
	p.add(&"sim", 1000, 1500)
	p.add(&"hud", 2000, 2200)
	p.next_frame(FrameProfile.WINDOW_USEC)
	assert_near(p.avg_ms.get(&"sim", -1.0), 1.0, 0.0001, "hai lần đo cùng phần trong một khung cộng dồn")
	assert_near(p.avg_ms.get(&"hud", -1.0), 0.2, 0.0001)


func test_D_261_average_and_peak_per_window() -> void:
	var p: FrameProfile = FrameProfile.new()
	var t: int = 0
	p.next_frame(t)
	for us: int in [1000, 3000, 2000, 2000]:
		p.add(&"actors", t, t + us)
		t += 250_000
		p.next_frame(t)
	assert_near(p.avg_ms[&"actors"], 2.0, 0.0001, "trung bình 4 khung")
	assert_near(p.peak_ms[&"actors"], 3.0, 0.0001, "khung nặng nhất")
	assert_near(p.avg_ms[&"frame"], 250.0, 0.0001, "khoảng cách giữa hai lần next_frame")


func test_D_261_nothing_published_before_window_ends() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.add(&"sim", 0, 500)
	p.next_frame(1000)
	assert_true(p.avg_ms.is_empty(), "chưa đủ 1 giây thì chưa công bố")


func test_D_261_section_missing_in_some_frames_counts_as_zero() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.add(&"fx", 0, 4000)
	p.next_frame(500_000)
	p.next_frame(FrameProfile.WINDOW_USEC)
	assert_near(p.avg_ms[&"fx"], 2.0, 0.0001, "khung không đo phần đó = 0 ms")
	assert_near(p.peak_ms[&"fx"], 4.0, 0.0001)


func test_D_261_window_resets_after_publish() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.add(&"sim", 0, 8000)
	p.next_frame(FrameProfile.WINDOW_USEC)
	p.add(&"sim", 0, 1000)
	p.next_frame(FrameProfile.WINDOW_USEC * 2)
	assert_near(p.avg_ms[&"sim"], 1.0, 0.0001, "cửa sổ sau không mang số cửa sổ trước")
	assert_near(p.peak_ms[&"sim"], 1.0, 0.0001)


func test_D_261_counts_keep_latest_value() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.set_count(&"actors", 12)
	p.set_count(&"actors", 15)
	assert_eq(p.counts[&"actors"], 15)


func test_D_261_report_lists_heaviest_section_first() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.add(&"hud", 0, 1000)
	p.add(&"sim", 0, 3000)
	p.next_frame(FrameProfile.WINDOW_USEC)
	var keys: Array[StringName] = p.sections_by_cost()
	assert_eq(keys[0], &"sim")
	assert_true(not keys.has(&"frame"), "tổng khung hiện riêng, không xếp chung")


func _measured() -> FrameProfile:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.add(&"process", 0, 10_000)
	p.add(&"scene", 0, 8000)
	p.add(&"sim", 0, 3000)
	p.add(&"actors", 0, 2000)
	p.next_frame(FrameProfile.WINDOW_USEC)
	return p


func test_D_261_rows_show_remainder_of_parent_sections() -> void:
	var got: Dictionary = {}
	for r: Array in ProfilePainter.rows(_measured()):
		got[r[0]] = r[1]
	assert_near(got[ProfilePainter.LABELS[&"scene_other"]], 3.0, 0.0001, "màn trận 8 − SIM 3 − nhân vật 2")
	assert_near(got[ProfilePainter.LABELS[&"process_other"]], 2.0, 0.0001, "_process 10 − màn trận 8")
	assert_true(not got.has(ProfilePainter.LABELS[&"gpu"]), "phần chưa đo thì không hiện")


func test_D_261_count_lines_show_counters() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.set_count(&"actors", 37)
	p.set_count(&"nodes", 2100)
	var text: String = "\n".join(ProfilePainter.count_lines(p))
	assert_true(text.contains("hình 3D 37"), text)
	assert_true(text.contains("Node 2100"), text)


func test_D_261_profile_area_catches_taps() -> void:
	var d: DiagPanel = DiagPanel.new()
	d.open = true
	assert_true(d._has_point(DiagPanel.PROFILE.get_center()), "chạm vào bảng đo không lọt xuống trận")
	d.free()
