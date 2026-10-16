class_name Shop
extends RefCounted
## Mua bán (SHOP-01..06, D-81): đồ thường mua mọi nơi, đồ shop ẩn chỉ gần S1/S1', đồ mở theo
## giờ, đồ độc nhất cả trận, bán 50% hoặc hoàn đủ ngay sau khi mua.

const R := Command.Reject


## SHOP-06: lý do không mua được `id`, NONE nếu mua được.
static func buy_problem(world: World, e: Entity, id: StringName) -> R:
	var def: ItemDef = world.item_catalog.get(id)
	if def == null:
		return R.BAD_ITEM
	if def.unlock_time > 0.0 and world.tick < SimClock.seconds_to_ticks(def.unlock_time):
		return R.NOT_YET  # SHOP-03
	if def.unique and _held(world, id):
		return R.SOLD_OUT  # SHOP-04
	if stock(world, e.team, def) == 0:
		return R.OUT_OF_STOCK  # SHOP-08
	if def.shop == ItemDef.ShopKind.SECRET and not near_secret_shop(world, e):
		return R.NOT_IN_SHOP  # SHOP-02
	if e.gold < def.cost:
		return R.NOT_ENOUGH_GOLD
	if not Items.slots(e).has(null) and Items.stack_slot(e, def) < 0:
		return R.INVENTORY_FULL
	return R.NONE


static func buy(world: World, e: Entity, id: StringName) -> void:
	var def: ItemDef = world.item_catalog[id]
	e.gold -= def.cost
	_take_stock(world, e.team, def)
	Items.give(world, e, def)
	world.emit(&"item_bought", e.id, -1, def.cost, id)


static func sell_problem(e: Entity, index: int) -> R:
	if index < 0 or index >= Items.SLOTS or Items.slots(e)[index] == null:
		return R.BAD_ITEM
	return R.NONE


## SHOP-05: 50% giá (làm tròn xuống), hoàn đủ nếu bán trong `sell_full_refund_time` giây.
static func sell(world: World, e: Entity, index: int) -> void:
	var it: ItemInstance = Items.slots(e)[index]
	var refund: int = refund_for(world, it)
	Items.remove(world, e, index)
	e.gold += refund
	world.emit(&"item_sold", e.id, -1, refund, it.def.id)


## SHOP-02: còn sống và trong `shop_radius` quanh một shop ẩn.
static func near_secret_shop(world: World, e: Entity) -> bool:
	if not e.alive or world.map == null:
		return false
	for p: Vector2 in world.map.shop_points:
		if e.position.distance_to(p) <= world.balance.shop_radius:
			return true
	return false


static func _held(world: World, id: StringName) -> bool:
	for e: Entity in world.entities:
		for it: ItemInstance in e.items:
			if it != null and it.def.id == id:
				return true
	return false


## SHOP-05: số vàng nhận lại nếu bán món `it` lúc này.
## Món gộp (WRD-01) tính theo số lần dùng còn lại.
static func refund_for(world: World, it: ItemInstance) -> int:
	var full: bool = world.tick - it.bought_tick <= SimClock.seconds_to_ticks(world.balance.sell_full_refund_time)
	var worth: int = it.def.cost
	if it.def.max_stack > 0 and it.def.charges > 0:
		worth = it.def.cost * it.charges / it.def.charges
	return worth if full else int(floor(worth * world.balance.sell_ratio))


## SHOP-08: món còn trong kho của đội `team`; -1 = không giới hạn.
static func stock(world: World, team: int, def: ItemDef) -> int:
	if def.stock_max <= 0 or team < 0 or team >= world.shop_stock.size():
		return -1
	return world.shop_stock[team][def.id][0]


## SHOP-08: giây còn lại tới lần thêm hàng kế tiếp; -1 nếu kho đang đầy hoặc không giới hạn.
static func restock_seconds(world: World, team: int, def: ItemDef) -> float:
	if stock(world, team, def) < 0 or world.shop_stock[team][def.id][1] < 0:
		return -1.0
	return (world.shop_stock[team][def.id][1] - world.tick) * SimClock.TICK_SECONDS


static func init_stock(world: World) -> void:
	world.shop_stock = [{}, {}]
	for def: ItemDef in world.item_catalog.values():
		if def.stock_max <= 0:
			continue
		for t: int in range(2):
			var full: bool = def.stock_initial >= def.stock_max
			world.shop_stock[t][def.id] = [def.stock_initial, -1 if full else SimClock.seconds_to_ticks(def.stock_restock)]


## SHOP-08: chạy mỗi tick (EconomySystem): kho chưa đầy thì tới hạn thêm 1.
static func restock(world: World) -> void:
	for t: int in range(world.shop_stock.size()):
		for id: StringName in world.shop_stock[t]:
			var entry: Array = world.shop_stock[t][id]
			if entry[1] >= 0 and world.tick >= entry[1]:
				var def: ItemDef = world.item_catalog[id]
				entry[0] += 1
				entry[1] = -1 if entry[0] >= def.stock_max else entry[1] + SimClock.seconds_to_ticks(def.stock_restock)


static func _take_stock(world: World, team: int, def: ItemDef) -> void:
	if stock(world, team, def) < 0:
		return
	var entry: Array = world.shop_stock[team][def.id]
	entry[0] -= 1
	if entry[1] < 0:
		entry[1] = world.tick + SimClock.seconds_to_ticks(def.stock_restock)
