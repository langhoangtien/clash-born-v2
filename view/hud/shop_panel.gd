class_name ShopPanel
extends Control
## Cửa hàng kiểu Liên Quân (M6.6, D-90; hình vẽ ở M8). Nút "Shop" dưới ô máu/mana hoặc phím B
## mở/đóng. Trái: thẻ danh mục. Giữa: lưới món (mờ khi chưa mua được). Phải: chi tiết món đang
## chọn — giá, nhãn, chỉ số, mô tả, nút Mua (hoặc Bán khi chọn đồ đang có). Dưới: 6 ô đồ của hero.
## Chỉ đọc World và báo bằng tín hiệu.

const BUTTON: Rect2 = Rect2(292, 160, 120, 44)
const PANEL_SIZE: Vector2 = Vector2(1640, 900)
const TAB_SIZE: Vector2 = Vector2(190, 76)
const CARD_SIZE: Vector2 = Vector2(122, 126)
const CARD_GAP: float = 10.0
const COLUMNS: int = 6
## Vùng lưới món (cuộn dọc khi nhiều món): từ y = GRID_TOP tới trên hàng ô đồ.
const GRID_TOP: float = 80.0
const GRID_BOTTOM_GAP: float = 150.0
const SCROLL_STEP: float = 136.0
const GRID_LEFT: float = 230.0
const DETAIL_LEFT: float = 1080.0
const SLOT_SIZE: Vector2 = Vector2(116, 86)

enum Tab { ALL, BASIC, ATTACK, MAGIC, DEFENSE, UTILITY, SECRET }
const TAB_NAMES: PackedStringArray = ["Tất cả", "Cơ bản", "Tấn công", "Phép", "Phòng thủ", "Tiện ích", "Shop ẩn"]
const CATEGORY_TAB: Dictionary = {
	ItemDef.Category.BASIC: Tab.BASIC,
	ItemDef.Category.ATTACK: Tab.ATTACK,
	ItemDef.Category.MAGIC: Tab.MAGIC,
	ItemDef.Category.DEFENSE: Tab.DEFENSE,
	ItemDef.Category.UTILITY: Tab.UTILITY,
}
const REASONS: Dictionary = {
	Command.Reject.NOT_ENOUGH_GOLD: "Thiếu vàng",
	Command.Reject.INVENTORY_FULL: "Hết ô đồ",
	Command.Reject.NOT_IN_SHOP: "Tới shop ẩn S1 / S1'",
	Command.Reject.NOT_YET: "Chưa mở",
	Command.Reject.SOLD_OUT: "Đã có người mua",
	Command.Reject.OUT_OF_STOCK: "Hết hàng",
}
## Tên và cách ghi chỉ số (tỉ lệ thì nhân 100 và thêm %).
const STATS: Dictionary = {
	&"strength": ["Sức mạnh", false],
	&"agility": ["Nhanh nhẹn", false],
	&"intelligence": ["Trí tuệ", false],
	&"max_hp": ["Máu", false],
	&"max_mana": ["Mana", false],
	&"hp_regen": ["Hồi máu", false],
	&"mana_regen": ["Hồi mana", false],
	&"physical_damage": ["Sát thương", false],
	&"physical_armor": ["Giáp", false],
	&"magic_armor": ["Kháng phép", false],
	&"attack_speed": ["Tốc đánh", true],
	&"movement_speed": ["Tốc chạy", false],
	&"lifesteal": ["Hút máu", true],
	&"evasion": ["Né tránh", true],
	&"critical_chance": ["Tỉ lệ chí mạng", true],
}

signal buy_pressed(item_id: StringName)
signal sell_pressed(index: int)

var world: World
var hero: Entity
var open: bool = false
var tab: Tab = Tab.ALL
## Món đang xem: một món trong cửa hàng (`selected_id`) hoặc một ô đồ đang có (`selected_slot` ≥ 0).
var selected_id: StringName = &""
var selected_slot: int = -1
## Độ cuộn của lưới món (px, ≥ 0).
var scroll: float = 0.0
var _drag_from: float = INF


func panel_rect() -> Rect2:
	return Rect2((size - PANEL_SIZE) * 0.5, PANEL_SIZE)


## Món trong thẻ `which`, theo giá tăng dần rồi id.
func catalog(which: Tab = Tab.ALL) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for d: ItemDef in world.item_catalog.values():
		if which == Tab.ALL or (which == Tab.SECRET and d.shop == ItemDef.ShopKind.SECRET) or CATEGORY_TAB.get(d.category, -1) == which:
			out.append(d)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.cost < b.cost or (a.cost == b.cost and String(a.id) < String(b.id)))
	return out


