class_name Taps
extends RefCounted
## Một lần chạm = một sự kiện. Dự án bật `emulate_touch_from_mouse` nên trên PC một cú click
## đến hai lần (InputEventMouseButton + InputEventScreenTouch giả); nút bật/tắt chỉ được xử lý
## một lần (D-102).


## Vị trí nhấn nếu `event` là một lần chạm / click trái mới; INF nếu không.
static func press_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		return (event as InputEventScreenTouch).position
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not _mouse_is_touch():
		return (event as InputEventMouseButton).position
	return Vector2.INF


static func _mouse_is_touch() -> bool:
	return ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)
