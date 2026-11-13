class_name SettingsPage
extends Control
## D-413: trang Cài đặt của menu — trái: mục Đồ họa / Âm thanh / Điều khiển / Tài khoản / Công cụ; phải: chỉ những tùy chọn
## game đang có và chạy được (chất lượng 3D 3 mức + hiện FPS — GraphicsSetting; Nhạc và Âm thanh mỗi thứ một công tắc + âm
## lượng — AudioSettings, D-414; tài khoản; công cụ đo: ghi log hiệu năng, đo tự động, kiểm tra đồng bộ). Lưu ngay khi bấm.

signal account_pressed
signal bench_pressed
signal sync_pressed

const SECTIONS: Array[String] = ["Đồ họa", "Âm thanh", "Điều khiển", "Tài khoản", "Công cụ"]
const LEFT_W: float = 360.0
const PAD: float = 40.0
const ROW_H: float = 96.0
const OPT: Vector2 = Vector2(170, 64)
const SLIDER_W: float = 420.0
const CONTROLS: PackedStringArray = ["Điện thoại: cần gạt trái để đi · nút ĐÁNH / Lính / Trụ · nút chiêu: chạm để dùng, kéo để nhắm",
	"Máy tính: WASD đi · J / K / L đánh · 1 / 2 / 3 chiêu · Ctrl+1..4 cộng điểm · 4–9 dùng đồ · H về thành · B shop",
	"M: bật / tắt Âm thanh (không đụng nhạc) · chuột phải: đi tới / khóa mục tiêu · Esc: về menu"]

var section: int = 0
## Tên tài khoản ("" = chưa đăng nhập; APP đặt).
var account_name: String = ""
var version_text: String = ""
var _drag: StringName = &""   ## thanh âm lượng đang kéo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioSettings.ensure()


func section_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAD, 110 + i * 92), Vector2(LEFT_W - PAD, 78))


func row_y(i: int) -> float:
	return 120.0 + i * ROW_H


func option_rect(row: int, i: int) -> Rect2:
	return Rect2(Vector2(size.x - PAD - 40 - (3 - i) * (OPT.x + 12), row_y(row)), OPT)


func toggle_rect(row: int) -> Rect2:
	return option_rect(row, 2)


func slider_rect(row: int) -> Rect2:
	return Rect2(Vector2(toggle_rect(row).position.x - SLIDER_W - 40, row_y(row) + OPT.y * 0.5 - 6), Vector2(SLIDER_W, 12))


func button_rect(row: int) -> Rect2:
	return Rect2(Vector2(size.x - PAD - 40 - 360, row_y(row)), Vector2(360, OPT.y))


func press_at(at: Vector2) -> void:
	for i: int in SECTIONS.size():
		if section_rect(i).has_point(at):
			section = i
	match section:
		0:
			_press_graphics(at)
		1:
			_press_audio(at)
		3:
			if button_rect(0).has_point(at):
				account_pressed.emit()
		4:
			_press_tools(at)
	queue_redraw()


func _press_graphics(at: Vector2) -> void:
	for i: int in GraphicsSetting.NAMES.size():
		if option_rect(0, i).has_point(at):
			GraphicsSetting.save_level(i as GraphicsSetting.Level)
			GraphicsSetting.apply(get_viewport(), i as GraphicsSetting.Level)
	if toggle_rect(1).has_point(at):
		GraphicsSetting.save_show_fps(not GraphicsSetting.load_show_fps())


func _press_audio(at: Vector2) -> void:
	if toggle_rect(0).has_point(at):
		AudioSettings.set_music(not AudioSettings.music_on)
	if toggle_rect(1).has_point(at):
		AudioSettings.set_sfx(not AudioSettings.sfx_on)
	for row: int in 2:
		if slider_rect(row).grow(28).has_point(at):
			_drag = [&"music", &"sfx"][row]
			_slide(at)


func _press_tools(at: Vector2) -> void:
	if toggle_rect(0).has_point(at):
		PerfSettings.save_enabled(not PerfSettings.enabled())  # MATCH-06: bật thì các trận sau là trận thử
	if button_rect(1).has_point(at):
		bench_pressed.emit()
	if button_rect(2).has_point(at):
		sync_pressed.emit()


## Âm lượng theo vị trí ngang trên thanh đang kéo.
func _slide(at: Vector2) -> void:
	var r: Rect2 = slider_rect(0 if _drag == &"music" else 1)
	var v: float = clampf((at.x - r.position.x) / r.size.x, 0.0, 1.0)
	if _drag == &"music":
		AudioSettings.set_music_volume(v)
	else:
		AudioSettings.set_sfx_volume(v)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and _drag != &"":
		_slide((event as InputEventScreenDrag).position)
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_drag = &""
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
	accept_event()


func _draw() -> void:
	UiStyle.panel(self, Rect2(Vector2(PAD - 16, 24), Vector2(LEFT_W, size.y - 48)))
	draw_string(UiStyle.serif(true), Vector2(PAD, 82), "Cài đặt", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiStyle.GOLD)
	for i: int in SECTIONS.size():
		UiStyle.button(self, section_rect(i), &"gold" if i == section else &"ghost", SECTIONS[i], "", 30)
	UiStyle.panel(self, Rect2(Vector2(LEFT_W + PAD, 24), Vector2(size.x - LEFT_W - PAD * 2, size.y - 48)))
	SettingsPagePainter.draw(self)
