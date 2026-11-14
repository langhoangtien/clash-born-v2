class_name PlayPage
extends Control
## D-413 + D-356 (người chơi chốt: giao diện chỉ còn 5v5 mặc định và 1v1): Chọn chế độ (mở từ nút CHƠI) — trái hai thẻ lớn:
## 5v5 [Chơi ngay · Phòng bạn bè] và 1v1 [Đấu bot · Đấu bạn]. Chơi ngay / Đấu bot → phải: lưới tướng + độ khó + xem map
## (1v1 thêm đối thủ bot — MATCH-02) → BẮT ĐẦU (5v5 chưa có tìm trận tự động: chạy trong máy, 9 ô còn lại là bot). Phòng bạn
## bè / Đấu bạn → bảng Online (phòng theo mã, cỡ tương ứng). Trận thử chỉ còn ở nút "Thử tướng" (trang Tướng).

signal start_pressed(hero_id: StringName, bot_id: StringName, difficulty: int, team_size: int, practice: bool)
signal online_pressed(team_size: int)
signal map_pressed
signal back_pressed

enum Mode { FIVE, ONE }

const MODE_NAMES: Array[String] = ["5v5", "1v1"]
const MODE_SIZES: Array[int] = [5, 1]
const MODE_SUBS: Array[String] = ["Mỗi đội 5 tướng · ô trống là bot", "Đối đầu một chọi một"]
const ACTIONS: Array[Array] = [["Chơi ngay", "Phòng bạn bè"], ["Đấu bot", "Đấu bạn"]]
const DIFF_NAMES: Array[String] = ["Dễ", "Thường", "Khó"]
const LEFT_W: float = 460.0
const PAD: float = 40.0
const CELL: Vector2 = Vector2(132, 164)
const COLUMNS: int = 6
const BOT_SIZE: float = 72.0
const GRID_ROWS: int = 2  ## hàng tướng nhìn thấy; nhiều tướng hơn thì cuộn dọc (hàng đối thủ cuộn ngang)

var previews: Array[HeroPreview] = []
var mode: Mode = Mode.FIVE
var selected: int = 0
var bot: int = 1
var difficulty: int = 1
var grid_scroll: ScrollArea = ScrollArea.make(true)
var bot_scroll: ScrollArea = ScrollArea.make(false)


func setup(list: Array[HeroPreview]) -> void:
	previews = list
	bot = mini(1, previews.size() - 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func back_rect() -> Rect2:
	return Rect2(Vector2(PAD, 24), Vector2(200, 60))


func mode_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAD, 120 + i * 330), Vector2(LEFT_W - PAD, 300))


## Nút trong thẻ chế độ `i`: j = 0 chơi với bot trong máy, 1 phòng bạn bè (Online).
func action_rect(i: int, j: int) -> Rect2:
	var r: Rect2 = mode_rect(i)
	return Rect2(Vector2(r.position.x + 24, r.position.y + 150 + j * 72), Vector2(r.size.x - 48, 60))


func right_x() -> float:
	return LEFT_W + PAD


## Số cột lưới tướng theo bề rộng (màn 20:9 rộng hơn: ít hàng hơn).
func columns() -> int:
	return clampi(int((size.x - right_x() - PAD) / (CELL.x + 12)), COLUMNS, 8)


func hero_rect(i: int) -> Rect2:
	_layout()
	return Rect2(grid_scroll.shift(Vector2(right_x() + (i % columns()) * (CELL.x + 12), 84 + (i / columns()) * (CELL.y + 12))), CELL)


func options_y() -> float:
	return 84.0 + GRID_ROWS * (CELL.y + 12) + 28.0


## Khung nhìn + độ dài nội dung của hai vùng cuộn theo cỡ trang và số tướng.
func _layout() -> void:
	grid_scroll.rect = Rect2(Vector2(right_x(), 84), Vector2(columns() * (CELL.x + 12), GRID_ROWS * (CELL.y + 12) - 12))
	grid_scroll.content = ceili(previews.size() / float(columns())) * (CELL.y + 12) - 12
	var x: float = right_x() + 200
	bot_scroll.rect = Rect2(Vector2(x, options_y()), Vector2(size.x - PAD - 40 - x, BOT_SIZE))
	bot_scroll.content = previews.size() * (BOT_SIZE + 8) - 8


func team_size() -> int:
	return MODE_SIZES[mode]


## Đối thủ bot chỉ chọn được khi 1v1 (5v5: đồng đội và đối thủ ngẫu nhiên, không trùng — MATCH-02).
func picks_bot() -> bool:
	return team_size() == 1


func bot_rect(i: int) -> Rect2:
	_layout()
	return Rect2(bot_scroll.shift(Vector2(right_x() + 200 + i * (BOT_SIZE + 8), options_y())), Vector2(BOT_SIZE, BOT_SIZE))


