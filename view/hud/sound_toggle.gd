class_name SoundToggle
extends Control
## Nút chế độ tiếng cạnh nút Shop (D-114): Bật → Tắt nhạc → Tắt hết. Phím M.

signal pressed

const BUTTON: Rect2 = Rect2(424, 160, 150, 44)


func _has_point(point: Vector2) -> bool:
	return BUTTON.has_point(point)


func _gui_input(event: InputEvent) -> void:
	if Taps.press_position(event).is_finite():  # D-102
		pressed.emit()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_M:
		pressed.emit()


func _draw() -> void:
	UiStyle.button(self, BUTTON, &"blue", AudioView.MODE_NAMES[maxi(AudioView.mode, 0)] + " (M)", "", 18)  # D-130
