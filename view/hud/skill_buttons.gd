class_name SkillButtons
extends Control
## Ô chiêu Q/W/R kiểu Liên Quân (M3.8), cùng khung góc dưới phải với AttackButtons:
## - chạm rồi thả tại chỗ → tung nhanh (tự nhắm); kéo ra khỏi vùng chết → nhắm, thả → tung
##   theo hướng/khoảng kéo; thả vào ô "Hủy" → không tung;
## - nút "+" trên mỗi ô khi nâng được, nút "+TT" đổi điểm lấy thuộc tính (ABL-04).
## Chỉ báo bằng tín hiệu; không biết gì về trận đấu.

const MAIN_OFFSET: Vector2 = Vector2(180, 180)
const SKILL_RADIUS: float = 62.0
const SKILL_DISTANCE: float = 350.0
const SKILL_ANGLES: Array[float] = [178.0, 213.0, 248.0]
## Kéo bao xa (px) thì nhắm hết tầm; dưới vùng chết coi như chạm.
const AIM_RADIUS: float = 160.0
const DEAD_ZONE: float = 20.0
const PLUS_OFFSET: Vector2 = Vector2(-44, -50)
const PLUS_RADIUS: float = 22.0
const ATTR_OFFSET: Vector2 = Vector2(-50, -150)
const CANCEL_RADIUS: float = 52.0
## Mã ô "+" thuộc tính trong level_pressed.
const ATTRIBUTES: int = 3
const MOUSE_POINTER: int = -1

signal skill_tapped(index: int)
signal skill_aimed(index: int, aim: Vector2)
## Đang nhắm (aim: −1..1 theo mỗi trục, độ dài ≤ 1) hoặc thôi nhắm (active = false).
signal aim_changed(index: int, aim: Vector2, active: bool)
signal level_pressed(index: int)

## APP đặt mỗi khung: [cấp, giây hồi chiêu, dùng được, nâng được] cho Q/W/R.
var skill_view: Array = [[0, 0.0, false, false], [0, 0.0, false, false], [0, 0.0, false, false]]
## art_id của Q/W/R (APP đặt); có hình trong ArtLibrary thì vẽ hình thay chữ.
var skill_art: Array[StringName] = [&"", &"", &""]
var attributes_can_level: bool = false

var _aim_pointer: int = -100
var _aim_index: int = -1
var _aim_offset: Vector2 = Vector2.ZERO
var _aiming: bool = false


func skill_center(index: int) -> Vector2:
	return size - MAIN_OFFSET + Vector2.from_angle(deg_to_rad(SKILL_ANGLES[index])) * SKILL_DISTANCE


func plus_center(index: int) -> Vector2:
	return skill_center(0) + ATTR_OFFSET if index == ATTRIBUTES else skill_center(index) + PLUS_OFFSET


func cancel_center() -> Vector2:
	return Vector2(size.x - MAIN_OFFSET.x, CANCEL_RADIUS + 10.0)


func skill_at(local: Vector2) -> int:
	for i: int in range(SKILL_ANGLES.size()):
		if local.distance_to(skill_center(i)) <= SKILL_RADIUS:
			return i
	return -1


func plus_at(local: Vector2) -> int:
	for i: int in range(4):
		var shown: bool = attributes_can_level if i == ATTRIBUTES else skill_view[i][3]
		if shown and local.distance_to(plus_center(i)) <= PLUS_RADIUS:
			return i
	return -1


func is_aiming() -> bool:
	return _aiming


## Hướng nhắm hiện tại, độ dài 0..1 (1 = hết tầm).
func aim() -> Vector2:
	return _aim_offset.limit_length(AIM_RADIUS) / AIM_RADIUS


func press_at(pointer: int, local: Vector2) -> void:
	var plus: int = plus_at(local)
	if plus >= 0:
		level_pressed.emit(plus)
		return
	var i: int = skill_at(local)
	if i >= 0 and _aim_index < 0:
		_aim_pointer = pointer
		_aim_index = i
		_aim_offset = Vector2.ZERO
		_aiming = false


