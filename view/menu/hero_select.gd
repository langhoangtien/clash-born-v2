class_name HeroSelect
extends Control
## Màn chọn tướng (D-123), vẽ tay theo khung 1920 × 1080: thẻ tướng có chân dung bên trái,
## chi tiết (Chiêu / Chỉ số / Talent) bên phải, hàng dưới chọn tướng bot, độ khó, Xem map và
## BẮT ĐẦU. Chỉ báo lựa chọn qua tín hiệu; APP mở trận.

signal start_pressed(hero_id: StringName, bot_id: StringName, difficulty: int)
signal map_pressed
## D-183: nút Cài đặt (APP mở SettingsPanel).
signal settings_pressed

const CARD: Vector2 = Vector2(192, 262)
const CARD_GAP: float = 14.0
const CARDS_AT: Vector2 = Vector2(64, 140)
const DETAIL: Rect2 = Rect2(720, 110, 1140, 790)
const TAB_SIZE: Vector2 = Vector2(200, 56)
const BOT_AT: Vector2 = Vector2(80, 964)
const BOT_SIZE: float = 84.0
const DIFF_NAMES: Array[String] = ["Dễ", "Thường", "Khó"]
const START: Rect2 = Rect2(1480, 934, 380, 112)
const MAP_BUTTON: Rect2 = Rect2(1196, 954, 130, 72)
## D-183: nút Cài đặt (âm thanh, đồ họa, FPS).
const SETTINGS_BUTTON: Rect2 = Rect2(1336, 954, 130, 72)

var previews: Array[HeroPreview] = []
var selected: int = 0
var bot: int = 1
var difficulty: int = 1
var tab: HeroDetail.Tab = HeroDetail.Tab.SKILLS


func setup(heroes: Array[HeroDef], balance: BalanceSettings) -> void:
	previews.clear()
	for d: HeroDef in heroes:
		previews.append(HeroPreview.of(d, balance))
	bot = mini(1, previews.size() - 1)
	queue_redraw()


func card_rect(i: int) -> Rect2:
	return Rect2(CARDS_AT + Vector2((i % 3) * (CARD.x + CARD_GAP), (i / 3) * (CARD.y + CARD_GAP)), CARD)


func tab_rect(i: int) -> Rect2:
	return Rect2(DETAIL.position + Vector2(24 + i * (TAB_SIZE.x + 12), 190), TAB_SIZE)


func bot_rect(i: int) -> Rect2:
	return Rect2(BOT_AT + Vector2(150 + i * (BOT_SIZE + 10), -BOT_SIZE * 0.5 + 10), Vector2(BOT_SIZE, BOT_SIZE))


func diff_rect(i: int) -> Rect2:
	var x0: float = bot_rect(previews.size()).position.x + 40.0
	return Rect2(Vector2(x0 + i * 112, 958), Vector2(104, 64))


func press_at(at: Vector2) -> void:
	for i: int in range(previews.size()):
		if card_rect(i).has_point(at):
			selected = i
		if bot_rect(i).has_point(at):
			bot = i
	for i: int in range(HeroDetail.TAB_NAMES.size()):
		if tab_rect(i).has_point(at):
			tab = i as HeroDetail.Tab
	for i: int in range(DIFF_NAMES.size()):
		if diff_rect(i).has_point(at):
			difficulty = i
	if START.has_point(at) and not previews.is_empty():
		start_pressed.emit(previews[selected].def.id, previews[bot].def.id, difficulty)
	if MAP_BUTTON.has_point(at):
		map_pressed.emit()
	if SETTINGS_BUTTON.has_point(at):
		settings_pressed.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _draw() -> void:  # D-130: giao diện theo UiStyle
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.BG)
	draw_string(UiStyle.serif(true), Vector2(60, 70), "CLASHBORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, UiStyle.GOLD)
	UiStyle.divider(self, Vector2(428, 30), Vector2(428, 76))
	draw_string(UiStyle.serif(), Vector2(456, 66), "Chọn tướng", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiStyle.DIM)
	UiStyle.panel(self, Rect2(Vector2(40, 116), Vector2(DETAIL.position.x - 60, 784)))
	for i: int in range(previews.size()):
		_card(i)
	if not previews.is_empty():
		_detail()
	_bottom()


func _card(i: int) -> void:
	var r: Rect2 = card_rect(i)
	var p: HeroPreview = previews[i]
	var on: bool = i == selected
	UiStyle.card(self, r, on)
	HeroDetail.portrait(self, p, Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, r.size.x - 20)), on)
	UiStyle.text_center(self, UiStyle.serif(true), Vector2(r.get_center().x, r.end.y - 38), p.def.display_name.get_slice(" · ", 0), 28, UiStyle.TEXT)
	UiStyle.text_center(self, UiStyle.serif(), Vector2(r.get_center().x, r.end.y - 12), p.primary_name(), 18, UiStyle.DIM)


func _detail() -> void:
	UiStyle.panel(self, DETAIL)
	var p: HeroPreview = previews[selected]
	HeroDetail.draw_header(self, p, DETAIL.position + Vector2(24, 24))
	for i: int in range(HeroDetail.TAB_NAMES.size()):
		var r: Rect2 = tab_rect(i)
		var on: bool = i == tab
		if on:
			draw_style_box(UiStyle.box(Color(0.5, 0.37, 0.14, 0.95), UiStyle.GOLD, 2, 8, Color(UiStyle.GOLD, 0.2), 6), r)
		else:
			draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 1, 8), r)
		UiStyle.text_center(self, UiStyle.serif(on), r.get_center(), HeroDetail.TAB_NAMES[i], 26, Color(1, 0.95, 0.85) if on else UiStyle.DIM)
	UiStyle.divider(self, Vector2(tab_rect(0).position.x, tab_rect(0).end.y + 8), Vector2(DETAIL.end.x - 24, tab_rect(0).end.y + 8))
	var area: Rect2 = Rect2(DETAIL.position + Vector2(24, 272), DETAIL.size - Vector2(48, 292))
	HeroDetail.draw_tab(self, p, tab, area)


func _bottom() -> void:
	UiStyle.panel(self, Rect2(Vector2(40, 918), Vector2(size.x - 80, 144)))
	draw_string(UiStyle.serif(), BOT_AT + Vector2(0, 18), "Đối thủ (bot)", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiStyle.DIM)
	for i: int in range(previews.size()):
		var r: Rect2 = bot_rect(i)
		var on: bool = i == bot
		draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.GOLD if on else UiStyle.LINE, 3 if on else 1, 8, Color(UiStyle.GOLD, 0.25) if on else Color(0, 0, 0, 0), 6 if on else 0), r)
		HeroDetail.portrait(self, previews[i], r.grow(-3), on)
	for i: int in range(DIFF_NAMES.size()):
		var on: bool = i == difficulty
		UiStyle.button(self, diff_rect(i), &"gold" if on else &"ghost", DIFF_NAMES[i], "", 24)
	UiStyle.button(self, MAP_BUTTON, &"blue", "Map", "", 24)
	UiStyle.button(self, SETTINGS_BUTTON, &"ghost", "Cài đặt", "", 26)
	UiStyle.button(self, START, &"gold", "BẮT ĐẦU", "", 46)
