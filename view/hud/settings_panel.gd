class_name SettingsPanel
extends Control
## Bảng Cài đặt (D-183, kiểu Liên Quân). Trong trận: nút bánh răng góc trên phải mở bảng — âm thanh, đồ họa,
## hiện FPS, công cụ thử (bảng Test, bảng Chẩn đoán), thoát trận; không dừng trận. Ở menu: APP mở bảng bằng
## nút Cài đặt của màn chọn tướng — chỉ âm thanh, đồ họa, FPS. Chỉ báo hàng được bấm qua `action`; APP áp và
## đặt chữ giá trị (`values`).

signal action(what: StringName)

const GEAR_SIZE: float = 60.0  ## D-225: nhỏ hơn (76 → 60)
const ROW: Vector2 = Vector2(600, 72)
const ROW_GAP: float = 14.0
## D-267: chiều cao dòng phiên bản dưới hàng cuối.
const VERSION_H: float = 44.0
const LABELS: Dictionary[StringName, String] = {
	&"sound": "Âm thanh", &"graphics": "Đồ họa", &"fps": "Hiện FPS", &"test": "Bảng Test (thử)",
	&"diag": "Chẩn đoán FPS (thử)", &"quit": "Thoát trận", &"perf_log": "Ghi log hiệu năng",
	&"perf_export": "Xuất log hiệu năng", &"bench": "Đo hiệu năng tự động",
}

var open: bool = false
## true: trong trận (có bánh răng, công cụ thử, thoát trận).
var in_match: bool = true
## MATCH-06 (D-332): trận thử — mới có công cụ thử (Test, Chẩn đoán, xuất log).
var practice: bool = false
## Chữ giá trị bên phải mỗi hàng (APP đặt), vd {&"sound": "Bật"}.
var values: Dictionary[StringName, String] = {}
## D-267: tên bản đang chạy (APP đặt, vd "0.1.449"); rỗng = chạy từ editor.
var version_text: String = ""


func rows() -> Array[StringName]:
	var out: Array[StringName] = [&"sound", &"graphics", &"fps"]
	if in_match:
		if practice:  # MATCH-06: công cụ thử chỉ trong trận thử
			out.append_array([&"test", &"diag", &"perf_export"] as Array[StringName])
		out.append(&"quit")
	else:
		out.append_array([&"perf_log", &"bench"] as Array[StringName])  # D-268 / D-272: chọn trước khi vào trận
	return out


func gear_rect() -> Rect2:
	return Rect2(size.x - GEAR_SIZE - 16, 14, GEAR_SIZE, GEAR_SIZE) if in_match else Rect2()


func panel_rect() -> Rect2:
	var h: float = 110 + rows().size() * (ROW.y + ROW_GAP) + 20 + VERSION_H
	return Rect2((size - Vector2(ROW.x + 60, h)) * 0.5, Vector2(ROW.x + 60, h))


func row_rect(i: int) -> Rect2:
	return Rect2(panel_rect().position + Vector2(30, 100 + i * (ROW.y + ROW_GAP)), ROW)


func version_line() -> String:
	return "Phiên bản " + version_text if version_text != "" else "Phiên bản: chạy từ editor"


func close_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.end.x - 76, p.position.y + 16, 60, 60)


func _has_point(point: Vector2) -> bool:
	return gear_rect().has_point(point) or open


func press_at(at: Vector2) -> void:
	if gear_rect().has_point(at):
		open = not open
	elif open:
		if close_rect().has_point(at) or not panel_rect().has_point(at):
			open = false
		else:
			for i: int in rows().size():
				if row_rect(i).has_point(at):
					action.emit(rows()[i])
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _draw() -> void:
	if in_match:
		_gear(gear_rect())
	if not open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var p: Rect2 = panel_rect()
	UiStyle.panel(self, p, 16)
	draw_string(UiStyle.serif(true), p.position + Vector2(32, 66), "Cài đặt", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiStyle.GOLD)
	UiStyle.glyph(self, &"close", close_rect().get_center(), 20, UiStyle.TEXT)
	var list: Array[StringName] = rows()
	for i: int in list.size():
		var r: Rect2 = row_rect(i)
		var key: StringName = list[i]
		draw_string(UiStyle.sans(true), r.position + Vector2(8, 46), LABELS[key], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiStyle.TEXT)
		var b: Rect2 = Rect2(r.end.x - 240, r.position.y + 6, 240, r.size.y - 12)
		UiStyle.button(self, b, &"gold" if key == &"quit" else &"blue", values.get(key, "Mở" if key != &"quit" else "Thoát"), "", 24)
	var at: Vector2 = Vector2(p.position.x + 38, p.end.y - 26)  # D-267
	draw_string(UiStyle.sans(false), at, version_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UiStyle.TEXT, 0.6))


## Nút bánh răng: vành răng + lỗ giữa.
func _gear(r: Rect2) -> void:
	UiStyle.soft_frame(self, r, 14, Color(0.05, 0.07, 0.11, 0.88))  # D-222
	var c: Vector2 = r.get_center()
	var s: float = r.size.x * 0.3
	for k: int in 8:
		var d: Vector2 = Vector2.from_angle(TAU * k / 8.0)
		draw_line(c + d * s * 0.7, c + d * s * 1.15, UiStyle.TEXT, s * 0.32)
	draw_circle(c, s * 0.8, UiStyle.TEXT)
	draw_circle(c, s * 0.35, Color(0.05, 0.07, 0.11))
