extends TestCase
## M6.6: cửa hàng kiểu Liên Quân — thẻ danh mục, lưới món, chi tiết, Mua / Bán (D-90, SHOP-07).

const T := ShopPanel.Tab


func _panel() -> ShopPanel:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = load("res://data/maps/clashborn.tres") as MapLayout
	MatchSetup.add_shop(w, lib)
	var p: ShopPanel = ShopPanel.new()
	p.size = Vector2(1920, 1080)
	p.world = w
	p.hero = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, w.map.world_size() * 0.5)
	p.hero.gold = 5000
	return p


func _ids(items: Array[ItemDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: ItemDef in items:
		out.append(d.id)
	return out


func test_SHOP_07_tabs_filter_catalog() -> void:
	var p: ShopPanel = _panel()
	assert_eq(p.catalog(T.ALL).size(), 9)
	assert_eq(p.catalog(T.ALL)[0].id, &"reveal_dust", "rẻ nhất trước")
	assert_eq(_ids(p.catalog(T.ATTACK)), [&"shadow_blade", &"stun_hammer"])
	assert_eq(_ids(p.catalog(T.MAGIC)), [&"ghost_scepter", &"cyclone_staff", &"hex_scythe"])
	assert_eq(_ids(p.catalog(T.DEFENSE)), [&"cleansing_charm", &"frost_orb", &"resolute_armor"])
	assert_eq(_ids(p.catalog(T.UTILITY)), [&"reveal_dust"])
	assert_eq(_ids(p.catalog(T.SECRET)), [&"frost_orb", &"resolute_armor"])
	p.free()


func test_D_90_select_shows_detail_then_buy_and_sell() -> void:
	var p: ShopPanel = _panel()
	var bought: Array[StringName] = []
	var sold: Array[int] = []
	p.buy_pressed.connect(func(id: StringName) -> void: bought.append(id))
	p.sell_pressed.connect(func(i: int) -> void: sold.append(i))
	p.press_at(p.card_rect(0).get_center())
	assert_eq(p.selected_id, &"", "đóng thì không chọn")
	p.press_at(ShopPanel.BUTTON.get_center())
	p.press_at(p.tab_rect(T.ATTACK).get_center())
	assert_eq(p.tab, T.ATTACK)
	p.press_at(p.card_rect(1).get_center())
	assert_eq(p.selected_def().id, &"stun_hammer", "chạm thẻ thì xem chi tiết, chưa mua")
	assert_eq(bought.size(), 0)
	p.press_at(p.action_rect().get_center())
	assert_eq(bought, [&"stun_hammer"], "nút Mua")
	p.press_at(p.tab_rect(T.MAGIC).get_center())
	p.press_at(p.card_rect(2).get_center())
	p.press_at(p.action_rect().get_center())
	assert_eq(bought.size(), 1, "Lưỡi Hái chưa mở (phút 15): nút Mua không báo")
	Items.give(p.world, p.hero, p.world.item_catalog[&"ghost_scepter"])
	p.press_at(p.slot_rect(0).get_center())
	assert_eq(p.selected_def().id, &"ghost_scepter", "chạm ô đồ thì xem đồ của mình")
	p.press_at(p.action_rect().get_center())
	assert_eq(sold, [0], "nút Bán")
	assert_eq(p.selected_slot, -1)
	p.press_at(p.close_rect().get_center())
	assert_false(p.open, "nút đóng")
	p.free()


func test_D_90_stat_lines_tags_status() -> void:
	var p: ShopPanel = _panel()
	assert_eq(ShopPanel.stat_lines(p.world.item_catalog[&"shadow_blade"]), PackedStringArray(["+25 Sát thương", "+30% Tốc đánh"]))
	assert_eq(ShopPanel.stat_lines(p.world.item_catalog[&"cyclone_staff"]), PackedStringArray(["+10 Trí tuệ", "+2.5 Hồi mana"]))
	var late: ItemDef = ItemDef.new()
	late.shop = ItemDef.ShopKind.SECRET
	late.unique = true
	late.unlock_time = 1200.0
	assert_eq(ShopPanel.tags(late), PackedStringArray(["[shop ẩn]", "[độc nhất]", "[từ 20:00]"]))
	assert_eq(ShopPanel.status_text(p.world, late, Command.Reject.NOT_YET), "Mở sau 20:00")
	p.free()
