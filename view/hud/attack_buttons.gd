class_name AttackButtons
extends Control
## Cụm nút góc dưới phải kiểu Liên Quân (CTL-02/03): nút ĐÁNH lớn, hai nút nhỏ đánh lính /
## đánh trụ, ba ô chiêu Q/W/R (bấm là tung nhanh, kéo nhắm làm ở M3.8; phím 1/2/3). Chỉ đọc chạm/chuột và báo nút nào đang
## giữ; không biết gì về trận đấu. Nhiều ngón cùng lúc được (mỗi ngón một nút).

## Hằng số giao diện (px màn hình, tính từ góc dưới phải của khung).
const MAIN_OFFSET: Vector2 = Vector2(180, 180)
const MAIN_RADIUS: float = 105.0
const SMALL_RADIUS: float = 56.0
const SMALL_DISTANCE: float = 195.0
const SKILL_RADIUS: float = 62.0
const SKILL_DISTANCE: float = 350.0
## Góc (độ) quanh nút ĐÁNH: đánh lính, đánh trụ; ba ô chiêu.
const SMALL_ANGLES: Array[float] = [200.0, 250.0]
const SKILL_ANGLES: Array[float] = [178.0, 213.0, 248.0]
const LABELS: Array[String] = ["ĐÁNH", "Lính", "Trụ"]
const KEYS: Array[String] = ["J", "K", "L"]
## Con trỏ chuột dùng số này (chạm dùng chỉ số ngón tay ≥ 0).
const MOUSE_POINTER: int = -1

## Mã nút chiêu trả về từ button_at: SKILL_BASE + 0/1/2 (Q/W/R).
const SKILL_BASE: int = 10

signal skill_pressed(index: int)

var _pointers: Dictionary[int, int] = {}
## Trạng thái ô chiêu để vẽ (APP đặt mỗi khung): [cấp, giây hồi chiêu còn lại, dùng được].
var skill_view: Array = [[0, 0.0, false], [0, 0.0, false], [0, 0.0, false]]


func button_center(mode: int) -> Vector2:
	var main: Vector2 = size - MAIN_OFFSET
	if mode == Rules.AttackMode.ALL:
		return main
	return main + Vector2.from_angle(deg_to_rad(SMALL_ANGLES[mode - 1])) * SMALL_DISTANCE


func button_radius(mode: int) -> float:
	return MAIN_RADIUS if mode == Rules.AttackMode.ALL else SMALL_RADIUS


func skill_center(index: int) -> Vector2:
	return size - MAIN_OFFSET + Vector2.from_angle(deg_to_rad(SKILL_ANGLES[index])) * SKILL_DISTANCE


## Nút (Rules.AttackMode) dưới điểm `local`, -1 nếu không trúng nút nào.
func button_at(local: Vector2) -> int:
	for mode: int in range(LABELS.size()):
		if local.distance_to(button_center(mode)) <= button_radius(mode):
			return mode
	for i: int in range(SKILL_ANGLES.size()):
		if local.distance_to(skill_center(i)) <= SKILL_RADIUS:
			return SKILL_BASE + i
	return -1


func is_held(mode: int) -> bool:
	return _pointers.values().has(mode)


func press_at(pointer: int, local: Vector2) -> void:
	var mode: int = button_at(local)
	if mode >= SKILL_BASE:
		skill_pressed.emit(mode - SKILL_BASE)
	elif mode >= 0:
		_pointers[pointer] = mode
		queue_redraw()


func release(pointer: int) -> void:
	if _pointers.erase(pointer):
		queue_redraw()


## Chỉ nhận sự kiện trên nút; chỗ khác của khung để rơi xuống map.
func _has_point(point: Vector2) -> bool:
	return button_at(point) >= 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			press_at(touch.index, touch.position)
		else:
			release(touch.index)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click: InputEventMouseButton = event
		if click.pressed:
			press_at(MOUSE_POINTER, click.position)
		else:
			release(MOUSE_POINTER)
		accept_event()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i: int in range(SKILL_ANGLES.size()):
		var c: Vector2 = skill_center(i)
		var view: Array = skill_view[i]
		var learned: bool = view[0] > 0
		var ready: bool = learned and view[2]
		draw_circle(c, SKILL_RADIUS, Color(0.2, 0.35, 0.6, 0.7) if ready else Color(0.15, 0.15, 0.2, 0.45))
		draw_arc(c, SKILL_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.7 if ready else 0.2), 3.0, true)
		if view[1] > 0.0:
			_label(font, c - Vector2(0, 10), "%d" % ceili(view[1]), 30, Color(1, 0.85, 0.3))
		else:
			_label(font, c - Vector2(0, 10), ["Q", "W", "R"][i], 26, Color(1, 1, 1, 0.9 if learned else 0.3))
		_label(font, c + Vector2(0, 22), str(i + 1), 16, Color(1, 1, 1, 0.5))
		for r: int in range(view[0]):
			draw_circle(c + Vector2(-16 + r * 8, SKILL_RADIUS - 10), 3.0, Color(1, 0.85, 0.3))
	for mode: int in range(LABELS.size()):
		var c: Vector2 = button_center(mode)
		var r: float = button_radius(mode)
		var held: bool = is_held(mode)
		draw_circle(c, r, Color(0.85, 0.35, 0.25, 0.75 if held else 0.5))
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.9 if held else 0.55), 4.0, true)
		var big: int = 34 if mode == Rules.AttackMode.ALL else 22
		_label(font, c - Vector2(0, big * 0.35), LABELS[mode], big, Color.WHITE)
		_label(font, c + Vector2(0, big * 0.75), KEYS[mode], int(big * 0.7), Color(1, 1, 1, 0.6))


func _label(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
