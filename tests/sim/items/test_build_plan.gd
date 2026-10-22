extends TestCase
## SHOP-10 (D-117): thứ tự lên đồ → món nên mua lúc này (bot + nút mua nhanh).


func _setup() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	MatchSetup.add_shop(w, lib)
	var e: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 0, Vector2(1000, 1000))
	return [w, e]


func test_SHOP_10_buy_whole_item_when_affordable_else_cheapest_missing_part() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var e: Entity = s[1]
	var build: Array[StringName] = [&"wraith_band", &"boots_haste"]
	e.gold = 1000
	assert_eq(BuildPlan.next_buy(w, e, build).id, &"wraith_band", "đủ vàng: mua thẳng món lớn")
	e.gold = 160
	var part: ItemDef = BuildPlan.next_buy(w, e, build)
	assert_true(part != null and (w.item_catalog[&"wraith_band"] as ItemDef).components.has(part.id), "thiếu vàng: mua thành phần")
	e.gold = 0
	assert_eq(BuildPlan.next_buy(w, e, build), null, "không đủ mua gì: không gợi ý")


func test_SHOP_10_owned_or_built_item_is_skipped() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var e: Entity = s[1]
	var build: Array[StringName] = [&"circlet", &"wraith_band", &"boots_haste"]
	Items.give(w, e, w.item_catalog[&"wraith_band"])
	assert_eq(BuildPlan.next_target(w, e, build).id, &"boots_haste", "Vòng Đầu đã ghép vào Vòng Ma: coi như có")
