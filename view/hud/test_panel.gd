class_name TestPanel
extends Control
## Nút Test (D-138, kiểu chế độ luyện tập Liên Quân): mở bảng cộng vàng / lên cấp cho mình và cho
## bot. Chỉ báo nút nào được bấm; APP gửi lệnh CHEAT_* (CMD-06). Phím T mở / đóng.

## who: 0 = mình, 1 = bot; what: &"gold" (+10.000), &"level" (+1 cấp), &"max" (cấp tối đa).
signal action(who: int, what: StringName)

const BUTTON: Rect2 = Rect2(424, 214, 150, 44)
const PANEL: Rect2 = Rect2(424, 266, 430, 196)
const ROWS: Array[String] = ["Mình", "Bot"]
const ACTIONS: Array[StringName] = [&"gold", &"level", &"max"]
const LABELS: Array[String] = ["+10k vàng", "+1 cấp", "Cấp 20"]

var open: bool = false
## Có hero bot không (không thì ẩn hàng bot).
var has_bot: bool = true


func cell_rect(who: int, i: int) -> Rect2:
	return Rect2(PANEL.position + Vector2(96 + i * 110, 20 + who * 86), Vector2(100, 70))


func _has_point(point: Vector2) -> bool:
	return BUTTON.has_point(point) or (open and PANEL.has_point(point))


func press_at(at: Vector2) -> void:
	if BUTTON.has_point(at):
		open = not open
	elif open:
		for who: int in range(2 if has_bot else 1):
			for i: int in range(ACTIONS.size()):
				if cell_rect(who, i).has_point(at):
					action.emit(who, ACTIONS[i])
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_T:
		open = not open
		queue_redraw()


func _draw() -> void:
	UiStyle.button(self, BUTTON, &"gold" if open else &"ghost", "Test (T)", "", 18)
	if not open:
		return
	UiStyle.panel(self, PANEL, 12)
	for who: int in range(2 if has_bot else 1):
		var y: float = cell_rect(who, 0).get_center().y
		draw_string(UiStyle.serif(true), Vector2(PANEL.position.x + 18, y + 9), ROWS[who], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiStyle.TEXT)
		for i: int in range(ACTIONS.size()):
			UiStyle.button(self, cell_rect(who, i), &"gold" if i == 0 else &"blue", LABELS[i], "", 18)
