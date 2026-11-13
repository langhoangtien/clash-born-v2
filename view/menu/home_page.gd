class_name HomePage
extends Control
## D-413: Trang chủ — ảnh nền toàn màn, tên game + "MOBA chiến thuật 5v5", nút lớn CHƠI (mở Chọn chế độ), hai thẻ: Bản cập
## nhật (bản đang chạy + ghi chú bản mới nhất nếu đã hỏi được version.json) và Trận gần đây (trận mới nhất trong lịch sử
## tài khoản; chưa đăng nhập / chưa có trận thì ẩn). Chỉ báo bấm qua tín hiệu; APP đặt chữ.

signal play_pressed
signal update_pressed
signal recent_pressed

const BG_PATH: String = "res://assets/ui/home_bg.jpg"  ## D-413: ảnh nền người chơi gửi (art_inbox/concepts/menu)
const CARD_H: float = 120.0
const CARD_GAP: float = 28.0
const MARGIN: float = 48.0

## Dòng thẻ Bản cập nhật (APP đặt).
var version_text: String = ""
var notes_text: String = ""
## Trận gần đây: [dòng chính, dòng phụ]; rỗng = ẩn thẻ.
var recent: Array[String] = []
var _bg: Texture2D


func _ready() -> void:
	_bg = load(BG_PATH) as Texture2D
	mouse_filter = Control.MOUSE_FILTER_STOP


func play_rect() -> Rect2:
	return Rect2(Vector2(MARGIN + 20, size.y - CARD_H - MARGIN - 190), Vector2(440, 140))


func update_rect() -> Rect2:
	var w: float = minf(620.0, (size.x - MARGIN * 2 - CARD_GAP) * 0.5)
	return Rect2(Vector2(MARGIN, size.y - CARD_H - MARGIN), Vector2(w, CARD_H))


func recent_rect() -> Rect2:
	var u: Rect2 = update_rect()
	return Rect2(Vector2(u.end.x + CARD_GAP, u.position.y), u.size) if not recent.is_empty() else Rect2()


func press_at(at: Vector2) -> void:
	if play_rect().has_point(at):
		play_pressed.emit()
	elif update_rect().has_point(at):
		update_pressed.emit()
	elif recent_rect().has_point(at):
		recent_pressed.emit()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _draw() -> void:
	_cover(_bg)
	var shade: Color = Color(0.02, 0.03, 0.06, 0.55)  # tối dần xuống dưới: chữ thẻ dễ đọc, không có mép cứng
	draw_polygon([Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.45), size, Vector2(0, size.y)],
		[Color(shade, 0.0), Color(shade, 0.0), shade, shade])
	var at: Vector2 = Vector2(MARGIN + 20, 210)
	draw_string(UiStyle.serif(true), at + Vector2(4, 6), "CLASHBORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 112, Color(0, 0, 0, 0.6))
	draw_string(UiStyle.serif(true), at, "CLASHBORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 112, UiStyle.GOLD)
	draw_string(UiStyle.serif(), at + Vector2(10, 62), "— MOBA CHIẾN THUẬT 5V5 —", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiStyle.TEXT)
	UiStyle.button(self, play_rect(), &"gold", "CHƠI", "", 72)
	_card(update_rect(), "Bản cập nhật", version_text, notes_text)
	if not recent.is_empty():
		_card(recent_rect(), "Trận gần đây", recent[0], recent[1] if recent.size() > 1 else "")


## Ảnh phủ kín trang, giữ tỉ lệ (cắt phần thừa).
func _cover(tex: Texture2D) -> void:
	if tex == null:
		return
	var ts: Vector2 = tex.get_size()
	var k: float = maxf(size.x / ts.x, size.y / ts.y)
	var src: Vector2 = size / k
	draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), Rect2((ts - src) * 0.5, src))


func _card(r: Rect2, title: String, line: String, sub: String) -> void:
	UiStyle.soft_frame(self, r, 16, Color(0.04, 0.06, 0.1, 0.86))
	draw_style_box(UiStyle.box(Color(0, 0, 0, 0), Color(UiStyle.GOLD_DEEP, 0.9), 2, 16), r)
	var x: float = r.position.x + 28
	draw_string(UiStyle.serif(true), Vector2(x, r.position.y + 42), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 30, UiStyle.GOLD)
	draw_string(UiStyle.sans(true), Vector2(x, r.position.y + 76), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 22, UiStyle.TEXT)
	draw_string(UiStyle.sans(), Vector2(x, r.position.y + 104), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80, 19, UiStyle.DIM)
	draw_string(UiStyle.serif(true), Vector2(r.end.x - 42, r.get_center().y + 16), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, UiStyle.GOLD)
