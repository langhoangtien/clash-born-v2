class_name ItemButtons
extends Control
## Nút đồ chủ động (D-87, D-89): chỉ món có thể kích hoạt mới có nút, tối đa 6 nút tròn ở hàng dưới
## bên trái ô Q — chỗ phép bổ trợ (tốc biến, bộc phá) của Liên Quân. Chạm để dùng (tự nhắm như
## nút chiêu). Đồ bị động không có nút. Chỉ báo bằng tín hiệu.

const MAX: int = 6
## Chỗ luôn để dành cho nút đồ (hàng buff/debuff nằm trên chỗ này kể cả khi chưa có đồ).
const RESERVED: int = 3
## Nhỏ hơn nút chiêu (SKILL_RADIUS 62) như phép bổ trợ Liên Quân.
const RADIUS: float = 50.0
const SPACING: float = 128.0
## Khoảng từ tâm ô Q tới tâm nút đồ đầu tiên.
const FIRST_GAP: float = 176.0
## Cùng bố cục với SkillButtons: tâm nút ĐÁNH cách góc dưới phải MAIN_OFFSET, ô Q ở góc Q_ANGLE.
const MAIN_OFFSET: Vector2 = Vector2(180, 180)
const Q_ANGLE: float = 178.0
const Q_DISTANCE: float = 350.0
const DROP: float = 6.0

const AIM_RADIUS: float = 150.0
const DEAD_ZONE: float = 24.0
const MOUSE_POINTER: int = -1

## Chỉ số ô đồ (0..5) của món ở nút k: chạm (tự nhắm như nút chiêu).
signal item_tapped(index: int)
## M6.8b: kéo nút để nhắm (aim dài 0..1 của tầm), thả ra ngoài nút thì dùng.
signal item_aimed(index: int, aim: Vector2)
signal aim_changed(index: int, aim: Vector2, active: bool)
## D-104: nút Về thành (bên trái cụm nút đồ).
signal recall_pressed

const RECALL_RADIUS: float = 40.0
## APP đặt: phần thời gian kênh về thành đã qua 0..1, < 0 = không kênh.
var recall_progress: float = -1.0

## APP đặt mỗi khung, mỗi nút một món chủ động theo thứ tự ô: [chỉ số ô, tên tắt, giây hồi, số lần dùng (-1 = không), dùng được].
var item_view: Array = []
var _press: int = -1
var _pointer: int = -100
var _offset: Vector2 = Vector2.ZERO
var _aiming: bool = false


func button_center(k: int) -> Vector2:
	var q: Vector2 = size - MAIN_OFFSET + Vector2.from_angle(deg_to_rad(Q_ANGLE)) * Q_DISTANCE
	return q + Vector2(-FIRST_GAP - k * SPACING, DROP)


func recall_center() -> Vector2:
	return Vector2(zone_rect().position.x - RECALL_RADIUS - 24.0, button_center(0).y)


func button_at(local: Vector2) -> int:
	for k: int in range(mini(item_view.size(), MAX)):
		if local.distance_to(button_center(k)) <= RADIUS:
			return k
	return -1


## Mép trái của cụm nút (để hàng buff/debuff không đè lên), INF nếu không có nút nào.
func left_edge() -> float:
	var n: int = mini(item_view.size(), MAX)
	return INF if n == 0 else button_center(n - 1).x - RADIUS


## Khung chỗ đặt nút đồ (ít nhất RESERVED nút, kể cả khi chưa có đồ) — hàng buff/debuff nằm ngay trên.
func zone_rect() -> Rect2:
	var n: int = clampi(item_view.size(), RESERVED, MAX)
	var left: Vector2 = button_center(n - 1) - Vector2(RADIUS, RADIUS)
	var right: Vector2 = button_center(0) + Vector2(RADIUS, RADIUS)
	return Rect2(left, right - left)


func _has_point(point: Vector2) -> bool:
	return _press >= 0 or button_at(point) >= 0 or point.distance_to(recall_center()) <= RECALL_RADIUS


## PC: phím 4..9 = nút thứ k; trả về chỉ số ô đồ hoặc -1.
func slot_for_button(k: int) -> int:
	return item_view[k][0] if k >= 0 and k < mini(item_view.size(), MAX) else -1


func is_aiming() -> bool:
	return _aiming


func aim() -> Vector2:
	return _offset.limit_length(AIM_RADIUS) / AIM_RADIUS


func press_at(pointer: int, local: Vector2) -> void:
	if local.distance_to(recall_center()) <= RECALL_RADIUS:
		if pointer == MOUSE_POINTER and Taps._mouse_is_touch():
			return  # D-102: click PC đã đến dạng chạm giả
		recall_pressed.emit()
		return
	var k: int = button_at(local)
	if k >= 0 and _press < 0 and item_view[k][4]:
		_press = k
		_pointer = pointer
		_offset = Vector2.ZERO
		_aiming = false


func drag_to(pointer: int, local: Vector2) -> void:
	if pointer != _pointer or _press < 0:
		return
	_offset = local - button_center(_press)
	if not _aiming and _offset.length() > DEAD_ZONE:
		_aiming = true
	if _aiming:
		aim_changed.emit(item_view[_press][0], aim(), true)
		queue_redraw()


## Thả: chưa kéo → chạm; đã kéo → thả trong nút là hủy, ngoài nút là dùng theo hướng kéo.
func release_at(pointer: int, local: Vector2) -> void:
	if pointer != _pointer or _press < 0:
		return
	var slot: int = item_view[_press][0] if _press < item_view.size() else -1
	if _aiming:
		aim_changed.emit(slot, aim(), false)
		if slot >= 0 and local.distance_to(button_center(_press)) > RADIUS:
			item_aimed.emit(slot, aim())
	elif slot >= 0:
		item_tapped.emit(slot)
	_press = -1
	_pointer = -100
	_aiming = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		press_at(t.index, t.position) if t.pressed else release_at(t.index, t.position)
		accept_event()
	elif event is InputEventScreenDrag:
		drag_to((event as InputEventScreenDrag).index, (event as InputEventScreenDrag).position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m: InputEventMouseButton = event
		press_at(MOUSE_POINTER, m.position) if m.pressed else release_at(MOUSE_POINTER, m.position)
		accept_event()
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_to(MOUSE_POINTER, (event as InputEventMouseMotion).position)
		accept_event()


func _draw() -> void:
	var rc: Vector2 = recall_center()
	draw_circle(rc, RECALL_RADIUS, Color(0.15, 0.3, 0.55, 0.75))
	draw_arc(rc, RECALL_RADIUS, 0, TAU, 32, Color(0.6, 0.85, 1.0, 0.9), 3.0, true)
	if recall_progress >= 0.0:
		draw_arc(rc, RECALL_RADIUS - 6, -PI * 0.5, -PI * 0.5 + TAU * recall_progress, 32, Color(1, 1, 1, 0.95), 6.0, true)
	_label(ThemeDB.fallback_font, rc, "Về", 20, Color.WHITE)
	_label(ThemeDB.fallback_font, rc + Vector2(-RECALL_RADIUS * 0.7, -RECALL_RADIUS * 0.7), "H", 13, Color(1, 1, 1, 0.45))
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
		_label(font, c + Vector2(-RADIUS * 0.75, -RADIUS * 0.75), str(k + 4), 13, Color(1, 1, 1, 0.45))
	if _aiming and _press >= 0:
		var c: Vector2 = button_center(_press)
		draw_circle(c, AIM_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(c, AIM_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0, true)
		draw_circle(c + _offset.limit_length(AIM_RADIUS), 22.0, Color(1, 1, 1, 0.6))


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
