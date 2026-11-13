class_name ItemsDetail
extends RefCounted
## D-413: bảng chi tiết món ở trang Trang bị (chỉ đọc ItemDef): ảnh + tên + giá, chỉ số (ShopPanel.stat_lines), nhãn (shop
## ẩn / độc nhất / mở bán từ), Chủ động / Bị động + hồi chiêu, mô tả, công thức ghép (thành phần + phí ghép — SHOP-09) và
## các món ghép từ món này.

const ICON: float = 46.0


static func draw(c: CanvasItem, d: ItemDef, r: Rect2, library: Dictionary[StringName, ItemDef]) -> void:
	if d == null:
		UiStyle.text_center(c, UiStyle.serif(), r.get_center(), "Chạm một món để xem", 26, UiStyle.DIM)
		return
	var at: Vector2 = r.position + Vector2(28, 28)
	var w: float = r.size.x - 56
	var box: Rect2 = Rect2(at, Vector2(110, 110))
	c.draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 2, 10), box)
	ShopPainter.icon(c, box.get_center(), 50.0, d, true)
	c.draw_string(UiStyle.serif(true), at + Vector2(132, 46), d.display_name, HORIZONTAL_ALIGNMENT_LEFT, w - 132, 34, UiStyle.TEXT)
	UiStyle.coin(c, at + Vector2(146, 88), 14.0)
	c.draw_string(UiStyle.sans(true), at + Vector2(168, 99), "%d vàng" % d.cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.GOLD)
	var y: float = at.y + 150.0
	y = _lines(c, "Chỉ số", ShopPanel.stat_lines(d), Vector2(at.x, y), w, UiStyle.GREEN)
	var tag_line: String = " · ".join(ShopPanel.tags(d))
	if tag_line != "":
		c.draw_string(UiStyle.sans(), Vector2(at.x, y), tag_line, HORIZONTAL_ALIGNMENT_LEFT, w, 20, Color(0.65, 0.82, 1))
		y += 34.0
	y = _effect(c, d, Vector2(at.x, y), w)
	y = _recipe(c, d, Vector2(at.x, y), w, library)
	_builds_into(c, d, Vector2(at.x, y), w, library)


## Tiêu đề phần + các dòng; trả y kế tiếp.
static func _lines(c: CanvasItem, title: String, lines: PackedStringArray, at: Vector2, w: float, col: Color) -> float:
	if lines.is_empty():
		return at.y
	c.draw_string(UiStyle.serif(true), at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.GOLD)
	var y: float = at.y + 34.0
	for line: String in lines:
		c.draw_string(UiStyle.sans(true), Vector2(at.x + 8, y), line, HORIZONTAL_ALIGNMENT_LEFT, w - 8, 23, col)
		y += 30.0
	return y + 8.0


## "Chủ động · Hồi N giây" / "Bị động" + mô tả.
static func _effect(c: CanvasItem, d: ItemDef, at: Vector2, w: float) -> float:
	var y: float = at.y
	if d.ability != null:
		var active: bool = d.ability.targeting != AbilityDef.Targeting.PASSIVE
		var cd: PackedFloat32Array = d.ability.values.get(&"cooldown", PackedFloat32Array())
		var head: String = ("Chủ động" if active else "Bị động") + (" · Hồi %s giây" % InfoPanels.num(cd[0]) if active and not cd.is_empty() else "")
		c.draw_string(UiStyle.serif(true), Vector2(at.x, y), "Hiệu ứng — " + head, HORIZONTAL_ALIGNMENT_LEFT, w, 26, UiStyle.GOLD)
		y += 30.0
	if d.description != "":
		var font: Font = UiStyle.sans()
		var lines: int = mini(5, ceili(font.get_multiline_string_size(d.description, HORIZONTAL_ALIGNMENT_LEFT, w, 21).y / 28.0))
		c.draw_multiline_string(font, Vector2(at.x, y + 4), d.description, HORIZONTAL_ALIGNMENT_LEFT, w, 21, 5, Color(UiStyle.TEXT, 0.9))
		y += lines * 28.0 + 14.0
	return y


## SHOP-09: thành phần (ảnh + giá) và phí ghép = giá món − tổng thành phần.
static func _recipe(c: CanvasItem, d: ItemDef, at: Vector2, w: float, library: Dictionary[StringName, ItemDef]) -> float:
	if d.components.is_empty():
		return at.y
	c.draw_string(UiStyle.serif(true), at, "Công thức", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.GOLD)
	var x: float = at.x
	var parts: int = 0
	for id: StringName in d.components:
		var part: ItemDef = library.get(id)
		if part == null:
			continue
		_chip(c, Vector2(x, at.y + 18), part)
		parts += part.cost
		x += ICON * 2 + 30
	var fee: int = d.cost - parts
	if fee > 0:
		c.draw_string(UiStyle.sans(true), Vector2(x, at.y + 70), "+ %d phí ghép" % fee, HORIZONTAL_ALIGNMENT_LEFT, w - (x - at.x), 20, UiStyle.DIM)
	return at.y + 18 + ICON * 2 + 46


## Món dùng món này làm thành phần.
static func _builds_into(c: CanvasItem, d: ItemDef, at: Vector2, w: float, library: Dictionary[StringName, ItemDef]) -> void:
	var into: PackedStringArray = []
	for other: ItemDef in library.values():
		if other.components.has(d.id):
			into.append(other.display_name)
	if into.is_empty():
		return
	into.sort()
	c.draw_string(UiStyle.serif(true), at, "Ghép thành", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.GOLD)
	c.draw_multiline_string(UiStyle.sans(), at + Vector2(8, 32), " · ".join(into), HORIZONTAL_ALIGNMENT_LEFT, w - 8, 21, 3, UiStyle.TEXT)


static func _chip(c: CanvasItem, at: Vector2, part: ItemDef) -> void:
	var box: Rect2 = Rect2(at, Vector2(ICON * 2, ICON * 2))
	c.draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 1, 8), box)
	ShopPainter.icon(c, box.get_center(), ICON - 4, part, true)
	UiStyle.text_center(c, UiStyle.sans(true), Vector2(box.get_center().x, box.end.y + 16), str(part.cost), 18, UiStyle.GOLD)
