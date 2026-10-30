class_name SettingsControl
extends RefCounted
## D-183: nối bảng Cài đặt với nơi áp — tầng APP, dùng chung cho menu và trận. Âm thanh (AudioView, lưu
## settings.cfg), đồ họa (GraphicsSetting, áp ngay vào khung nhìn), hiện FPS (MatchHud); trong trận thêm mở /
## tắt bảng Test, bảng Chẩn đoán và thoát trận. Không dừng trận.

var panel: SettingsPanel
var audio: AudioView
var viewport: Viewport
## Trong trận (null ở menu).
var hud: MatchHud
var tools: Dictionary[StringName, Control] = {}
var quit: Callable


static func attach(layer: Node, in_match: bool, audio_view: AudioView) -> SettingsControl:
	var s: SettingsControl = SettingsControl.new()
	s.audio = audio_view
	s.panel = SettingsPanel.new()
	s.panel.name = "SettingsPanel"
	s.panel.in_match = in_match
	layer.add_child(s.panel)
	s.panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.viewport = s.panel.get_viewport()
	s.panel.action.connect(s.apply)
	s.refresh()
	return s


func apply(what: StringName) -> void:
	match what:
		&"sound":
			audio.cycle_mode()
		&"graphics":
			GraphicsSetting.apply(viewport, GraphicsSetting.cycle())
		&"fps":
			GraphicsSetting.save_show_fps(not GraphicsSetting.load_show_fps())
		&"test", &"diag":
			tools[what].visible = not tools[what].visible
		&"quit":
			quit.call()
			return
	refresh()


## Chữ giá trị các hàng theo trạng thái hiện tại; báo HUD bật / tắt FPS.
func refresh() -> void:
	AudioView.load_mode()
	panel.values = {
		&"sound": AudioView.MODE_NAMES[maxi(AudioView.mode, 0)],
		&"graphics": GraphicsSetting.NAMES[GraphicsSetting.load_level()],
		&"fps": "Bật" if GraphicsSetting.load_show_fps() else "Tắt",
	}
	for key: StringName in tools:
		panel.values[key] = "Đang hiện" if tools[key].visible else "Ẩn"
	if hud != null:
		hud.show_fps = GraphicsSetting.load_show_fps()
	panel.queue_redraw()
