class_name HeroSelect
extends Control
## Màn chọn tướng (D-123), vẽ tay theo khung 1920 × 1080: thẻ tướng có chân dung bên trái,
## chi tiết (Chiêu / Chỉ số / Talent) bên phải, hàng dưới chọn tướng bot, độ khó, Xem map và
## BẮT ĐẦU. Chỉ báo lựa chọn qua tín hiệu; APP mở trận.

signal start_pressed(hero_id: StringName, bot_id: StringName, difficulty: int)
signal map_pressed

const CARD: Vector2 = Vector2(200, 250)
const CARD_GAP: float = 20.0
const CARDS_AT: Vector2 = Vector2(60, 150)
const DETAIL: Rect2 = Rect2(720, 110, 1140, 790)
const TAB_SIZE: Vector2 = Vector2(200, 56)
const BOT_AT: Vector2 = Vector2(60, 960)
const BOT_SIZE: float = 84.0
const DIFF_NAMES: Array[String] = ["Dễ", "Thường", "Khó"]
const START: Rect2 = Rect2(1500, 930, 360, 120)
const MAP_BUTTON: Rect2 = Rect2(1240, 960, 200, 70)

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
	var x0: float = bot_rect(previews.size()).position.x + 150.0
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
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite():
		press_at(at)
		accept_event()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.055, 0.075))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 96)), Color(0.08, 0.07, 0.06))
	draw_string(font, Vector2(60, 66), "CLASHBORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, HeroDetail.GOLD)
	draw_string(font, Vector2(400, 64), "Chọn tướng", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, HeroDetail.DIM)
	for i: int in range(previews.size()):
		_card(font, i)
	if not previews.is_empty():
		_detail(font)
	_bottom(font)


func _card(font: Font, i: int) -> void:
	var r: Rect2 = card_rect(i)
	var p: HeroPreview = previews[i]
	var on: bool = i == selected
	draw_rect(r, Color(0.14, 0.12, 0.1) if on else Color(0.1, 0.11, 0.14))
	var tex: Texture2D = ArtLibrary.texture(StringName(String(p.def.id) + "_portrait"))
	var pic: Rect2 = Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, r.size.x - 20))
	if tex != null:
		draw_texture_rect(tex, pic, false, Color.WHITE if on else Color(0.75, 0.75, 0.75))
	else:
		draw_rect(pic, Color(0.18, 0.2, 0.16))
		HeroDetail._center(self, font, pic.get_center(), p.def.display_name.left(1), 90, HeroDetail.GOLD)
	var name: String = p.def.display_name.get_slice(" · ", 0)
	HeroDetail._center(self, font, Vector2(r.get_center().x, r.end.y - 34), name, 26, Color.WHITE)
	HeroDetail._center(self, font, Vector2(r.get_center().x, r.end.y - 10), p.primary_name(), 16, HeroDetail.DIM)
	draw_rect(r, HeroDetail.GOLD if on else Color(1, 1, 1, 0.15), false, 4.0 if on else 2.0)


func _detail(font: Font) -> void:
	draw_rect(DETAIL, Color(0.08, 0.085, 0.11))
	draw_rect(DETAIL, Color(1, 0.84, 0.4, 0.35), false, 2.0)
	var p: HeroPreview = previews[selected]
	HeroDetail.draw_header(self, font, p, DETAIL.position + Vector2(24, 24))
	for i: int in range(HeroDetail.TAB_NAMES.size()):
		var r: Rect2 = tab_rect(i)
		var on: bool = i == tab
		draw_rect(r, Color(0.5, 0.38, 0.12) if on else Color(0.13, 0.14, 0.18))
		HeroDetail._center(self, font, r.get_center(), HeroDetail.TAB_NAMES[i], 24, Color.WHITE if on else HeroDetail.DIM)
	var area: Rect2 = Rect2(DETAIL.position + Vector2(24, 270), DETAIL.size - Vector2(48, 290))
	HeroDetail.draw_tab(self, font, p, tab, area)


func _bottom(font: Font) -> void:
	draw_rect(Rect2(Vector2(0, 910), Vector2(size.x, size.y - 910)), Color(0.07, 0.07, 0.09))
	draw_string(font, BOT_AT + Vector2(0, 18), "Đối thủ (bot)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, HeroDetail.DIM)
	for i: int in range(previews.size()):
		var r: Rect2 = bot_rect(i)
		var tex: Texture2D = ArtLibrary.texture(StringName(String(previews[i].def.id) + "_portrait"))
		draw_rect(r, Color(0.12, 0.13, 0.17))
		if tex != null:
			draw_texture_rect(tex, r, false, Color.WHITE if i == bot else Color(0.55, 0.55, 0.55))
		else:
			HeroDetail._center(self, font, r.get_center(), previews[i].def.display_name.left(1), 40, HeroDetail.GOLD)
		draw_rect(r, Color(1, 0.4, 0.35) if i == bot else Color(1, 1, 1, 0.12), false, 3.0 if i == bot else 1.0)
	for i: int in range(DIFF_NAMES.size()):
		var r: Rect2 = diff_rect(i)
		draw_rect(r, Color(0.45, 0.2, 0.18) if i == difficulty else Color(0.13, 0.14, 0.18))
		HeroDetail._center(self, font, r.get_center(), DIFF_NAMES[i], 22, Color.WHITE if i == difficulty else HeroDetail.DIM)
	draw_rect(MAP_BUTTON, Color(0.13, 0.14, 0.18))
	HeroDetail._center(self, font, MAP_BUTTON.get_center(), "Xem map", 22, HeroDetail.DIM)
	draw_rect(START, Color(0.62, 0.42, 0.1))
	draw_rect(START, HeroDetail.GOLD, false, 3.0)
	HeroDetail._center(self, font, START.get_center(), "BẮT ĐẦU", 44, Color.WHITE)
