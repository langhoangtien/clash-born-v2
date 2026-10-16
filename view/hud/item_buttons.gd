class_name ItemButtons
extends Control
## Hàng 6 ô đồ phía trên cụm nút chiêu (M6.5a, ITM-01). Ô có món chủ động: chạm để dùng
## (tự nhắm như chạm nút chiêu). Hiện tên tắt, giây hồi, số lần dùng. Chỉ báo bằng tín hiệu.

const SIDE: float = 64.0
const GAP: float = 8.0
## Góc trên trái của hàng, tính từ góc dưới phải khung.
const OFFSET: Vector2 = Vector2(6 * (64.0 + 8.0) + 24.0, 660.0)

signal item_tapped(index: int)

## APP đặt mỗi khung, mỗi ô: [] nếu trống, hoặc [tên tắt, giây hồi, số lần dùng (-1 = không), chủ động, dùng được].
var item_view: Array = [[], [], [], [], [], []]


func slot_rect(i: int) -> Rect2:
	var origin: Vector2 = size - OFFSET
	return Rect2(origin + Vector2(i * (SIDE + GAP), 0), Vector2(SIDE, SIDE))


func slot_at(local: Vector2) -> int:
	for i: int in range(6):
		if slot_rect(i).has_point(local):
			return i
	return -1


func _has_point(point: Vector2) -> bool:
	return slot_at(point) >= 0


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		var i: int = slot_at((event as InputEventFromWindow).position if event is InputEventMouseButton else (event as InputEventScreenTouch).position)
		if i >= 0 and item_view[i].size() > 0 and item_view[i][3]:
			item_tapped.emit(i)
		accept_event()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i: int in range(6):
		var r: Rect2 = slot_rect(i)
		var view: Array = item_view[i]
		draw_rect(r, Color(0.08, 0.1, 0.14, 0.7))
		draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)
		if view.is_empty():
			_label(font, r.get_center(), str(i + 4), 16, Color(1, 1, 1, 0.25))
			continue
		var active: bool = view[3]
		var ready: bool = view[4]
		draw_rect(r.grow(-3), Color(0.25, 0.4, 0.6, 0.8) if active and ready else Color(0.22, 0.24, 0.3, 0.8))
		_label(font, r.get_center() - Vector2(0, 6), view[0], 18, Color.WHITE)
		if view[1] > 0.0:
			_label(font, r.get_center() + Vector2(0, 16), "%d" % ceili(view[1]), 18, Color(1, 0.85, 0.3))
		if view[2] >= 0:
			_label(font, r.position + Vector2(SIDE - 10, SIDE - 10), str(view[2]), 14, Color(1, 1, 0.6))
		_label(font, r.position + Vector2(9, 10), str(i + 4), 12, Color(1, 1, 1, 0.5))


func _label(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Tên tắt từ tên hiển thị: chữ đầu của tối đa hai từ (vd "Gậy Hồn Ma" → "GH").
static func short_name(name: String) -> String:
	var parts: PackedStringArray = name.split(" ", false)
	var out: String = ""
	for p: String in parts.slice(0, 2):
		out += p.substr(0, 1).to_upper()
	return out
