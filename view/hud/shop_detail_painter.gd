class_name ShopDetailPainter
extends RefCounted
## Khung chi tiết món trong shop (D-130): ảnh lớn + tên + giá, cây ghép (D-115), chỉ số xanh,
## nhãn, phần Chủ động / Bị động có hồi chiêu, mô tả, nút Mua / Thiếu vàng / Bán và Soạn.


static func draw(s: ShopPanel) -> void:
	var r: Rect2 = s.detail_rect()
	s.draw_style_box(UiStyle.box(Color(0.07, 0.1, 0.16, 0.98), UiStyle.LINE, 1, 12), r)
	var d: ItemDef = s.selected_def()
	if d == null:
		UiStyle.text_center(s, UiStyle.serif(), r.get_center(), "Chạm một món để xem", 24, UiStyle.DIM)
		s._tree = []
		return
	var at: Vector2 = r.position + Vector2(24, 20)
	var w: float = r.size.x - 48
	_header(s, d, at, w)
	var tree: Array = RecipeTree.layout(s.world, s.hero, d, at + Vector2(0, 142), w)  # D-115
	s._tree = tree[0]
	RecipeTree.draw(s, UiStyle.serif(), s.world, s._tree, at + Vector2(0, 142))
	var y: float = at.y + 142.0 + tree[1] + 10.0
	UiStyle.divider(s, Vector2(at.x, y), Vector2(at.x + w, y))
	y += 40.0
	for line: String in ShopPanel.stat_lines(d):
		s.draw_string(UiStyle.sans(true), Vector2(at.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, w, 26, UiStyle.GREEN)
		y += 32.0
	var tag_line: String = " · ".join(ShopPanel.tags(d))
	if not tag_line.is_empty():
		s.draw_string(UiStyle.sans(), Vector2(at.x, y), tag_line, HORIZONTAL_ALIGNMENT_LEFT, w, 20, Color(0.65, 0.82, 1))
		y += 30.0
	y = _ability(s, d, Vector2(at.x, y + 6), w)
	if not d.description.is_empty():
		s.draw_multiline_string(UiStyle.sans(), Vector2(at.x, y), d.description, HORIZONTAL_ALIGNMENT_LEFT, w, 22, -1, Color(UiStyle.TEXT, 0.9))
	_buttons(s, d)


static func _header(s: ShopPanel, d: ItemDef, at: Vector2, w: float) -> void:
	var box: Rect2 = Rect2(at, Vector2(110, 110))
	s.draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 2, 10), box)
	ShopPainter.icon(s, box.get_center(), 50.0, d, true)
	s.draw_string(UiStyle.serif(true), at + Vector2(132, 48), d.display_name, HORIZONTAL_ALIGNMENT_LEFT, w - 132, 34, UiStyle.TEXT)
	UiStyle.coin(s, at + Vector2(146, 88), 14.0)
	s.draw_string(UiStyle.sans(true), at + Vector2(168, 99), str(d.cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiStyle.GOLD)
	UiStyle.divider(s, at + Vector2(0, 128), at + Vector2(w, 128))


## "Chủ động · Hồi N giây" hoặc "Bị động" khi món có kỹ năng.
static func _ability(s: ShopPanel, d: ItemDef, at: Vector2, w: float) -> float:
	if d.ability == null:
		return at.y + 8.0
	UiStyle.divider(s, at - Vector2(0, 22), at + Vector2(w, -22))
	var active: bool = d.ability.targeting != AbilityDef.Targeting.PASSIVE
	s.draw_string(UiStyle.serif(true), at + Vector2(0, 6), "Chủ động" if active else "Bị động", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.GOLD)
	var cd: PackedFloat32Array = d.ability.values.get(&"cooldown", PackedFloat32Array())
	if active and not cd.is_empty():
		var x: float = UiStyle.serif(true).get_string_size("Chủ động", HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		s.draw_string(UiStyle.sans(), at + Vector2(x + 10, 5), "· Hồi %s giây" % InfoPanels._num(cd[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.DIM)
	return at.y + 40.0


static func _buttons(s: ShopPanel, d: ItemDef) -> void:
	var b: Rect2 = s.action_rect()
	if s.selected_slot >= 0:
		UiStyle.button(s, b, &"gold", "Bán", "+%d vàng" % Shop.refund_for(s.world, Items.slots(s.hero)[s.selected_slot]), 30)
		return
	var problem: Command.Reject = Shop.buy_problem(s.world, s.hero, d.id)
	var price: int = Shop.price(s.world, s.hero, d)
	if problem == Command.Reject.NONE:
		UiStyle.button(s, b, &"gold", "Mua", "%d vàng" % price, 30)
	elif problem == Command.Reject.NOT_ENOUGH_GOLD:
		UiStyle.button(s, b, &"red", "Thiếu vàng", "Cần thêm %d vàng" % (price - s.hero.gold), 28)
	else:
		UiStyle.button(s, b, &"red", ShopPanel.status_text(s.world, d, problem, s.hero.team), "", 24)
	var cr: Rect2 = s.compose_rect()
	var has: bool = s.build.has(d.id)
	var label: String = "Bỏ soạn" if has else ("Soạn +" if s.build.size() < ShopPanel.BUILD_MAX else "Đủ 6")
	s.draw_style_box(UiStyle.box(UiStyle.BLUE_BTN, UiStyle.BLUE_EDGE, 2, 10), cr)
	UiStyle.glyph(s, &"cart", cr.position + Vector2(36, cr.size.y * 0.5), 15.0, UiStyle.TEXT)
	s.draw_string(UiStyle.serif(true), cr.position + Vector2(64, cr.size.y * 0.5 + 10), label, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x - 70, 26, UiStyle.TEXT)
