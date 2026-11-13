class_name ItemsPage
extends Control
## D-413: trang Trang bị — thư viện đồ chỉ đọc từ `content/items` (ContentLibrary): trái danh mục (đúng như cửa hàng trong
## trận — ShopPanel.TAB_NAMES: theo ItemDef.Category, cộng Shop ẩn), giữa ô tìm + lưới icon (cuộn bằng vuốt / lăn chuột),
## phải bảng chi tiết (ItemsDetail: giá, chỉ số, nhãn, chủ động / bị động, mô tả, công thức ghép, ghép thành).

const LEFT_W: float = 300.0
const DETAIL_W: float = 620.0
const PAD: float = 32.0
const CELL: Vector2 = Vector2(128, 156)
const GAP: float = 12.0
const SEARCH_H: float = 64.0
const SCROLL_STEP: float = 160.0

var items: Array[ItemDef] = []
var library: Dictionary[StringName, ItemDef] = {}
var tab: int = ShopPanel.Tab.ALL
var query: String = ""
var selected: ItemDef
var scroll: float = 0.0
var search: LineEdit
var _dragging: bool = false


func setup(lib: ContentLibrary) -> void:
	library = lib.items
	items.assign(lib.items.values())
	items.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.cost < b.cost or (a.cost == b.cost and String(a.id) < String(b.id)))
	mouse_filter = Control.MOUSE_FILTER_STOP
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Tìm trang bị…"
	search.add_theme_font_size_override("font_size", 26)
	search.text_changed.connect(func(t: String) -> void:
		query = t.strip_edges().to_lower()
		scroll = 0.0
		queue_redraw())
	add_child(search)
	resized.connect(_layout)


## Món đang hiện theo danh mục + ô tìm (giá tăng dần).
func shown() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for d: ItemDef in items:
		var in_tab: bool = tab == ShopPanel.Tab.ALL or (tab == ShopPanel.Tab.SECRET and d.shop == ItemDef.ShopKind.SECRET) \
			or ShopPanel.CATEGORY_TAB.get(d.category, -1) == tab
		if in_tab and (query == "" or d.display_name.to_lower().contains(query)):
			out.append(d)
	return out


func tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(PAD, 84 + i * 76), Vector2(LEFT_W - 24, 64))


func grid_rect() -> Rect2:
	var x: float = PAD + LEFT_W + 12
	return Rect2(Vector2(x, 24 + SEARCH_H + 16), Vector2(size.x - x - DETAIL_W - PAD - 24, size.y - SEARCH_H - 40 - PAD))


func detail_rect() -> Rect2:
	return Rect2(Vector2(size.x - DETAIL_W - PAD, 24), Vector2(DETAIL_W, size.y - 24 - PAD))


func columns() -> int:
	return maxi(1, int((grid_rect().size.x + GAP) / (CELL.x + GAP)))


func cell_rect(k: int) -> Rect2:
	var g: Rect2 = grid_rect()
	return Rect2(g.position + Vector2((k % columns()) * (CELL.x + GAP), (k / columns()) * (CELL.y + GAP) - scroll), CELL)


func max_scroll() -> float:
	var rows: int = ceili(shown().size() / float(columns()))
	return maxf(0.0, rows * (CELL.y + GAP) - grid_rect().size.y)


func scroll_by(px: float) -> void:
	scroll = clampf(scroll + px, 0.0, max_scroll())
	queue_redraw()


func _layout() -> void:
	var g: Rect2 = grid_rect()
	search.position = Vector2(g.position.x, 24)
	search.size = Vector2(g.size.x, SEARCH_H)


func press_at(at: Vector2) -> void:
	for i: int in ShopPanel.TAB_NAMES.size():
		if tab_rect(i).has_point(at):
			tab = i
			scroll = 0.0
	var list: Array[ItemDef] = shown()
	for k: int in list.size():
		if grid_rect().has_point(at) and cell_rect(k).has_point(at):
			selected = list[k]
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and grid_rect().has_point((event as InputEventScreenDrag).position):
		_dragging = true
		scroll_by(-(event as InputEventScreenDrag).relative.y)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: MouseButton = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(-SCROLL_STEP if b == MOUSE_BUTTON_WHEEL_UP else SCROLL_STEP)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_dragging = false
	var at: Vector2 = Taps.press_position(event)  # D-102
	if at.is_finite() and not _dragging:
		press_at(at)
	accept_event()


func _draw() -> void:
	UiStyle.panel(self, Rect2(Vector2(PAD - 12, 24), Vector2(LEFT_W, size.y - 24 - PAD)))
	draw_string(UiStyle.serif(true), Vector2(PAD, 66), "Thư viện trang bị", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.GOLD)
	for i: int in ShopPanel.TAB_NAMES.size():
		UiStyle.button(self, tab_rect(i), &"gold" if i == tab else &"ghost", ShopPanel.TAB_NAMES[i], "", 26)
	var g: Rect2 = grid_rect()
	var list: Array[ItemDef] = shown()
	for k: int in list.size():
		var r: Rect2 = cell_rect(k)
		if r.end.y >= g.position.y and r.position.y <= g.end.y:
			_cell(r, list[k])
	if list.is_empty():
		UiStyle.text_center(self, UiStyle.serif(), g.get_center(), "Không có món nào", 26, UiStyle.DIM)
	UiStyle.panel(self, detail_rect())
	ItemsDetail.draw(self, selected, detail_rect(), library)


func _cell(r: Rect2, d: ItemDef) -> void:
	var g: Rect2 = grid_rect()
	if r.position.y < g.position.y or r.end.y > g.end.y:  # nửa ô ở mép: chỉ khung mờ (không vẽ tràn ra ngoài lưới)
		draw_style_box(UiStyle.box(Color(UiStyle.CARD, 0.4), Color(UiStyle.LINE, 0.3), 1, 10), r.intersection(g))
		return
	UiStyle.card(self, r, d == selected)
	ShopPainter.icon(self, r.position + Vector2(r.size.x * 0.5, 58), 46.0, d, true)
	UiStyle.text_center(self, UiStyle.sans(true), Vector2(r.get_center().x, r.end.y - 34), d.display_name, 16, UiStyle.TEXT)
	UiStyle.coin(self, Vector2(r.get_center().x - 26, r.end.y - 14), 7.0)
	draw_string(UiStyle.sans(true), Vector2(r.get_center().x - 14, r.end.y - 7), str(d.cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiStyle.GOLD)
