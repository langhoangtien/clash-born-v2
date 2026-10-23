class_name ShopPainter
extends RefCounted
## Vẽ bảng cửa hàng (D-130) theo UiStyle: đầu bảng (giỏ hàng, vàng, đóng), thẻ danh mục có icon,
## lưới thẻ món, hàng Soạn sẵn, 6 ô đồ, khung chi tiết (ảnh lớn, giá, cây ghép, chỉ số, chủ động,
## nút Mua / Thiếu vàng / Soạn). ShopPanel giữ bố cục và xử lý chạm.

const TAB_GLYPHS: Array[StringName] = [&"cat_all", &"cat_basic", &"cat_attack", &"cat_magic", &"cat_defense", &"cat_utility", &"cat_secret"]


static func draw(s: ShopPanel) -> void:
	if not s.open or s.world == null or s.hero == null:
		UiStyle.button(s, ShopPanel.BUTTON, &"gold", "Shop (B)", "", 20)
		return
	var p: Rect2 = s.panel_rect()
	s.draw_rect(Rect2(Vector2.ZERO, s.size), Color(0, 0, 0, 0.6))  # làm tối trận phía sau
	UiStyle.panel(s, p)
	_header(s, p)
	for i: int in range(ShopPanel.TAB_NAMES.size()):
		_tab(s, i)
	var items: Array[ItemDef] = s.catalog(s.tab)
	var view: Rect2 = s.grid_rect()
	for i: int in range(items.size()):
		var cr: Rect2 = s.card_rect(i)
		if view.encloses(cr):
			_card(s, cr, items[i])
	if s.max_scroll() > 0.0:
		var bar: float = view.size.y * view.size.y / (view.size.y + s.max_scroll())
		var top: float = view.position.y + (view.size.y - bar) * s.scroll / s.max_scroll()
		s.draw_style_box(UiStyle.box(Color(1, 1, 1, 0.25), Color(0, 0, 0, 0), 0, 3), Rect2(Vector2(view.end.x + 4, top), Vector2(6, bar)))
	_slots(s)
	_build(s)
	ShopDetailPainter.draw(s)


static func _header(s: ShopPanel, p: Rect2) -> void:
	UiStyle.glyph(s, &"cart", p.position + Vector2(48, 44), 20.0, UiStyle.GOLD)
	s.draw_string(UiStyle.serif(true), p.position + Vector2(84, 58), "Cửa hàng", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UiStyle.TEXT)
	UiStyle.divider(s, p.position + Vector2(286, 22), p.position + Vector2(286, 66))
	UiStyle.coin(s, p.position + Vector2(326, 44), 17.0)
	s.draw_string(UiStyle.sans(true), p.position + Vector2(352, 57), str(s.hero.gold), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiStyle.GOLD)
	var x: Rect2 = s.close_rect()
	UiStyle.divider(s, Vector2(x.position.x - 16, x.position.y), Vector2(x.position.x - 16, x.end.y))
	UiStyle.glyph(s, &"close", x.get_center(), 18.0, UiStyle.TEXT)
	UiStyle.divider(s, p.position + Vector2(0, 86), p.position + Vector2(p.size.x, 86))


static func _tab(s: ShopPanel, i: int) -> void:
	var r: Rect2 = s.tab_rect(i)
	var on: bool = i == s.tab
	if on:
		s.draw_style_box(UiStyle.box(Color(0.5, 0.37, 0.14, 0.95), UiStyle.GOLD, 2, 10, Color(UiStyle.GOLD, 0.2), 8), r)
	var col: Color = Color(1, 0.95, 0.85) if on else UiStyle.DIM
	UiStyle.glyph(s, TAB_GLYPHS[i], r.position + Vector2(34, r.size.y * 0.5), 13.0, col)
	s.draw_string(UiStyle.serif(on), r.position + Vector2(64, r.size.y * 0.5 + 9), ShopPanel.TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)


static func _card(s: ShopPanel, r: Rect2, d: ItemDef) -> void:
	var ok: bool = Shop.buy_problem(s.world, s.hero, d.id) == Command.Reject.NONE
	UiStyle.card(s, r, s.selected_slot < 0 and d.id == s.selected_id, not ok)
	icon(s, Vector2(r.get_center().x, r.position.y + 70), 58.0, d, ok)
	UiStyle.text_center(s, UiStyle.serif(), Vector2(r.get_center().x, r.end.y - 44), d.display_name, 19, UiStyle.TEXT if ok else Color(UiStyle.TEXT, 0.55))
	UiStyle.text_center(s, UiStyle.sans(true), Vector2(r.get_center().x, r.end.y - 17), str(Shop.price(s.world, s.hero, d)), 22, UiStyle.GOLD if ok else Color(UiStyle.GOLD, 0.5))
	if d.shop == ItemDef.ShopKind.SECRET:
		s.draw_string(UiStyle.sans(true), r.position + Vector2(10, 22), "ẨN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.65, 0.82, 1))
	var left: int = Shop.stock(s.world, s.hero.team, d)
	if left >= 0:  # SHOP-08: còn trong kho đội
		s.draw_string(UiStyle.sans(true), r.position + Vector2(r.size.x - 34, 24), "x%d" % left, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiStyle.TEXT if left > 0 else UiStyle.RED_TEXT)


static func _slots(s: ShopPanel) -> void:
	for i: int in range(Items.SLOTS):
		var r: Rect2 = s.slot_rect(i)
		var it: ItemInstance = Items.slots(s.hero)[i]
		UiStyle.card(s, r, i == s.selected_slot)
		if it != null:
			icon(s, r.get_center(), r.size.y * 0.38, it.def, true)
		else:
			UiStyle.text_center(s, UiStyle.sans(), r.get_center(), "+", 40, Color(UiStyle.DIM, 0.5))


static func _build(s: ShopPanel) -> void:
	s.draw_string(UiStyle.serif(), s.build_rect(0).position + Vector2(0, -14), "Soạn sẵn", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiStyle.TEXT)
	for i: int in range(ShopPanel.BUILD_MAX):
		var r: Rect2 = s.build_rect(i)
		UiStyle.card(s, r)
		if i < s.build.size() and s.world.item_catalog.has(s.build[i]):
			icon(s, r.get_center(), r.size.x * 0.42, s.world.item_catalog[s.build[i]], true)


## Ảnh món (ô vuông bo); chưa có ảnh thì ô màu theo danh mục + chữ tắt.
static func icon(s: CanvasItem, c: Vector2, half: float, d: ItemDef, bright: bool) -> void:
	var tex: Texture2D = ArtLibrary.texture(d.art_id)
	var rect: Rect2 = Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	if tex != null:
		s.draw_texture_rect(tex, rect, false, Color.WHITE if bright else Color(0.62, 0.62, 0.66))  # D-129
		return
	var col: Color = [Color(0.75, 0.3, 0.25), Color(0.4, 0.35, 0.8), Color(0.3, 0.6, 0.4), Color(0.6, 0.55, 0.3), Color(0.45, 0.47, 0.5)][d.category]
	s.draw_style_box(UiStyle.box(col if bright else col.darkened(0.5), UiStyle.LINE, 1, 8), rect)
	UiStyle.text_center(s, UiStyle.sans(true), c, ItemButtons.short_name(d.display_name), int(half * 0.6), Color(1, 1, 1, 1.0 if bright else 0.5))
