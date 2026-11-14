class_name SettingsControl
extends RefCounted
## D-183: nối bảng Cài đặt trong trận với nơi áp — tầng APP. Nhạc / Âm thanh (AudioSettings, D-414: hai công tắc riêng),
## đồ họa (GraphicsSetting, áp ngay vào khung nhìn), hiện FPS (MatchHud), thoát trận; chỉ trận thử (MATCH-06) có mở / tắt
## bảng Test, bảng Chẩn đoán, xuất log. Không dừng trận. Menu dùng trang Cài đặt (SettingsPage, D-413).

var panel: SettingsPanel
var viewport: Viewport
var hud: MatchHud
var tools: Dictionary[StringName, Control] = {}
## D-268: phiên ghi log hiệu năng của trận.
var perf: PerfSession
var quit: Callable


static func attach(layer: Node, practice: bool = false) -> SettingsControl:
	var s: SettingsControl = SettingsControl.new()
	s.panel = SettingsPanel.new()
	s.panel.name = "SettingsPanel"
	s.panel.practice = practice
	s.panel.version_text = Updater.current_name()  # D-267
	layer.add_child(s.panel)
	s.panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.viewport = s.panel.get_viewport()
	s.panel.action.connect(s.apply)
	s.refresh()
	return s


func apply(what: StringName) -> void:
	match what:
		&"music":  # D-414: chỉ nhạc
			AudioSettings.set_music(not AudioSettings.music_on)
		&"sfx":  # D-414: chỉ âm thanh (tiếng động, tiếng nền) — phím M cũng là cái này
			AudioSettings.set_sfx(not AudioSettings.sfx_on)
		&"graphics":
			GraphicsSetting.apply(viewport, GraphicsSetting.cycle())
		&"fps":
			GraphicsSetting.save_show_fps(not GraphicsSetting.load_show_fps())
		&"test", &"diag":
			tools[what].visible = not tools[what].visible
		&"perf_export":
			if perf != null:
				perf.export_now()
		&"quit":
			quit.call()
			return
	refresh()


## Chữ giá trị các hàng theo trạng thái hiện tại; báo HUD bật / tắt FPS.
func refresh() -> void:
	AudioSettings.ensure()
	panel.values = {
		&"music": "Bật" if AudioSettings.music_on else "Tắt",
		&"sfx": "Bật" if AudioSettings.sfx_on else "Tắt",
		&"graphics": GraphicsSetting.NAMES[GraphicsSetting.load_level()],
		&"fps": "Bật" if GraphicsSetting.load_show_fps() else "Tắt",
		&"perf_export": "Xuất",
	}
	for key: StringName in tools:
		panel.values[key] = "Đang hiện" if tools[key].visible else "Ẩn"
	if hud != null:
		hud.show_fps = GraphicsSetting.load_show_fps()
	panel.queue_redraw()
