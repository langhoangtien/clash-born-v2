class_name ShopPanel
extends Control
## Cửa hàng kiểu Liên Quân (M6.6, D-90; giao diện D-130 vẽ ở ShopPainter). Nút "Shop" dưới ô máu/mana hoặc phím B
## mở/đóng. Trái: thẻ danh mục. Giữa: lưới món (mờ khi chưa mua được). Phải: chi tiết món đang
## chọn — giá, nhãn, chỉ số, mô tả, nút Mua (hoặc Bán khi chọn đồ đang có). Dưới: 6 ô đồ của hero.
## Chỉ đọc World và báo bằng tín hiệu.

const BUTTON: Rect2 = Rect2(292, 160, 120, 44)
const PANEL_SIZE: Vector2 = Vector2(1840, 1030)
const TAB_SIZE: Vector2 = Vector2(214, 60)
const CARD_SIZE: Vector2 = Vector2(176, 186)
const CARD_GAP: float = 14.0
const COLUMNS: int = 5
## Vùng lưới món (cuộn dọc khi nhiều món): từ y = GRID_TOP tới trên hàng ô đồ.
const GRID_TOP: float = 104.0
const GRID_BOTTOM_GAP: float = 150.0
const SCROLL_STEP: float = 200.0
const GRID_LEFT: float = 250.0
const DETAIL_LEFT: float = 1218.0
const SLOT_SIZE: Vector2 = Vector2(130, 110)

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
## D-120: bộ đồ soạn sẵn đổi (thêm / bỏ món).
signal build_changed(build: Array[StringName])

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
## D-115: các nút của cây ghép đồ đang vẽ (để bắt chạm).
var _tree: Array = []
## D-120: bộ đồ soạn sẵn (tối đa BUILD_MAX món, theo thứ tự mua).
var build: Array[StringName] = []
const BUILD_SLOT: float = 64.0
const BUILD_MAX: int = 6


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
	return Rect2(panel_rect().position + Vector2(14, 102 + i * (TAB_SIZE.y + 8)), TAB_SIZE)


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
	return Rect2(p.position + Vector2(GRID_LEFT + 20 + i * (SLOT_SIZE.x + 14), p.size.y - SLOT_SIZE.y - 22), SLOT_SIZE)


func detail_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(DETAIL_LEFT, 104), Vector2(p.size.x - DETAIL_LEFT - 22, p.size.y - 126))


func action_rect() -> Rect2:
	var d: Rect2 = detail_rect()
	var full: Rect2 = Rect2(d.position + Vector2(20, d.size.y - 104), Vector2(d.size.x - 40, 86))
	if selected_slot >= 0:
		return full
	return Rect2(full.position, Vector2(full.size.x * 0.6 - 6, full.size.y))


## D-120: nút "Soạn" cạnh nút Mua (chỉ khi xem món của cửa hàng).
func compose_rect() -> Rect2:
	var a: Rect2 = action_rect()
	var d: Rect2 = detail_rect()
	return Rect2(Vector2(a.end.x + 12, a.position.y), Vector2(d.end.x - 24 - a.end.x - 12, a.size.y))


## D-120: ô thứ `i` của hàng "Soạn sẵn" (cột trái, dưới các thẻ), 3 cột × 2 hàng.
func build_rect(i: int) -> Rect2:
	var top: Vector2 = panel_rect().position + Vector2(18, 102 + TAB_NAMES.size() * (TAB_SIZE.y + 8) + 52)
	return Rect2(top + Vector2((i % 3) * (BUILD_SLOT + 8), (i / 3) * (BUILD_SLOT + 8)), Vector2(BUILD_SLOT, BUILD_SLOT))


## D-120: thêm món vào bộ soạn sẵn, hoặc bỏ nếu đã có. Đầy thì không thêm.
func toggle_build(id: StringName) -> void:
	if build.has(id):
		build.erase(id)
	elif build.size() < BUILD_MAX:
		build.append(id)
	else:
		return
	build_changed.emit(build)


func close_rect() -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(p.size.x - 72, 18), Vector2(52, 52))


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
	return open or BUTTON.has_point(point)  # D-130: mở thì chặn cả màn (bảng che gần hết màn)


func press_at(local: Vector2) -> void:
	if (not open and BUTTON.has_point(local)) or (open and close_rect().has_point(local)):
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
	var node: RecipeTree.TreeNode = RecipeTree.node_at(_tree, local) if selected_def() != null else null
	if node != null:  # D-115: chạm ô trên cây ghép → xem món đó
		selected_id = node.def.id
		selected_slot = -1
		return
	for i: int in range(build.size()):
		if build_rect(i).has_point(local):  # D-120: chạm ô soạn sẵn → bỏ món đó
			toggle_build(build[i])
			return
	if selected_slot < 0 and selected_def() != null and compose_rect().has_point(local):
		toggle_build(selected_def().id)
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
	ShopPainter.draw(self)  # D-130


## Dòng chỉ số từ modifier của món, vd "+25 Sát thương", "+30% Tốc đánh".
static func stat_lines(d: ItemDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: ModifierDef in d.modifiers:
		var info: Array = STATS.get(m.stat, [String(m.stat), false])
		var v: float = float(m.value)
		var text: String = ("%d%%" % roundi(v * 100.0)) if info[1] else (str(int(v)) if is_equal_approx(v, roundf(v)) else str(v))
		out.append("+%s %s" % [text, info[0]])
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
