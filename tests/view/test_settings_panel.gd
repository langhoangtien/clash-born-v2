extends TestCase
## D-183: bảng Cài đặt trong trận (kiểu Liên Quân) — mở bằng nút bánh răng, có Nhạc, Âm thanh (D-414: riêng), đồ họa,
## FPS, công cụ thử, thoát trận. Bảng chỉ báo lựa chọn (`action`); APP áp. Không dừng trận. Menu: trang Cài đặt (D-413).


func _panel(_in_match: bool = true) -> SettingsPanel:
	var p: SettingsPanel = SettingsPanel.new()
	p.size = Vector2(1920, 1080)
	return p


func test_D_183_gear_opens_and_rows_report_action() -> void:
	var p: SettingsPanel = _panel(true)
	var got: Array[StringName] = []
	p.action.connect(func(what: StringName) -> void: got.append(what))
	assert_false(p.open)
	p.press_at(p.gear_rect().get_center())
	assert_true(p.open, "bấm bánh răng mở bảng")
	p.press_at(p.row_rect(p.rows().find(&"graphics")).get_center())
	assert_eq(got, [&"graphics"] as Array[StringName], "bấm hàng đồ họa báo đổi đồ họa")
	p.press_at(p.close_rect().get_center())
	assert_false(p.open, "nút ✕ đóng bảng")
	p.free()


func test_D_183_rows_in_match() -> void:
	var m: SettingsPanel = _panel(true)
	assert_eq(m.rows(), [&"music", &"sfx", &"graphics", &"fps", &"quit"] as Array[StringName],
		"MATCH-06: trận thường không có công cụ thử; D-414: Nhạc và Âm thanh hai hàng riêng")
	m.practice = true
	assert_eq(m.rows(), [&"music", &"sfx", &"graphics", &"fps", &"test", &"diag", &"perf_export", &"quit"] as Array[StringName],
		"trận thử: bảng Test, chẩn đoán, xuất log")
	m.free()


func test_D_183_closed_panel_ignores_rows() -> void:
	var p: SettingsPanel = _panel(true)
	var got: Array[StringName] = []
	p.action.connect(func(what: StringName) -> void: got.append(what))
	p.press_at(p.row_rect(0).get_center())
	assert_eq(got.size(), 0)
	p.free()


func test_D_183_show_fps_default_on_and_saved() -> void:
	assert_true(GraphicsSetting.SHOW_FPS_DEFAULT, "bản thử hiện FPS mặc định")


func test_D_267_version_line_below_rows() -> void:
	var p: SettingsPanel = _panel(true)
	p.version_text = "0.1.449"
	assert_eq(p.version_line(), "Phiên bản 0.1.449")
	var last: Rect2 = p.row_rect(p.rows().size() - 1)
	assert_true(p.panel_rect().end.y >= last.end.y + SettingsPanel.VERSION_H, "bảng chừa chỗ cho dòng phiên bản dưới hàng cuối")
	p.version_text = ""
	assert_eq(p.version_line(), "Phiên bản: chạy từ editor", "không có build.json (chạy từ editor)")
	p.free()


func test_D_267_version_name_read_from_build_info() -> void:
	assert_eq(Updater.version_name_from({"code": 449, "name": "0.1.449"}), "0.1.449")
	assert_eq(Updater.version_name_from({}), "")


func test_D_342_pc_run_without_build_json_uses_export_presets_version() -> void:
	var name: String = Updater.presets_name(Updater.PRESETS)
	assert_true(RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+$").search(name) != null, "dạng 0.1.N (máy chủ thống kê nhận): " + name)
	assert_eq(Updater.presets_name("res://khong_co.cfg"), "")
