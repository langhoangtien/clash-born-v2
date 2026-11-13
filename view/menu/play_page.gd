class_name PlayPage
extends Control
## D-413: Chọn chế độ (mở từ nút CHƠI ở Trang chủ) — trái: Đấu bot 1v1 · Đấu bot 3v3 · Online · Trận thử; phải: lưới tướng
## gọn + lựa chọn riêng của chế độ (đối thủ bot khi 1v1, độ khó, xem map; Trận thử chọn thêm 1v1 / 3v3 — MATCH-06) → BẮT
## ĐẦU. Online mở bảng Online hiện có. Chỉ báo lựa chọn qua tín hiệu; APP mở trận.

signal start_pressed(hero_id: StringName, bot_id: StringName, difficulty: int, team_size: int, practice: bool)
signal online_pressed
signal map_pressed
signal back_pressed

enum Mode { BOT_1V1, BOT_3V3, ONLINE, PRACTICE }

const MODE_NAMES: Array[String] = ["Đấu bot 1v1", "Đấu bot 3v3", "Online", "Trận thử"]
const MODE_SUBS: Array[String] = ["Bạn và một bot đối thủ", "Đồng đội và đối thủ là bot", "Phòng theo mã, chơi với người",
	"Không tính thống kê · có bảng Test"]
const DIFF_NAMES: Array[String] = ["Dễ", "Thường", "Khó"]
const LEFT_W: float = 460.0
const PAD: float = 40.0
const CELL: Vector2 = Vector2(132, 164)
const COLUMNS: int = 6
const BOT_SIZE: float = 72.0

var previews: Array[HeroPreview] = []
var mode: Mode = Mode.BOT_1V1
var selected: int = 0
var bot: int = 1
var difficulty: int = 1
## Trận thử: 1v1 hay 3v3.
var practice_size: int = 1


func setup(list: Array[HeroPreview]) -> void:
	previews = list
	bot = mini(1, previews.size() - 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func back_rect() -> Rect2:
	return Rect2(Vector2(PAD, 24), Vector2(200, 60))


func mode_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAD, 120 + i * 150), Vector2(LEFT_W - PAD, 132))


func right_x() -> float:
	return LEFT_W + PAD


## Số cột lưới tướng theo bề rộng (màn 20:9 rộng hơn: ít hàng hơn).
func columns() -> int:
	return clampi(int((size.x - right_x() - PAD) / (CELL.x + 12)), COLUMNS, 8)


func hero_rect(i: int) -> Rect2:
	return Rect2(Vector2(right_x() + (i % columns()) * (CELL.x + 12), 84 + (i / columns()) * (CELL.y + 12)), CELL)


func options_y() -> float:
	return hero_rect(previews.size() - 1).end.y + 40.0 if not previews.is_empty() else 120.0


func team_size() -> int:
	return [1, 3, 1, practice_size][mode]


## Đối thủ bot chỉ chọn được khi 1v1 (3v3: đồng đội và đối thủ ngẫu nhiên — MATCH-02).
func picks_bot() -> bool:
	return team_size() == 1


func bot_rect(i: int) -> Rect2:
	return Rect2(Vector2(right_x() + 200 + i * (BOT_SIZE + 8), options_y()), Vector2(BOT_SIZE, BOT_SIZE))


func diff_rect(i: int) -> Rect2:
	return Rect2(Vector2(right_x() + 200 + i * 132, options_y() + (BOT_SIZE + 28 if picks_bot() else 0.0)), Vector2(120, 64))


func size_rect(i: int) -> Rect2:
	return Rect2(Vector2(diff_rect(2).end.x + 60 + i * 132, diff_rect(0).position.y), Vector2(120, 64))


func map_rect() -> Rect2:
	return Rect2(Vector2(right_x(), size.y - 136), Vector2(220, 96))


func start_rect() -> Rect2:
	return Rect2(Vector2(size.x - PAD - 444, size.y - 152), Vector2(420, 112))


func press_at(at: Vector2) -> void:
	if back_rect().has_point(at):
		back_pressed.emit()
	for i: int in MODE_NAMES.size():
		if mode_rect(i).has_point(at):
			if i == Mode.ONLINE:
				online_pressed.emit()
			else:
				mode = i as Mode
	_press_options(at)
	if bot == selected and previews.size() > 1:  # MATCH-02: không trùng tướng với đối thủ
		bot = (selected + 1) % previews.size()
	if map_rect().has_point(at):
		map_pressed.emit()
	if start_rect().has_point(at) and not previews.is_empty():
		start_pressed.emit(previews[selected].def.id, previews[bot].def.id, difficulty, team_size(), mode == Mode.PRACTICE)
	queue_redraw()


func _press_options(at: Vector2) -> void:
	for i: int in previews.size():
		if hero_rect(i).has_point(at):
			selected = i
		if picks_bot() and bot_rect(i).has_point(at):
			bot = i
	for i: int in DIFF_NAMES.size():
		if diff_rect(i).has_point(at):
			difficulty = i
	for i: int in 2:
		if mode == Mode.PRACTICE and size_rect(i).has_point(at):
			practice_size = [1, 3][i]


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _draw() -> void:
	UiStyle.button(self, back_rect(), &"ghost", "‹ Quay lại", "", 26)
	for i: int in MODE_NAMES.size():
		var r: Rect2 = mode_rect(i)
		UiStyle.card(self, r, i == mode)
		draw_string(UiStyle.serif(true), r.position + Vector2(28, 58), MODE_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 36,
			UiStyle.GOLD if i == mode else UiStyle.TEXT)
		draw_string(UiStyle.sans(), r.position + Vector2(28, 100), MODE_SUBS[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40, 21, UiStyle.DIM)
	UiStyle.panel(self, Rect2(Vector2(right_x() - 20, 24), Vector2(size.x - right_x() - PAD + 20, size.y - 48)))
	draw_string(UiStyle.serif(true), Vector2(right_x(), 66), "Chọn tướng — " + MODE_NAMES[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UiStyle.GOLD)
	for i: int in previews.size():
		_hero(i)
	_options()
	UiStyle.button(self, map_rect(), &"blue", "Xem map", "", 28)
	UiStyle.button(self, start_rect(), &"gold", "BẮT ĐẦU", "", 50)


func _hero(i: int) -> void:
	var r: Rect2 = hero_rect(i)
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
			draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.GOLD if i == bot else UiStyle.LINE, 3 if i == bot else 1, 8), r)
			HeroDetail.portrait(self, previews[i], r.grow(-3), i == bot)
	var dy: float = diff_rect(0).position.y
	draw_string(UiStyle.serif(), Vector2(right_x(), dy + 42), "Độ khó bot", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.DIM)
	for i: int in DIFF_NAMES.size():
		UiStyle.button(self, diff_rect(i), &"gold" if i == difficulty else &"ghost", DIFF_NAMES[i], "", 26)
	if mode == Mode.PRACTICE:
		for i: int in 2:
			var n: int = [1, 3][i]
			UiStyle.button(self, size_rect(i), &"gold" if n == practice_size else &"ghost", "%d vs %d" % [n, n], "", 26)
