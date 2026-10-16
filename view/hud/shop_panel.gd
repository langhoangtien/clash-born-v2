class_name ShopPanel
extends Control
## Bảng shop tạm (M6.5b, D-81; bảng đẹp ở M8). Nút "Shop" dưới ô máu/mana hoặc phím B mở/đóng.
## Mỗi dòng một món: tên, giá, nhãn (ẩn / độc nhất / mở lúc…), trạng thái mua được hay lý do.
## Hàng dưới: 6 ô đồ của hero, chạm để bán. Chỉ đọc World và báo bằng tín hiệu.

const BUTTON: Rect2 = Rect2(292, 160, 120, 44)
const PANEL_SIZE: Vector2 = Vector2(980, 780)
const ROW: float = 48.0
const REASONS: Dictionary = {
	Command.Reject.NOT_ENOUGH_GOLD: "Thiếu vàng",
	Command.Reject.INVENTORY_FULL: "Hết ô",
	Command.Reject.NOT_IN_SHOP: "Tới shop ẩn S1 / S1'",
	Command.Reject.NOT_YET: "Chưa mở",
	Command.Reject.SOLD_OUT: "Đã có người mua",
}

signal buy_pressed(item_id: StringName)
signal sell_pressed(index: int)

var world: World
var hero: Entity
var open: bool = false


func panel_rect() -> Rect2:
	return Rect2((size - PANEL_SIZE) * 0.5, PANEL_SIZE)


## Món trong cửa hàng theo giá tăng dần, rồi id.
func catalog() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for d: ItemDef in world.item_catalog.values():
		out.append(d)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.cost < b.cost or (a.cost == b.cost and String(a.id) < String(b.id)))
	return out


func row_rect(i: int) -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(20, 70 + i * ROW), Vector2(p.size.x - 40, ROW - 6))


func sell_rect(i: int) -> Rect2:
	var p: Rect2 = panel_rect()
	return Rect2(p.position + Vector2(20 + i * 156, p.size.y - 84), Vector2(146, 64))


func toggle() -> void:
	open = not open
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return BUTTON.has_point(point) or (open and panel_rect().has_point(point))


func press_at(local: Vector2) -> void:
	if BUTTON.has_point(local):
		toggle()
		return
	if not open:
		return
	var items: Array[ItemDef] = catalog()
	for i: int in range(items.size()):
		if row_rect(i).has_point(local):
			buy_pressed.emit(items[i].id)
			return
	for i: int in range(Items.SLOTS):
		if sell_rect(i).has_point(local) and Items.slots(hero)[i] != null:
			sell_pressed.emit(i)
			return


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		press_at((event as InputEventScreenTouch).position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press_at((event as InputEventMouseButton).position)
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
	draw_rect(p, Color(0.05, 0.06, 0.09, 0.92))
	draw_rect(p, Color(1, 0.85, 0.4, 0.8), false, 3.0)
	draw_string(font, p.position + Vector2(20, 44), "Cửa hàng — vàng: %d" % hero.gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.85, 0.3))
	var items: Array[ItemDef] = catalog()
	for i: int in range(items.size()):
		_draw_row(font, row_rect(i), items[i])
	draw_string(font, p.position + Vector2(20, p.size.y - 96), "Đồ của bạn (chạm để bán):", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	for i: int in range(Items.SLOTS):
		var r: Rect2 = sell_rect(i)
		var it: ItemInstance = Items.slots(hero)[i]
		draw_rect(r, Color(0.15, 0.17, 0.22, 0.9))
		if it != null:
			draw_string(font, r.position + Vector2(8, 26), it.def.display_name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 16, Color.WHITE)
			draw_string(font, r.position + Vector2(8, 52), "Bán", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.6, 0.5))


func _draw_row(font: Font, r: Rect2, d: ItemDef) -> void:
	var problem: Command.Reject = Shop.buy_problem(world, hero, d.id)
	var ok: bool = problem == Command.Reject.NONE
	draw_rect(r, Color(0.2, 0.35, 0.25, 0.85) if ok else Color(0.18, 0.18, 0.2, 0.85))
	draw_string(font, r.position + Vector2(12, 30), d.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE if ok else Color(1, 1, 1, 0.5))
	draw_string(font, r.position + Vector2(330, 30), str(d.cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.3))
	draw_string(font, r.position + Vector2(430, 30), " ".join(tags(d)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.85, 1))
	var status: String = "Mua" if ok else status_text(world, d, problem)
	draw_string(font, r.position + Vector2(r.size.x - 260, 30), status, HORIZONTAL_ALIGNMENT_LEFT, 250, 20, Color(0.6, 1, 0.6) if ok else Color(1, 0.6, 0.5))


static func tags(d: ItemDef) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if d.shop == ItemDef.ShopKind.SECRET:
		out.append("[shop ẩn]")
	if d.unique:
		out.append("[độc nhất]")
	if d.unlock_time > 0.0:
		out.append("[từ %s]" % MatchHud.clock_text(SimClock.seconds_to_ticks(d.unlock_time)))
	return out


static func status_text(w: World, d: ItemDef, problem: Command.Reject) -> String:
	if problem == Command.Reject.NOT_YET:
		return "Mở sau %s" % MatchHud.clock_text(SimClock.seconds_to_ticks(d.unlock_time) - w.tick)
	return REASONS.get(problem, "Không mua được")
