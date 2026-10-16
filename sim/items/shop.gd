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
	if def.shop == ItemDef.ShopKind.SECRET and not near_secret_shop(world, e):
		return R.NOT_IN_SHOP  # SHOP-02
	if e.gold < def.cost:
		return R.NOT_ENOUGH_GOLD
	if not Items.slots(e).has(null):
		return R.INVENTORY_FULL
	return R.NONE


static func buy(world: World, e: Entity, id: StringName) -> void:
	var def: ItemDef = world.item_catalog[id]
	e.gold -= def.cost
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
static func refund_for(world: World, it: ItemInstance) -> int:
	var full: bool = world.tick - it.bought_tick <= SimClock.seconds_to_ticks(world.balance.sell_full_refund_time)
	return it.def.cost if full else int(floor(it.def.cost * world.balance.sell_ratio))
