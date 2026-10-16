extends TestCase
## M6.5b: mua bán (SHOP-01..06, D-81).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const R := Command.Reject

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_shop(w, _lib)
	return w


func _hero(w: World, team: int = 0, at: Vector2 = Vector2.INF) -> Entity:
	var p: Vector2 = at if at.is_finite() else _map.world_size() * 0.5 + Vector2(-900, 900)
	var h: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], team, w.navigation(32.0).nearest_clear(p))
	h.gold = 10000
	return h


## Món thử thêm vào cửa hàng của trận.
func _item(w: World, id: StringName, cost: int, shop: ItemDef.ShopKind = ItemDef.ShopKind.BASE, unlock: float = 0.0, unique: bool = false) -> ItemDef:
	var d: ItemDef = ItemDef.new()
	d.id = id
	d.display_name = String(id)
	d.cost = cost
	d.shop = shop
	d.unlock_time = unlock
	d.unique = unique
	w.item_catalog[id] = d
	return d


func _buy(w: World, h: Entity, id: StringName) -> R:
	w.submit(Command.buy(h.id, id))
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else R.NONE


func _sell(w: World, h: Entity, index: int) -> R:
	w.submit(Command.sell(h.id, index))
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else R.NONE


func test_SHOP_01_buy_anywhere_even_dead_gold_and_slots() -> void:
	var w: World = _world()
	var h: Entity = _hero(w)
	assert_eq(_buy(w, h, &"reveal_dust"), R.NONE, "đồ thường mua ở mọi nơi")
	assert_eq(h.gold, 10000 - 80)
	assert_eq(h.items[0].def.id, &"reveal_dust")
	assert_eq(_buy(w, h, &"no_such_item"), R.BAD_ITEM)
	h.gold = 10
	assert_eq(_buy(w, h, &"reveal_dust"), R.NOT_ENOUGH_GOLD)
	h.gold = 10000
	for i: int in range(5):
		_buy(w, h, &"reveal_dust")
	assert_eq(_buy(w, h, &"reveal_dust"), R.INVENTORY_FULL)
	var d: World = _world()
	var dead: Entity = _hero(d)
	dead.alive = false
	dead.respawn_tick = d.tick + 300
	assert_eq(_buy(d, dead, &"reveal_dust"), R.NONE, "đang chờ hồi sinh vẫn mua được đồ thường")


func test_SHOP_02_secret_items_only_near_either_secret_shop_and_alive() -> void:
	var w: World = _world()
	_item(w, &"test_secret", 500, ItemDef.ShopKind.SECRET)
	var h: Entity = _hero(w)
	assert_eq(_buy(w, h, &"test_secret"), R.NOT_IN_SHOP, "ở xa shop ẩn")
	h.position = w.navigation(32.0).nearest_clear(_map.shop_points[0] + Vector2(300, 0))
	assert_eq(_buy(w, h, &"test_secret"), R.NONE, "trong 600 quanh S1")
	var enemy: Entity = _hero(w, 1, _map.shop_points[0] + Vector2(0, 300))
	assert_eq(_buy(w, enemy, &"test_secret"), R.NONE, "đội kia cũng dùng được S1")
	var far: Entity = _hero(w, 0, _map.shop_points[1] + Vector2(-200, 200))
	assert_eq(_buy(w, far, &"test_secret"), R.NONE, "S1' cũng bán")
	far.alive = false
	far.respawn_tick = w.tick + 300
	assert_eq(_buy(w, far, &"test_secret"), R.NOT_IN_SHOP, "chờ hồi sinh thì không mua đồ shop ẩn")


func test_SHOP_03_unlock_time() -> void:
	var w: World = _world()
	_item(w, &"test_late", 500, ItemDef.ShopKind.BASE, 2.0)
	var h: Entity = _hero(w)
	assert_eq(_buy(w, h, &"test_late"), R.NOT_YET)
	while w.tick < 60:
		w.step()
	assert_eq(_buy(w, h, &"test_late"), R.NONE, "tới giây 2 thì mở")


func test_SHOP_04_unique_one_per_match_returns_when_sold() -> void:
	var w: World = _world()
	_item(w, &"test_unique", 1000, ItemDef.ShopKind.BASE, 0.0, true)
	var a: Entity = _hero(w, 0)
	var b: Entity = _hero(w, 1, _map.world_size() * 0.5 + Vector2(900, -900))
	assert_eq(_buy(w, a, &"test_unique"), R.NONE)
	assert_eq(_buy(w, b, &"test_unique"), R.SOLD_OUT, "đã có người giữ")
	assert_eq(_buy(w, a, &"test_unique"), R.SOLD_OUT, "kể cả người đang giữ")
	a.alive = false
	a.respawn_tick = w.tick + 300
	w.step()
	assert_eq(_buy(w, b, &"test_unique"), R.SOLD_OUT, "chết không rơi đồ")
	assert_eq(_sell(w, a, 0), R.NONE)
	assert_eq(_buy(w, b, &"test_unique"), R.NONE, "bán lại thì món về cửa hàng")


func test_SHOP_05_sell_half_or_full_refund_within_10s() -> void:
	var w: World = _world()
	_item(w, &"test_blade", 1001)
	var h: Entity = _hero(w)
	_buy(w, h, &"test_blade")
	assert_eq(_sell(w, h, 0), R.NONE)
	assert_eq(h.gold, 10000, "bán trong 10 s: hoàn đủ")
	_buy(w, h, &"test_blade")
	for i: int in range(10 * 30 + 1):
		w.step()
	var before: int = h.gold
	w.submit(Command.sell(h.id, 0))
	var refund: int = -1
	w.step()
	for ev: GameEvent in w.events:
		if ev.type == &"item_sold":
			refund = int(ev.amount)
	assert_eq(refund, 500, "sau 10 s: 50% (làm tròn xuống)")
	assert_true(h.gold >= before + 500)
	assert_true(h.items[0] == null)
	assert_eq(_sell(w, h, 0), R.BAD_ITEM, "ô trống")
