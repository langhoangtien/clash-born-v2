class_name DiagPanel
extends Control
## D-179: bảng chẩn đoán FPS cho bản thử trên máy tính bảng — bật / tắt từng phần vẽ để đo phần nào
## tốn khung hình. Chỉ báo ô nào đổi (`changed`); APP áp vào cảnh 3D / khung nhìn. Không đổi trận đấu.
## Khi mở, hiện thêm ms mỗi khung, số lệnh vẽ, số tam giác. Phím G mở / đóng.

signal changed(key: StringName, value: int)

const BUTTON: Rect2 = Rect2(584, 214, 170, 44)
const PANEL: Rect2 = Rect2(864, 266, 470, 340)
const CELL: Vector2 = Vector2(215, 56)
const KEYS: Array[StringName] = [&"scenery", &"ground", &"layer", &"fog", &"actors", &"water", &"scale", &"msaa"]
const LABELS: Array[String] = ["Cảnh vật", "Nền ảnh", "Lớp phủ", "Sương", "Nhân vật", "Nước", "Độ phân giải", "MSAA"]
## Giá trị mỗi ô: bật / tắt, riêng độ phân giải (%) và MSAA (×) quay vòng.
const SCALES: Array[int] = [100, 75, 60, 50]
const MSAAS: Array[int] = [0, 2, 4]

var open: bool = false
## Giá trị hiện tại theo KEYS: 1 bật / 0 tắt; `scale` là chỉ số trong SCALES, `msaa` trong MSAAS.
var values: Dictionary[StringName, int] = {&"scenery": 1, &"ground": 1, &"layer": 1, &"fog": 1, &"actors": 1, &"water": 1, &"scale": 1, &"msaa": 0}
## Nơi áp (APP đặt); null thì chỉ báo `changed`.
var view_3d: MatchView3D


## Lấy độ phân giải / MSAA đang dùng (mức đồ họa D-157) làm giá trị đầu.
func read_viewport(vp: Viewport) -> void:
	values[&"scale"] = maxi(0, SCALES.find(roundi(vp.scaling_3d_scale * 100.0)))
	values[&"msaa"] = maxi(0, MSAAS.find([0, 2, 4, 8][vp.msaa_3d]))


func cell_rect(i: int) -> Rect2:
	return Rect2(PANEL.position + Vector2(14 + (i % 2) * (CELL.x + 12), 92 + (i / 2) * (CELL.y + 4)), CELL)


func _has_point(point: Vector2) -> bool:
	return BUTTON.has_point(point) or (open and PANEL.has_point(point))


func press_at(at: Vector2) -> void:
	if BUTTON.has_point(at):
		open = not open
	elif open:
		for i: int in KEYS.size():
			if cell_rect(i).has_point(at):
				var key: StringName = KEYS[i]
				var count: int = SCALES.size() if key == &"scale" else (MSAAS.size() if key == &"msaa" else 2)
				values[key] = (values[key] + 1) % count
				_apply(key)
				changed.emit(key, value_of(key))
	queue_redraw()


func _apply(key: StringName) -> void:
	var on: bool = value_of(key) != 0
	if key == &"scale":
		get_viewport().scaling_3d_scale = value_of(key) / 100.0
	elif key == &"msaa":
		get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][values[key]]
	elif view_3d != null:
		view_3d.set_part(key, on)


## Giá trị thật của ô `key`: 0/1, % độ phân giải, hoặc số mẫu MSAA.
func value_of(key: StringName) -> int:
	if key == &"scale":
		return SCALES[values[key]]
	if key == &"msaa":
		return MSAAS[values[key]]
	return values[key]


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_G:
		visible = true  # D-183: ẩn mặc định, phím tắt cũng hiện bảng
		open = not open
		queue_redraw()


func _process(_delta: float) -> void:
	if open:
		queue_redraw()


func _draw() -> void:
	UiStyle.button(self, BUTTON, &"gold" if open else &"ghost", "Chẩn đoán (G)", "", 18)
	if not open:
		return
	UiStyle.panel(self, PANEL, 12)
	var ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var line: String = "FPS %d · xử lý %.1f ms · vẽ %d lệnh · %dk tam giác" % [Engine.get_frames_per_second(), ms,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)]
	draw_string(UiStyle.sans(true), PANEL.position + Vector2(18, 40), line, HORIZONTAL_ALIGNMENT_LEFT, PANEL.size.x - 30, 18, UiStyle.TEXT)
	draw_string(UiStyle.sans(false), PANEL.position + Vector2(18, 70), "Bấm ô để bật / tắt, đo FPS trước và sau", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.TEXT)
	for i: int in KEYS.size():
		var key: StringName = KEYS[i]
		var text: String = LABELS[i] + ": " + _value_text(key)
		UiStyle.button(self, cell_rect(i), &"blue" if values[key] != 0 or key == &"scale" else &"ghost", text, "", 18)


func _value_text(key: StringName) -> String:
	if key == &"scale":
		return "%d%%" % value_of(key)
	if key == &"msaa":
		return "tắt" if value_of(key) == 0 else "%d×" % value_of(key)
	return "bật" if values[key] != 0 else "tắt"
