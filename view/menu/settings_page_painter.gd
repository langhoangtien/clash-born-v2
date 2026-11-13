class_name SettingsPagePainter
extends RefCounted
## D-413: vẽ phần bên phải của trang Cài đặt theo mục đang chọn (SettingsPage giữ vị trí nút và xử lý bấm).


static func draw(p: SettingsPage) -> void:
	var x: float = SettingsPage.LEFT_W + SettingsPage.PAD + 40
	match p.section:
		0:
			var lv: int = GraphicsSetting.load_level()
			_label(p, x, 0, "Chất lượng cảnh 3D", "Độ phân giải cảnh trận: Thấp 50% · Vừa 75% · Cao 100%")
			for i: int in GraphicsSetting.NAMES.size():
				UiStyle.button(p, p.option_rect(0, i), &"gold" if i == lv else &"ghost", GraphicsSetting.NAMES[i], "", 26)
			_label(p, x, 1, "Hiện FPS trong trận", "FPS · thời gian SIM mỗi tick, góc màn hình")
			_toggle(p, p.toggle_rect(1), GraphicsSetting.load_show_fps())
		1:
			_label(p, x, 0, "Nhạc", "Nhạc nền menu và trận")
			_slider(p, p.slider_rect(0), AudioSettings.music_volume, AudioSettings.music_on)
			_toggle(p, p.toggle_rect(0), AudioSettings.music_on)
			_label(p, x, 1, "Âm thanh", "Tiếng đánh, chiêu, thông báo, tiếng nền map — phím M trong trận")
			_slider(p, p.slider_rect(1), AudioSettings.sfx_volume, AudioSettings.sfx_on)
			_toggle(p, p.toggle_rect(1), AudioSettings.sfx_on)
		2:
			p.draw_string(UiStyle.serif(true), Vector2(x, p.row_y(0) + 30), "Điều khiển", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.TEXT)
			for i: int in SettingsPage.CONTROLS.size():
				p.draw_multiline_string(UiStyle.sans(), Vector2(x, p.row_y(0) + 84 + i * 84), SettingsPage.CONTROLS[i],
					HORIZONTAL_ALIGNMENT_LEFT, p.size.x - x - 80, 24, 2, UiStyle.DIM)
		3:
			_label(p, x, 0, p.account_name if p.account_name != "" else "Chưa đăng nhập",
				"Đăng nhập, đổi tên, lịch sử trận, đăng xuất")
			UiStyle.button(p, p.button_rect(0), &"blue", "Mở tài khoản", "", 26)
		4:
			_label(p, x, 0, "Ghi log hiệu năng", "Bật thì các trận sau là trận thử (không tính thống kê)")
			_toggle(p, p.toggle_rect(0), PerfSettings.enabled())
			_label(p, x, 1, "Đo hiệu năng tự động", "Trận cố định hai bot, ghi log để so sánh")
			UiStyle.button(p, p.button_rect(1), &"blue", "Bắt đầu", "", 26)
			_label(p, x, 2, "Kiểm tra đồng bộ (online)", "Chạy trận 3v3 bot cố định, gửi mã băm lên máy chủ")
			UiStyle.button(p, p.button_rect(2), &"blue", "Bắt đầu", "", 26)
	var v: String = "Phiên bản " + p.version_text if p.version_text != "" else "Phiên bản: chạy từ editor"
	p.draw_string(UiStyle.sans(), Vector2(x, p.size.y - 56), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UiStyle.TEXT, 0.6))


static func _label(p: SettingsPage, x: float, row: int, title: String, sub: String) -> void:
	var y: float = p.row_y(row)
	p.draw_string(UiStyle.serif(true), Vector2(x, y + 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.TEXT)
	p.draw_string(UiStyle.sans(), Vector2(x, y + 62), sub, HORIZONTAL_ALIGNMENT_LEFT, 640, 20, UiStyle.DIM)
	UiStyle.divider(p, Vector2(x, y + SettingsPage.ROW_H - 12), Vector2(p.size.x - SettingsPage.PAD - 40, y + SettingsPage.ROW_H - 12))


static func _toggle(p: SettingsPage, r: Rect2, on: bool) -> void:
	UiStyle.button(p, r, &"gold" if on else &"ghost", "Bật" if on else "Tắt", "", 26)


static func _slider(p: SettingsPage, r: Rect2, v: float, on: bool) -> void:
	var col: Color = UiStyle.GOLD if on else UiStyle.DIM
	p.draw_style_box(UiStyle.box(Color(0.1, 0.13, 0.2), UiStyle.LINE, 1, 6), r)
	p.draw_style_box(UiStyle.box(Color(col, 0.85), Color(0, 0, 0, 0), 0, 6), Rect2(r.position, Vector2(r.size.x * v, r.size.y)))
	p.draw_circle(Vector2(r.position.x + r.size.x * v, r.get_center().y), 16.0, col)
	p.draw_string(UiStyle.sans(true), Vector2(r.end.x - 60, r.position.y - 14), "%d%%" % roundi(v * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 60, 20, col)