func tab_rect(i: int) -> Rect2:
	return Rect2(panel_rect().position + Vector2(20, 80 + i * (TAB_SIZE.y + 10)), TAB_SIZE)


func card_rect(i: int) -> Rect2:
	var at: Vector2 = Vector2(GRID_LEFT + (i % COLUMNS) * (CARD_SIZE.x + CARD_GAP), GRID_TOP + (i / COLUMNS) * (CARD_SIZE.y + CARD_GAP) - scroll)
	return Rect2(panel_rect().position + at, CARD_SIZE)


## Khung nhìn của lưới món; thẻ ngoài khung không vẽ, không chạm được.
func grid_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(GRID_LEFT, GRID_TOP), Vector2(COLUMNS * (CARD_SIZE.x + CARD_GAP), p.size.y - GRID_TOP - GRID_BOTTOM_GAP))


func max_scroll() -> float:
	var rows: int = ceili(float(catalog(tab).size()) / COLUMNS)
	return maxf(0.0, rows * (CARD_SIZE.y + CARD_GAP) - grid_rect().size.y)


func scroll_by(amount: float) -> void:
	scroll = clampf(scroll + amount, 0.0, max_scroll())
	queue_redraw()


func slot_rect(i: int) -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(GRID_LEFT + i * (SLOT_SIZE.x + 12), p.size.y - SLOT_SIZE.y - 24), SLOT_SIZE)


func detail_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(DETAIL_LEFT, 80), Vector2(p.size.x - DETAIL_LEFT - 24, p.size.y - 104))


func action_rect() -> Rect2:
	var d: Rect2 = detail_rect()
	return Rect2(d.position + Vector2(24, d.size.y - 96), Vector2(d.size.x - 48, 76))


func close_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(p.size.x - 70, 14), Vector2(52, 52))


func toggle() -> void:
	open = not open
	queue_redraw()


## Món đang hiện ở khung chi tiết (null nếu chưa chọn).
func selected_def() -> ItemDef:
	if selected_slot >= 0:
		var it: ItemInstance = Items.slots(hero)[selected_slot]
		return it.def if it != null else null
	return world.item_catalog.get(selected_id) as ItemDef


func _has_point(point: Vector2) -> bool:
	return BUTTON.has_point(point) or (open and panel_rect().has_point(point))


func press_at(local: Vector2) -> void:
	if BUTTON.has_point(local) or (open and close_rect().has_point(local)):
		toggle()
		return
	if not open:
		return
	for i: int in range(TAB_NAMES.size()):
		if tab_rect(i).has_point(local):
			tab = i as Tab
			scroll = 0.0
			return
	var items: Array[ItemDef] = catalog(tab)
	for i: int in range(items.size()):
		if card_rect(i).has_point(local) and grid_rect().has_point(local):
			selected_id = items[i].id
			selected_slot = -1
			return
	for i: int in range(Items.SLOTS):
		if slot_rect(i).has_point(local) and Items.slots(hero)[i] != null:
			selected_slot = i
			return
	if action_rect().has_point(local):
		_act()


## Nút ở khung chi tiết: Bán khi đang xem đồ của mình, Mua khi xem món của cửa hàng (chỉ khi mua được).
func _act() -> void:
	if selected_slot >= 0:
		if Items.slots(hero)[selected_slot] != null:
			sell_pressed.emit(selected_slot)
		selected_slot = -1
	elif selected_def() != null and Shop.buy_problem(world, hero, selected_id) == Command.Reject.NONE:
		buy_pressed.emit(selected_id)


func _gui_input(event: InputEvent) -> void:
	var at: Vector2 = Taps.press_position(event)  # D-102: click PC không bật/tắt hai lần
	if at.is_finite():
		press_at(at)
		_drag_from = at.y if open and grid_rect().has_point(at) else INF
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and open:
		var b: MouseButton = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_DOWN or b == MOUSE_BUTTON_WHEEL_UP:
			scroll_by(SCROLL_STEP * (1.0 if b == MOUSE_BUTTON_WHEEL_DOWN else -1.0))  # D-106: cuộn lưới món
	if event is InputEventScreenDrag and open and is_finite(_drag_from):
		scroll_by(-(event as InputEventScreenDrag).relative.y)
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_drag_from = INF
	if event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventScreenDrag:
		accept_event()


