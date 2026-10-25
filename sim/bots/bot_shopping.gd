class_name BotShopping
extends RefCounted
## BOT-22 (D-164): đầy ô mà món kế tiếp trong thứ tự lên đồ chưa có → bán món đầu trận rẻ nhất
## (giá < bot_sell_max_cost, không phải thành phần của món kế tiếp, không phải món có số lần dùng)
## nếu vàng + tiền bán đủ mua món kế tiếp.


## Gửi lệnh bán (nếu cần) để mua được `next`; true nếu đã gửi.
static func sell_for(world: World, e: Entity, next: ItemDef) -> bool:
	if next == null or not _full(e):
		return false
	var why: Command.Reject = Shop.buy_problem(world, e, next.id)
	if why != Command.Reject.INVENTORY_FULL and why != Command.Reject.NOT_ENOUGH_GOLD:
		return false
	var index: int = _cheapest(world, e, next)
	if index < 0:
		return false
	if e.gold + Shop.refund_for(world, Items.slots(e)[index]) < Shop.price(world, e, next):
		return false
	world.submit(Command.sell(e.id, index))
	e.bot.sold.append(Items.slots(e)[index].def.id)
	return true


## Thứ tự lên đồ của bot trừ các món đã bán theo BOT-22.
static func build(e: Entity) -> Array[StringName]:
	return e.hero_def.bot_item_build.filter(func(id: StringName) -> bool: return not e.bot.sold.has(id))


static func _full(e: Entity) -> bool:
	for it: ItemInstance in Items.slots(e):
		if it == null:
			return false
	return true


## Ô của món rẻ nhất được phép bán; -1 nếu không có.
static func _cheapest(world: World, e: Entity, next: ItemDef) -> int:
	var best: int = -1
	var slots: Array[ItemInstance] = Items.slots(e)
	for i: int in slots.size():
		var d: ItemDef = slots[i].def
		if d.cost >= world.balance.bot_sell_max_cost or d.max_stack > 0 or BuildPlan.contains(world, next, d.id):
			continue
		if best < 0 or d.cost < slots[best].def.cost:
			best = i
	return best
