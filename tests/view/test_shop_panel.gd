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
	assert_eq(p.catalog(T.ALL).size(), p.world.item_catalog.size())
	assert_eq(p.catalog(T.ALL)[0].id, &"iron_branch", "rẻ nhất trước")
	var attack: Array[StringName] = _ids(p.catalog(T.ATTACK))
	assert_true(attack.has(&"shadow_blade") and attack.has(&"stun_hammer") and attack.has(&"battle_axe"))
	assert_false(attack.has(&"broadsword"), "món cơ bản ở thẻ Cơ bản")
	assert_true(_ids(p.catalog(T.BASIC)).has(&"broadsword"))
	assert_true(_ids(p.catalog(T.MAGIC)).has(&"hex_scythe"))
	assert_true(_ids(p.catalog(T.DEFENSE)).has(&"magic_cloak"))
	assert_true(_ids(p.catalog(T.UTILITY)).has(&"grapes"))
	assert_eq(_ids(p.catalog(T.SECRET)), [&"frost_orb", &"resolute_armor"])
	p.free()


func test_D_106_scroll_and_recipe_lines() -> void:
	var p: ShopPanel = _panel()
	p.toggle()
	assert_true(p.max_scroll() > 0.0, "nhiều món: lưới cuộn được")
	p.scroll_by(10000.0)
	assert_near(p.scroll, p.max_scroll(), 0.01)
	p.scroll_by(-10000.0)
	assert_eq(p.scroll, 0.0)
	var wb: ItemDef = p.world.item_catalog[&"wraith_band"]
	assert_eq(RecipeTree.fee(p.world, wb), 130, "phí ghép")
	var into: Array[ItemDef] = RecipeTree.builds_into(p.world, p.world.item_catalog[&"circlet"])
	assert_true(into.has(wb), "Vòng Đầu ghép thành Vòng Ma")
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
	p.press_at(p.card_rect(_ids(p.catalog(T.ATTACK)).find(&"stun_hammer")).get_center())
	assert_eq(p.selected_def().id, &"stun_hammer", "chạm thẻ thì xem chi tiết, chưa mua")
	assert_eq(bought.size(), 0)
	p.press_at(p.action_rect().get_center())
	assert_eq(bought, [&"stun_hammer"], "nút Mua")
	p.press_at(p.tab_rect(T.MAGIC).get_center())
	p.press_at(p.card_rect(_ids(p.catalog(T.MAGIC)).find(&"hex_scythe")).get_center())
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


func test_D_115_recipe_tree_links_components_and_select_by_tap() -> void:
	var p: ShopPanel = _panel()
	var w: World = p.world
	var wb: ItemDef = w.item_catalog[&"wraith_band"]
	Items.give(w, p.hero, w.item_catalog[&"circlet"])
	var tree: Array = RecipeTree.layout(w, p.hero, wb, p.detail_rect().position + Vector2(24, 162), 500.0)  # D-130: đúng chỗ khung chi tiết
	var nodes: Array = tree[0]
	assert_eq((nodes[0] as RecipeTree.TreeNode).def, wb, "gốc = món đang xem")
	var parts: Array = nodes.filter(func(n: RecipeTree.TreeNode) -> bool: return n.parent == 0)
	assert_eq(parts.size(), wb.components.size(), "mỗi thành phần một nút nối với gốc")
	var circ: Array = parts.filter(func(n: RecipeTree.TreeNode) -> bool: return n.def.id == &"circlet")
	assert_true((circ[0] as RecipeTree.TreeNode).owned, "thành phần đang có trong túi: đánh dấu")
	for n: RecipeTree.TreeNode in parts:
		assert_true(n.center.y > (nodes[0] as RecipeTree.TreeNode).center.y, "thành phần nằm dưới món ghép")
	assert_eq(RecipeTree.node_at(nodes, (circ[0] as RecipeTree.TreeNode).center), circ[0])
	p.toggle()
	p.selected_id = &"wraith_band"
	p.queue_redraw()
	p._tree = nodes
	p.press_at((circ[0] as RecipeTree.TreeNode).center)
	assert_eq(p.selected_id, &"circlet", "chạm ô thành phần: chuyển sang xem món đó")
	p.free()


func test_D_120_compose_button_adds_and_build_slot_removes() -> void:
	var p: ShopPanel = _panel()
	var saved: Array = []
	p.build_changed.connect(func(b: Array[StringName]) -> void: saved.append(b.duplicate()))
	p.toggle()
	p.selected_id = &"wraith_band"
	p.press_at(p.compose_rect().get_center())
	assert_eq(p.build, [&"wraith_band"] as Array[StringName], "Soạn +: thêm vào bộ soạn sẵn")
	p.selected_id = &"boots_haste"
	p.press_at(p.compose_rect().get_center())
	assert_eq(p.build.size(), 2)
	p.press_at(p.build_rect(0).get_center())
	assert_eq(p.build, [&"boots_haste"] as Array[StringName], "chạm ô soạn sẵn: bỏ món")
	assert_eq(saved.size(), 3, "mỗi lần đổi báo để lưu")
	for id: StringName in [&"circlet", &"slippers", &"mantle", &"gauntlets", &"iron_branch", &"bracer"]:
		p.toggle_build(id)
	assert_eq(p.build.size(), ShopPanel.BUILD_MAX, "tối đa 6 món")
	p.free()


func test_D_120_build_presets_round_trip() -> void:
	var b: Array[StringName] = [&"wraith_band", &"butterfly"]
	BuildPresets.save_build(&"test_hero", b)
	assert_eq(BuildPresets.load_build(&"test_hero"), b)
	BuildPresets.save_build(&"test_hero", [] as Array[StringName])
	assert_eq(BuildPresets.load_build(&"test_hero").size(), 0)
