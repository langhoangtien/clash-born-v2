class_name MenuShell
extends Control
## D-413: khung menu — thanh trên cố định (logo · Trang chủ · Tướng · Trang bị · tài khoản · ⚙ Cài đặt) và các trang bên
## dưới, mỗi lúc hiện một trang. Trang "play" (Chọn chế độ, mở từ nút CHƠI) không có thẻ trên thanh: có nút Quay lại về
## trang trước. Trang tự lo nội dung; khung chỉ điều hướng và báo nút tài khoản qua tín hiệu.

signal account_pressed

const BAR_H: float = 96.0
const TABS: Array[StringName] = [&"home", &"heroes", &"items"]
const TAB_NAMES: Dictionary[StringName, String] = {&"home": "Trang chủ", &"heroes": "Tướng", &"items": "Trang bị"}
const TAB_SIZE: Vector2 = Vector2(210, 60)
const TABS_X: float = 470.0
const GEAR: float = 64.0
const ACCOUNT_W: float = 300.0

var pages: Dictionary[StringName, Control] = {}
var current: StringName = &""
## Tên tài khoản đang đăng nhập ("" = chưa; APP đặt).
var account_name: String = ""
var _history: Array[StringName] = []


## Thêm trang `key` (ẩn tới khi được mở).
func add_page(key: StringName, page: Control) -> void:
	pages[key] = page
	page.name = String(key).capitalize().replace(" ", "") + "Page"
	page.visible = false
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_top = BAR_H


func open(key: StringName) -> void:
	if not pages.has(key) or key == current:
		return
	if current != &"":
		pages[current].visible = false
		if key != &"play":
			_history.clear()
		else:
			_history.append(current)
	current = key
	pages[key].visible = true
	queue_redraw()


## Nút Quay lại của trang không có thẻ (Chọn chế độ): về trang mở nó.
func back() -> void:
	open(_history.pop_back() if not _history.is_empty() else &"home")


func tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(TABS_X + i * (TAB_SIZE.x + 12), (BAR_H - TAB_SIZE.y) * 0.5), TAB_SIZE)


func gear_rect() -> Rect2:
	return Rect2(Vector2(size.x - GEAR - 24, (BAR_H - GEAR) * 0.5), Vector2(GEAR, GEAR))


func account_rect() -> Rect2:
	return Rect2(Vector2(gear_rect().position.x - ACCOUNT_W - 16, (BAR_H - TAB_SIZE.y) * 0.5), Vector2(ACCOUNT_W, TAB_SIZE.y))


func press_at(at: Vector2) -> void:
	for i: int in TABS.size():
		if tab_rect(i).has_point(at):
			open(TABS[i])
	if gear_rect().has_point(at):
		open(&"settings")
	if account_rect().has_point(at):
		account_pressed.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite() and at.y <= BAR_H:
		press_at(at)
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BG)
	draw_rect(Rect2(0, 0, size.x, BAR_H), Color(0.03, 0.045, 0.08, 0.97))
	draw_line(Vector2(0, BAR_H), Vector2(size.x, BAR_H), Color(UiStyle.GOLD_DEEP, 0.8), 2.0)
	draw_string(UiStyle.serif(true), Vector2(48, 66), "CLASHBORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 50, UiStyle.GOLD)
	for i: int in TABS.size():
		var on: bool = TABS[i] == current or (current == &"play" and TABS[i] == &"home")
		UiStyle.button(self, tab_rect(i), &"gold" if on else &"ghost", TAB_NAMES[TABS[i]], "", 28)
	UiStyle.button(self, account_rect(), &"ghost", account_name if account_name != "" else "Đăng nhập", "", 24)
	UiStyle.button(self, gear_rect(), &"gold" if current == &"settings" else &"ghost", "", "", 24)
	_gear(gear_rect().get_center(), GEAR * 0.3)


## Bánh răng: vành răng + lỗ giữa (cùng dáng nút Cài đặt trong trận).
func _gear(c: Vector2, s: float) -> void:
	for k: int in 8:
		var d: Vector2 = Vector2.from_angle(TAU * k / 8.0)
		draw_line(c + d * s * 0.7, c + d * s * 1.15, UiStyle.TEXT, s * 0.32)
	draw_circle(c, s * 0.8, UiStyle.TEXT)
	draw_circle(c, s * 0.35, Color(0.05, 0.07, 0.11))
