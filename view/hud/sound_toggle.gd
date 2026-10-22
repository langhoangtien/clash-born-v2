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
	draw_rect(BUTTON, Color(0.12, 0.2, 0.32, 0.85))
	draw_rect(BUTTON, Color(0.6, 0.8, 1.0, 0.8), false, 2.0)
	var text: String = AudioView.MODE_NAMES[maxi(AudioView.mode, 0)] + " (M)"
	draw_string(ThemeDB.fallback_font, BUTTON.position + Vector2(12, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
