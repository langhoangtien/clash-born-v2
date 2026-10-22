class_name BuildPlan
extends RefCounted
## SHOP-10 (D-117): thứ tự lên đồ → món nên mua lúc này. Bot (D-94) và nút mua nhanh của
## người chơi dùng chung. `build` là danh sách id món lớn theo thứ tự.


## Món kế tiếp trong `build` chưa có (kể cả đã ghép vào món lớn hơn), null nếu đã đủ.
static func next_target(world: World, e: Entity, build: Array[StringName]) -> ItemDef:
	for id: StringName in build:
		var owned: bool = Items.slots(e).any(func(it: ItemInstance) -> bool: return it != null and contains(world, it.def, id))
		if not owned and world.item_catalog.has(id):
			return world.item_catalog[id]
	return null


## Món mua được ngay: món kế tiếp nếu đủ vàng, không thì thành phần còn thiếu đầu tiên mua
## được (đi sâu vào thành phần của thành phần, D-106). null = chưa mua được gì.
static func next_buy(world: World, e: Entity, build: Array[StringName]) -> ItemDef:
	var d: ItemDef = next_target(world, e, build)
	if d == null:
		return null
	if Shop.buy_problem(world, e, d.id) == Command.Reject.NONE:
		return d
	return next_part(world, e, d)


## Món `d` chính là `id` hoặc đã ghép từ `id` (SHOP-09) — coi như đã có.
static func contains(world: World, d: ItemDef, id: StringName) -> bool:
	if d.id == id:
		return true
	for c: StringName in d.components:
		if world.item_catalog.has(c) and contains(world, world.item_catalog[c], id):
			return true
	return false


## D-106: thành phần còn thiếu đầu tiên của `d` mua được ngay (theo thứ tự, đi sâu).
static func next_part(world: World, e: Entity, d: ItemDef) -> ItemDef:
	var owned: Array[int] = Shop.owned_components(world, e, d)
	var held: Array[StringName] = []
	for index: int in owned:
		held.append(Items.slots(e)[index].def.id)
	for c: StringName in d.components:
		if held.has(c):
			held.erase(c)
			continue
		var part: ItemDef = world.item_catalog.get(c)
		if part == null:
			continue
		if Shop.buy_problem(world, e, c) == Command.Reject.NONE:
			return part
		var deeper: ItemDef = next_part(world, e, part) if not part.components.is_empty() else null
		if deeper != null:
			return deeper
		return null
	return null
