class_name TouchJoystick
extends Control
## Joystick ảo (CTL-01): giữ và kéo trong vùng góc dưới trái. Chỉ đọc chạm và báo hướng;
## không biết gì về trận đấu.

## Hằng số giao diện: bán kính đế (px màn hình) và vùng chết (tỉ lệ bán kính).
@export var radius: float = 140.0
const DEAD_ZONE: float = 0.15

var direction: Vector2 = Vector2.ZERO
var active: bool = false

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


## Hướng (độ dài 0 hoặc 1) từ độ lệch của ngón tay so với tâm đế.
func direction_for(offset: Vector2) -> Vector2:
	if offset.length() < radius * DEAD_ZONE:
		return Vector2.ZERO
	return offset.normalized()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_origin = touch.position
			_set_offset(Vector2.ZERO)
			active = true
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			active = false
			_set_offset(Vector2.ZERO)
		accept_event()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		_set_offset((event as InputEventScreenDrag).position - _origin)
		accept_event()


func _set_offset(offset: Vector2) -> void:
	_knob = offset.limit_length(radius)
	direction = direction_for(offset)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	draw_circle(_origin, radius, Color(1, 1, 1, 0.12))
	draw_arc(_origin, radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_origin + _knob, radius * 0.38, Color(1, 1, 1, 0.45))