func diff_rect(i: int) -> Rect2:
	return Rect2(Vector2(right_x() + 200 + i * 132, options_y() + (BOT_SIZE + 28 if picks_bot() else 0.0)), Vector2(120, 64))


func map_rect() -> Rect2:
	return Rect2(Vector2(right_x(), size.y - 136), Vector2(220, 96))


func start_rect() -> Rect2:
	return Rect2(Vector2(size.x - PAD - 444, size.y - 152), Vector2(420, 112))


func press_at(at: Vector2) -> void:
	if back_rect().has_point(at):
		back_pressed.emit()
	for i: int in MODE_NAMES.size():
		if action_rect(i, 1).has_point(at):
			online_pressed.emit(MODE_SIZES[i])
		elif mode_rect(i).has_point(at):
			mode = i as Mode
	_press_options(at)
	if bot == selected and previews.size() > 1:  # MATCH-02: không trùng tướng với đối thủ
		bot = (selected + 1) % previews.size()
	if map_rect().has_point(at):
		map_pressed.emit()
	if start_rect().has_point(at) and not previews.is_empty():
		start_pressed.emit(previews[selected].def.id, previews[bot].def.id, difficulty, team_size(), false)
	queue_redraw()


func _press_options(at: Vector2) -> void:
	for i: int in previews.size():
		if hero_rect(i).has_point(at) and grid_scroll.shows(hero_rect(i)):
			selected = i
		if picks_bot() and bot_rect(i).has_point(at) and bot_scroll.shows(bot_rect(i)):
			bot = i
	for i: int in DIFF_NAMES.size():
		if diff_rect(i).has_point(at):
			difficulty = i


func _gui_input(event: InputEvent) -> void:
	_layout()
	if grid_scroll.handle(event) or (picks_bot() and bot_scroll.handle(event)):
		queue_redraw()
		accept_event()
		return
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _draw() -> void:
	UiStyle.button(self, back_rect(), &"ghost", "‹ Quay lại", "", 26)
	for i: int in MODE_NAMES.size():
		var r: Rect2 = mode_rect(i)
		UiStyle.card(self, r, i == mode)
		draw_string(UiStyle.serif(true), r.position + Vector2(28, 84), MODE_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 72,
			UiStyle.GOLD if i == mode else UiStyle.TEXT)
		draw_string(UiStyle.sans(), r.position + Vector2(30, 124), MODE_SUBS[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 21, UiStyle.DIM)
		for j: int in 2:
			UiStyle.button(self, action_rect(i, j), &"gold" if i == mode and j == 0 else (&"blue" if j == 1 else &"ghost"), ACTIONS[i][j], "", 26)
	UiStyle.panel(self, Rect2(Vector2(right_x() - 20, 24), Vector2(size.x - right_x() - PAD + 20, size.y - 48)))
	draw_string(UiStyle.serif(true), Vector2(right_x(), 66), "Chọn tướng — %s · %s" % [MODE_NAMES[mode], ACTIONS[mode][0]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UiStyle.GOLD)
	for i: int in previews.size():
		_hero(i)
	grid_scroll.draw_bar(self)
	_options()
	if picks_bot():
		bot_scroll.draw_bar(self)
	UiStyle.button(self, map_rect(), &"blue", "Xem map", "", 28)
	UiStyle.button(self, start_rect(), &"gold", "BẮT ĐẦU", "", 50)


func _hero(i: int) -> void:
	var r: Rect2 = hero_rect(i)
	if not grid_scroll.shows(r):
		return
	UiStyle.card(self, r, i == selected)
	HeroDetail.portrait(self, previews[i], Rect2(r.position + Vector2(10, 8), Vector2(r.size.x - 20, r.size.x - 20)), i == selected)
	UiStyle.text_center(self, UiStyle.serif(true), Vector2(r.get_center().x, r.end.y - 16),
		previews[i].def.display_name.get_slice(" · ", 0), 19, UiStyle.TEXT)


func _options() -> void:
	var y: float = options_y()
	if picks_bot():
		draw_string(UiStyle.serif(), Vector2(right_x(), y + 46), "Đối thủ (bot)", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.DIM)
		for i: int in previews.size():
			var r: Rect2 = bot_rect(i)
			if not bot_scroll.shows(r):
				continue
			draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.GOLD if i == bot else UiStyle.LINE, 3 if i == bot else 1, 8), r)
			HeroDetail.portrait(self, previews[i], r.grow(-3), i == bot)
	var dy: float = diff_rect(0).position.y
	draw_string(UiStyle.serif(), Vector2(right_x(), dy + 42), "Độ khó bot", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.DIM)
	for i: int in DIFF_NAMES.size():
		UiStyle.button(self, diff_rect(i), &"gold" if i == difficulty else &"ghost", DIFF_NAMES[i], "", 26)
