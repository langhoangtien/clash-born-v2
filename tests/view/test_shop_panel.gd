extends TestCase
## M6.5b: bảng shop tạm — dòng món theo giá, nhãn, lý do, chạm để mua / bán (D-81).


func test_SHOP_panel_rows_tags_and_signals() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = load("res://data/maps/clashborn.tres") as MapLayout
	MatchSetup.add_shop(w, lib)
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(1000, 1000))
	var p: ShopPanel = ShopPanel.new()
	p.size = Vector2(1920, 1080)
	p.world = w
	p.hero = hero
	var items: Array[ItemDef] = p.catalog()
	assert_eq(items[0].id, &"reveal_dust", "rẻ nhất trước")
	var bought: Array[StringName] = []
	p.buy_pressed.connect(func(id: StringName) -> void: bought.append(id))
	p.press_at(p.row_rect(0).get_center())
	assert_eq(bought.size(), 0, "đóng thì không mua")
	p.press_at(ShopPanel.BUTTON.get_center())
	assert_true(p.open)
	p.press_at(p.row_rect(0).get_center())
	assert_eq(bought, [&"reveal_dust"])
	var late: ItemDef = ItemDef.new()
	late.shop = ItemDef.ShopKind.SECRET
	late.unique = true
	late.unlock_time = 1200.0
	assert_eq(ShopPanel.tags(late), PackedStringArray(["[shop ẩn]", "[độc nhất]", "[từ 20:00]"]))
	assert_eq(ShopPanel.status_text(w, late, Command.Reject.NOT_YET), "Mở sau 20:00")
	p.free()