func _process(_delta: float) -> void:
	if open:
		queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(BUTTON, Color(0.55, 0.4, 0.1, 0.85))
	draw_rect(BUTTON, Color(1, 0.85, 0.4), false, 2.0)
	draw_string(font, BUTTON.position + Vector2(16, 30), "Shop (B)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if not open or world == null or hero == null:
		return
	var p: Rect2 = panel_rect()
	draw_rect(p, Color(0.05, 0.06, 0.09, 0.95))
	draw_rect(p, Color(1, 0.85, 0.4, 0.8), false, 3.0)
	draw_string(font, p.position + Vector2(24, 52), "Cửa hàng", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	draw_string(font, p.position + Vector2(GRID_LEFT, 52), "Vàng: %d" % hero.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.85, 0.3))
	var x: Rect2 = close_rect()
	draw_rect(x, Color(0.5, 0.15, 0.15, 0.9))
	_center(font, x.get_center(), "✕", 28, Color.WHITE)
	for i: int in range(TAB_NAMES.size()):
		var r: Rect2 = tab_rect(i)
		var on: bool = i == tab
		draw_rect(r, Color(0.55, 0.4, 0.12, 0.95) if on else Color(0.14, 0.16, 0.2, 0.9))
		_center(font, r.get_center(), TAB_NAMES[i], 22, Color.WHITE if on else Color(1, 1, 1, 0.7))
	var items: Array[ItemDef] = catalog(tab)
	var view: Rect2 = grid_rect()
	for i: int in range(items.size()):
		var cr: Rect2 = card_rect(i)
		if view.encloses(cr):
			_draw_card(font, cr, items[i])
	if max_scroll() > 0.0:  # thanh cuộn
		var bar: float = view.size.y * view.size.y / (view.size.y + max_scroll())
		var top: float = view.position.y + (view.size.y - bar) * scroll / max_scroll()
		draw_rect(Rect2(Vector2(view.end.x + 2, top), Vector2(6, bar)), Color(1, 1, 1, 0.35))
	draw_string(font, slot_rect(0).position + Vector2(0, -12), "Đồ của bạn", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	for i: int in range(Items.SLOTS):
		var r: Rect2 = slot_rect(i)
		var it: ItemInstance = Items.slots(hero)[i]
		draw_rect(r, Color(0.15, 0.17, 0.22, 0.9))
		if it != null:
			_draw_icon(font, r.get_center() + Vector2(0, -8), 28.0, it.def, true)
			_center(font, r.get_center() + Vector2(0, 32), it.def.display_name, 13, Color(1, 1, 1, 0.8))
		if i == selected_slot:
			draw_rect(r, Color(1, 0.9, 0.4), false, 3.0)
	_draw_detail(font)


func _draw_card(font: Font, r: Rect2, d: ItemDef) -> void:
	var ok: bool = Shop.buy_problem(world, hero, d.id) == Command.Reject.NONE
	draw_rect(r, Color(0.13, 0.15, 0.2, 0.95))
	_draw_icon(font, r.position + Vector2(r.size.x * 0.5, 42), 30.0, d, ok)
	_center(font, r.position + Vector2(r.size.x * 0.5, 88), d.display_name, 13, Color.WHITE if ok else Color(1, 1, 1, 0.45))
	_center(font, r.position + Vector2(r.size.x * 0.5, 112), str(Shop.price(world, hero, d)), 16, Color(1, 0.85, 0.3) if ok else Color(1, 0.85, 0.3, 0.45))
	if d.shop == ItemDef.ShopKind.SECRET:
		_center(font, r.position + Vector2(22, 18), "ẨN", 13, Color(0.7, 0.85, 1))
	var left: int = Shop.stock(world, hero.team, d)
	if left >= 0:  # SHOP-08: còn trong kho đội
		_center(font, r.position + Vector2(r.size.x - 24, 18), "x%d" % left, 15, Color(1, 1, 1, 0.8) if left > 0 else Color(1, 0.5, 0.4))
	if selected_slot < 0 and d.id == selected_id:
		draw_rect(r, Color(1, 0.9, 0.4), false, 3.0)


## Ô hình tạm: tròn màu theo danh mục, chữ tắt (hình thật ở M8).
func _draw_icon(font: Font, c: Vector2, radius: float, d: ItemDef, bright: bool) -> void:
	var col: Color = [Color(0.75, 0.3, 0.25), Color(0.4, 0.35, 0.8), Color(0.3, 0.6, 0.4), Color(0.6, 0.55, 0.3), Color(0.45, 0.47, 0.5)][d.category]
	if not bright:
		col = col.darkened(0.55)
	draw_circle(c, radius, col)
	if d.ability != null and d.ability.targeting != AbilityDef.Targeting.PASSIVE:
		draw_arc(c, radius, 0, TAU, 32, Color(1, 0.85, 0.4, 0.9 if bright else 0.4), 3.0, true)
	_center(font, c, ItemButtons.short_name(d.display_name), int(radius * 0.6), Color(1, 1, 1, 1.0 if bright else 0.5))


func _draw_detail(font: Font) -> void:
	var r: Rect2 = detail_rect()
	draw_rect(r, Color(0.1, 0.12, 0.16, 0.95))
	var d: ItemDef = selected_def()
	if d == null:
		_center(font, r.get_center(), "Chạm một món để xem", 22, Color(1, 1, 1, 0.5))
		return
	var at: Vector2 = r.position + Vector2(24, 0)
	var w: float = r.size.x - 48
	_draw_icon(font, at + Vector2(40, 60), 40.0, d, true)
	draw_string(font, at + Vector2(100, 56), d.display_name, HORIZONTAL_ALIGNMENT_LEFT, w - 100, 28, Color.WHITE)
	draw_string(font, at + Vector2(100, 92), "Giá %d" % d.cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.3))
	var y: float = 140.0
	for line: String in recipe_lines(world, d):  # SHOP-09: ghép từ / ghép thành
		draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, 17, Color(1, 0.85, 0.55))
		y += 26.0
	var tag_line: String = " · ".join(tags(d))
	if not tag_line.is_empty():
		draw_string(font, at + Vector2(0, y), tag_line, HORIZONTAL_ALIGNMENT_LEFT, w, 18, Color(0.7, 0.85, 1))
		y += 34.0
	for line: String in stat_lines(d):
		draw_string(font, at + Vector2(0, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, 20, Color(0.6, 1, 0.6))
		y += 30.0
	y += 10.0
	draw_multiline_string(font, at + Vector2(0, y), d.description, HORIZONTAL_ALIGNMENT_LEFT, w, 19, -1, Color(1, 1, 1, 0.85))
	var b: Rect2 = action_rect()
	var label: String
	var ok: bool = true
	if selected_slot >= 0:
		label = "Bán  +%d" % Shop.refund_for(world, Items.slots(hero)[selected_slot])
	else:
		var problem: Command.Reject = Shop.buy_problem(world, hero, d.id)
		ok = problem == Command.Reject.NONE
		label = "Mua  %d" % Shop.price(world, hero, d) if ok else status_text(world, d, problem, hero.team)
	draw_rect(b, (Color(0.6, 0.25, 0.2) if selected_slot >= 0 else Color(0.2, 0.5, 0.25)) if ok else Color(0.25, 0.25, 0.28))
	_center(font, b.get_center(), label, 26, Color.WHITE if ok else Color(1, 0.6, 0.5))


func _center(font: Font, c: Vector2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, c + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Dòng chỉ số từ modifier của món, vd "+25 Sát thương", "+30% Tốc đánh".
static func stat_lines(d: ItemDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: ModifierDef in d.modifiers:
		var info: Array = STATS.get(m.stat, [String(m.stat), false])
		var v: float = float(m.value)
		var text: String = ("%d%%" % roundi(v * 100.0)) if info[1] else (str(int(v)) if is_equal_approx(v, roundf(v)) else str(v))
		out.append("+%s %s" % [text, info[0]])
	return out


## SHOP-09: "Ghép từ: A + B + phí N" và "Ghép thành: X, Y".
static func recipe_lines(w: World, d: ItemDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not d.components.is_empty():
		var names: PackedStringArray = PackedStringArray()
		var sum: int = 0
		for c: StringName in d.components:
			var part: ItemDef = w.item_catalog.get(c)
			if part != null:
				names.append(part.display_name)
				sum += part.cost
		out.append("Ghép từ: %s + phí %d" % [" + ".join(names), d.cost - sum])
	var into: PackedStringArray = PackedStringArray()
	for o: ItemDef in w.item_catalog.values():
		if o.components.has(d.id):
			into.append(o.display_name)
	into.sort()
	if not into.is_empty():
		out.append("Ghép thành: " + ", ".join(into))
	return out


static func tags(d: ItemDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if d.shop == ItemDef.ShopKind.SECRET:
		out.append("[shop ẩn]")
	if d.unique:
		out.append("[độc nhất]")
	if d.unlock_time > 0.0:
		out.append("[từ %s]" % MatchHud.clock_text(SimClock.seconds_to_ticks(d.unlock_time)))
	return out


static func status_text(w: World, d: ItemDef, problem: Command.Reject, team: int = -1) -> String:
	if problem == Command.Reject.OUT_OF_STOCK and Shop.restock_seconds(w, team, d) >= 0.0:
		return "Hết hàng, còn %d s" % ceili(Shop.restock_seconds(w, team, d))  # SHOP-08
	if problem == Command.Reject.NOT_YET:
		return "Mở sau %s" % MatchHud.clock_text(SimClock.seconds_to_ticks(d.unlock_time) - w.tick)
	return REASONS.get(problem, "Không mua được")
