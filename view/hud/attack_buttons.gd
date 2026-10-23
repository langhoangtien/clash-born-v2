class_name AttackButtons
extends Control
## Cụm nút đánh góc dưới phải kiểu Liên Quân (CTL-02/03): nút ĐÁNH lớn, hai nút nhỏ đánh
## lính / đánh trụ. Ô chiêu nằm ở SkillButtons (cùng bố cục). Chỉ đọc chạm/chuột và báo nút nào đang
## giữ; không biết gì về trận đấu. Nhiều ngón cùng lúc được (mỗi ngón một nút).

## Hằng số giao diện (px màn hình, tính từ góc dưới phải của khung).
const MAIN_OFFSET: Vector2 = Vector2(180, 180)
const MAIN_RADIUS: float = 105.0
const SMALL_RADIUS: float = 56.0
const SMALL_DISTANCE: float = 195.0
## Góc (độ) quanh nút ĐÁNH: đánh lính, đánh trụ.
const SMALL_ANGLES: Array[float] = [200.0, 250.0]
const LABELS: Array[String] = ["ĐÁNH", "Lính", "Trụ"]
const KEYS: Array[String] = ["J", "K", "L"]
## Icon nút (ArtLibrary); thiếu ảnh thì vẽ chữ LABELS.
const ART_IDS: Array[StringName] = [&"ui_attack", &"ui_attack_creep", &"ui_attack_tower"]
## Cạnh ảnh hình trắng = bán kính nút × hệ số (ảnh đã cắt sát hình, D-131).
const GLYPH_SCALE: float = 1.05
## Con trỏ chuột dùng số này (chạm dùng chỉ số ngón tay ≥ 0).
const MOUSE_POINTER: int = -1

var _pointers: Dictionary[int, int] = {}


func button_center(mode: int) -> Vector2:
	var main: Vector2 = size - MAIN_OFFSET
	if mode == Rules.AttackMode.ALL:
		return main
	return main + Vector2.from_angle(deg_to_rad(SMALL_ANGLES[mode - 1])) * SMALL_DISTANCE


func button_radius(mode: int) -> float:
	return MAIN_RADIUS if mode == Rules.AttackMode.ALL else SMALL_RADIUS


## Nút (Rules.AttackMode) dưới điểm `local`, -1 nếu không trúng nút nào.
func button_at(local: Vector2) -> int:
	for mode: int in range(LABELS.size()):
		if local.distance_to(button_center(mode)) <= button_radius(mode):
			return mode
	return -1


func is_held(mode: int) -> bool:
	return _pointers.values().has(mode)


func press_at(pointer: int, local: Vector2) -> void:
	var mode: int = button_at(local)
	if mode >= 0:
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
	for mode: int in range(LABELS.size()):
		var c: Vector2 = button_center(mode)
		var r: float = button_radius(mode)
		var held: bool = is_held(mode)
		var big: int = 34 if mode == Rules.AttackMode.ALL else 22
		var tex: Texture2D = ArtLibrary.texture(ART_IDS[mode])
		if tex != null:  # D-131: nền + viền vẽ bằng code (mịn, đúng tâm); ảnh chỉ là hình trắng
			draw_circle(c, r, Color(UiStyle.CARD, 0.88 if held else 0.78), true, -1.0, true)
			draw_arc(c, r - 2.0, 0, TAU, 96, Color(UiStyle.BLUE_EDGE, 1.0 if held else 0.85), 4.0 if held else 3.0, true)
			var side: float = r * GLYPH_SCALE
			draw_texture_rect(tex, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color.WHITE if held else Color(0.9, 0.9, 0.9, 0.95))
			_label(font, c + Vector2(r * 0.7, r * 0.7), KEYS[mode], int(big * 0.55), Color(1, 1, 1, 0.6))
			continue
		draw_circle(c, r, Color(0.85, 0.35, 0.25, 0.75 if held else 0.5))
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.9 if held else 0.55), 4.0, true)
		_label(font, c - Vector2(0, big * 0.35), LABELS[mode], big, Color.WHITE)
		_label(font, c + Vector2(0, big * 0.75), KEYS[mode], int(big * 0.7), Color(1, 1, 1, 0.6))


func _label(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