func drag_to(pointer: int, local: Vector2) -> void:
	if pointer != _aim_pointer or _aim_index < 0:
		return
	_aim_offset = local - skill_center(_aim_index)
	if not _aiming and _aim_offset.length() > DEAD_ZONE:
		_aiming = true
	if _aiming:
		aim_changed.emit(_aim_index, aim(), true)
		queue_redraw()


func release_at(pointer: int, local: Vector2) -> void:
	if pointer != _aim_pointer or _aim_index < 0:
		return
	var i: int = _aim_index
	if _aiming:
		aim_changed.emit(i, aim(), false)
		if local.distance_to(cancel_center()) > CANCEL_RADIUS:
			skill_aimed.emit(i, aim())
	else:
		skill_tapped.emit(i)
	_aim_index = -1
	_aim_pointer = -100
	_aiming = false
	queue_redraw()


## Nhận sự kiện trên nút; khi đang nhắm thì nhận cả khung (để kéo / thả vào ô Hủy).
func _has_point(point: Vector2) -> bool:
	return _aim_index >= 0 or skill_at(point) >= 0 or plus_at(point) >= 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			press_at(t.index, t.position)
		else:
			release_at(t.index, t.position)
		accept_event()
	elif event is InputEventScreenDrag:
		drag_to((event as InputEventScreenDrag).index, (event as InputEventScreenDrag).position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m: InputEventMouseButton = event
		if m.pressed:
			press_at(MOUSE_POINTER, m.position)
		else:
			release_at(MOUSE_POINTER, m.position)
		accept_event()
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		drag_to(MOUSE_POINTER, (event as InputEventMouseMotion).position)
		accept_event()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i: int in range(SKILL_ANGLES.size()):
		_draw_skill(font, i)
	if attributes_can_level:
		_draw_plus(font, plus_center(ATTRIBUTES), "+TT")
	if _aiming:
		var c: Vector2 = skill_center(_aim_index)
		draw_circle(c, AIM_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(c, AIM_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0, true)
		draw_circle(c + _aim_offset.limit_length(AIM_RADIUS), 26.0, Color(1, 1, 1, 0.6))
		draw_circle(cancel_center(), CANCEL_RADIUS, Color(0.8, 0.2, 0.2, 0.55))
		_label(font, cancel_center(), "Hủy", 24, Color.WHITE)


func _draw_skill(font: Font, i: int) -> void:
	var c: Vector2 = skill_center(i)
	var view: Array = skill_view[i]
	var learned: bool = view[0] > 0
	var ready: bool = learned and view[2]
	draw_circle(c, SKILL_RADIUS, Color(0.2, 0.35, 0.6, 0.7) if ready else Color(0.15, 0.15, 0.2, 0.45))
	var tex: Texture2D = ArtLibrary.texture(skill_art[i])
	if tex != null:
		var side: float = SKILL_RADIUS * 2.0 - 8.0
		draw_texture_rect(tex, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color.WHITE if ready else Color(0.45, 0.45, 0.45))
	draw_arc(c, SKILL_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.7 if ready else 0.2), 3.0, true)
	if view[1] > 0.0:
		_label(font, c - Vector2(0, 10), "%d" % ceili(view[1]), 30, Color(1, 0.85, 0.3))
	else:
		if tex == null:
			_label(font, c - Vector2(0, 10), ["Q", "W", "R"][i], 26, Color(1, 1, 1, 0.9 if learned else 0.3))
	_label(font, c + Vector2(0, 22), str(i + 1), 16, Color(1, 1, 1, 0.5))
	for r: int in range(view[0]):
		draw_circle(c + Vector2(-16 + r * 8, SKILL_RADIUS - 10), 3.0, Color(1, 0.85, 0.3))
	if view[3]:
		_draw_plus(font, plus_center(i), "+")


func _draw_plus(font: Font, c: Vector2, text: String) -> void:
	draw_circle(c, PLUS_RADIUS, Color(0.95, 0.75, 0.2, 0.9))
	draw_arc(c, PLUS_RADIUS, 0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
	_label(font, c, text, 18 if text.length() > 1 else 26, Color(0.15, 0.1, 0.0))


func _label(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
