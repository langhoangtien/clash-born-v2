class_name ItemButtons
extends Control
## Nút đồ chủ động (D-87): chỉ món có thể kích hoạt mới có nút, tối đa MAX nút tròn ở hàng dưới
## bên trái ô Q — chỗ phép bổ trợ (tốc biến, bộc phá) của Liên Quân. Chạm để dùng (tự nhắm như
## nút chiêu). Đồ bị động không có nút. Chỉ báo bằng tín hiệu.

const MAX: int = 3
const RADIUS: float = 46.0
const SPACING: float = 112.0
## Cùng bố cục với SkillButtons: tâm nút ĐÁNH cách góc dưới phải MAIN_OFFSET, ô Q ở góc Q_ANGLE.
const MAIN_OFFSET: Vector2 = Vector2(180, 180)
const Q_ANGLE: float = 178.0
const Q_DISTANCE: float = 350.0
const DROP: float = 28.0

## Chỉ số ô đồ (0..5) của món ở nút k.
signal item_tapped(index: int)

## APP đặt mỗi khung, mỗi nút một món chủ động theo thứ tự ô: [chỉ số ô, tên tắt, giây hồi, số lần dùng (-1 = không), dùng được].
var item_view: Array = []


func button_center(k: int) -> Vector2:
	var q: Vector2 = size - MAIN_OFFSET + Vector2.from_angle(deg_to_rad(Q_ANGLE)) * Q_DISTANCE
	return q + Vector2(-(k + 1) * SPACING, DROP)


func button_at(local: Vector2) -> int:
	for k: int in range(mini(item_view.size(), MAX)):
		if local.distance_to(button_center(k)) <= RADIUS:
			return k
	return -1


## Mép trái của cụm nút (để hàng buff/debuff không đè lên), INF nếu không có nút nào.
func left_edge() -> float:
	var n: int = mini(item_view.size(), MAX)
	return INF if n == 0 else button_center(n - 1).x - RADIUS


func _has_point(point: Vector2) -> bool:
	return button_at(point) >= 0


## PC: phím 4/5/6 = nút thứ k; trả về chỉ số ô đồ hoặc -1.
func slot_for_button(k: int) -> int:
	return item_view[k][0] if k >= 0 and k < mini(item_view.size(), MAX) else -1


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
	if at.is_finite():
		var k: int = button_at(at)
		if k >= 0 and item_view[k][4]:
			item_tapped.emit(item_view[k][0])
		accept_event()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for k: int in range(mini(item_view.size(), MAX)):
		var c: Vector2 = button_center(k)
		var view: Array = item_view[k]
		var ready: bool = view[4]
		draw_circle(c, RADIUS, Color(0.55, 0.4, 0.15, 0.75) if ready else Color(0.2, 0.2, 0.24, 0.6))
		draw_arc(c, RADIUS, 0, TAU, 32, Color(1, 0.85, 0.4, 0.9 if ready else 0.35), 3.0, true)
		_label(font, c - Vector2(0, 6), view[1], 20, Color.WHITE)
		if view[2] > 0.0:
			_label(font, c + Vector2(0, 18), "%d" % ceili(view[2]), 18, Color(1, 0.85, 0.3))
		if view[3] >= 0:
			_label(font, c + Vector2(RADIUS * 0.7, RADIUS * 0.7), str(view[3]), 16, Color(1, 1, 0.6))
		_label(font, c + Vector2(0, -RADIUS - 12), str(k + 4), 14, Color(1, 1, 1, 0.5))


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
