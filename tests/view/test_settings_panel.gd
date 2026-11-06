extends TestCase
## D-183: bảng Cài đặt (kiểu Liên Quân) — trong trận mở bằng nút bánh răng, có âm thanh, đồ họa, FPS, công cụ
## thử, thoát trận; ở menu chỉ âm thanh, đồ họa, FPS. Bảng chỉ báo lựa chọn (`action`); APP áp. Không dừng trận.


func _panel(in_match: bool) -> SettingsPanel:
	var p: SettingsPanel = SettingsPanel.new()
	p.size = Vector2(1920, 1080)
	p.in_match = in_match
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


func test_D_183_rows_in_match_and_menu() -> void:
	var m: SettingsPanel = _panel(true)
	assert_eq(m.rows(), [&"sound", &"graphics", &"fps", &"perf_log", &"test", &"diag", &"perf_export", &"quit"] as Array[StringName],
		"D-268: ghi log hiệu năng + xuất log trong trận")
	var menu: SettingsPanel = _panel(false)
	assert_eq(menu.rows(), [&"sound", &"graphics", &"fps", &"perf_log"] as Array[StringName], "menu không có công cụ thử / thoát trận")
	assert_false(menu.gear_rect().has_area(), "menu tự có nút Cài đặt, không vẽ bánh răng")
	m.free()
	menu.free()


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
