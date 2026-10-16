class_name Items
extends RefCounted
## Ô đồ của đơn vị (ITM-01..08): thêm / bỏ món, chỉ số, bị động một bản cho mỗi loại, hồi
## chiêu chung, số lần dùng. Lệnh dùng đồ là CAST với ô kỹ năng SLOT_BASE + chỉ số ô.

const SLOTS: int = 6
## Ô kỹ năng của món ở ô đồ k (0..5) trong Command.cast: SLOT_BASE + k.
const SLOT_BASE: int = 10


static func slots(e: Entity) -> Array[ItemInstance]:
	while e.items.size() < SLOTS:
		e.items.append(null)
	return e.items


## Cho món vào ô trống đầu tiên; trả về chỉ số ô hoặc -1 nếu đầy.
static func give(world: World, e: Entity, def: ItemDef) -> int:
	var list: Array[ItemInstance] = slots(e)
	var index: int = list.find(null)
	if index < 0:
		return -1
	var it: ItemInstance = ItemInstance.new()
	it.def = def
	it.index = index
	it.charges = def.charges
	it.serial = world.next_serial()
	it.bought_tick = world.tick
	if def.ability != null:
		var a: AbilityInstance = AbilityInstance.new()
		a.def = def.ability
		a.slot = AbilityDef.Slot.ITEM
		a.rank = 1
		a.item_index = index
		a.ready_tick = _shared_ready(e, def)
		it.ability = a
	list[index] = it
	for m: ModifierDef in def.modifiers:
		var ctx: ExprContext = ExprContext.make(e, e, {})
		e.stats.add_modifier(StatModifier.make(StatId.from_name(m.stat), m.op, ExprEval.evaluate(m.value, ctx), it.serial, m.unique_group, index + 1))
	refresh_passives(world, e)
	return index


static func remove(world: World, e: Entity, index: int) -> ItemDef:
	var list: Array[ItemInstance] = slots(e)
	var it: ItemInstance = list[index]
	if it == null:
		return null
	if it.ability != null:
		_clear_passive(world, e, it.ability)
	e.stats.remove_source(it.serial)
	list[index] = null
	refresh_passives(world, e)
	return it.def


## ITM-04/07: mỗi loại món chỉ món ở ô cao nhất áp bị động (on_learn).
static func refresh_passives(world: World, e: Entity) -> void:
	var holder: Dictionary[StringName, ItemInstance] = {}
	for it: ItemInstance in slots(e):
		if it != null and it.ability != null and not it.def.ability.on_learn.is_empty():
			holder[it.def.id] = it
	for it: ItemInstance in slots(e):
		if it == null or it.ability == null or it.def.ability.on_learn.is_empty():
			continue
		var keep: bool = holder[it.def.id] == it
		if keep and it.ability.learned_effects.is_empty():
			var before: Array[EffectInstance] = e.effects.duplicate()
			ActionRunner.run(world, it.def.ability.on_learn, Abilities.context(e, it.ability, e), e.id)
			for inst: EffectInstance in e.effects:
				if not before.has(inst):
					it.ability.learned_effects.append(inst)
		elif not keep:
			_clear_passive(world, e, it.ability)


static func _clear_passive(world: World, e: Entity, a: AbilityInstance) -> void:
	for inst: EffectInstance in a.learned_effects:
		Effects.remove(world, e, inst, &"removed")
	a.learned_effects.clear()


## Kỹ năng của món ở ô kỹ năng `slot` (SLOT_BASE + k), null nếu không có.
static func ability_at(e: Entity, slot: int) -> AbilityInstance:
	var k: int = slot - SLOT_BASE
	if k < 0 or k >= e.items.size() or e.items[k] == null:
		return null
	return e.items[k].ability


## ITM-04/07: sau khi dùng — hồi chiêu chung cho mọi món cùng loại, trừ một lần dùng.
static func after_use(e: Entity, a: AbilityInstance) -> void:
	var it: ItemInstance = e.items[a.item_index]
	for other: ItemInstance in slots(e):
		if other != null and other.ability != null and other.def.id == it.def.id:
			other.ability.ready_tick = a.ready_tick
	if it.def.charges > 0:
		it.charges -= 1


## Món hết lần dùng thì bỏ khỏi ô (gọi sau khi chiêu đã chạy).
static func drop_spent(world: World, e: Entity, a: AbilityInstance) -> void:
	if a.item_index < 0 or a.item_index >= e.items.size():
		return
	var it: ItemInstance = e.items[a.item_index]
	if it != null and it.ability == a and it.def.charges > 0 and it.charges <= 0:
		remove(world, e, a.item_index)


static func _shared_ready(e: Entity, def: ItemDef) -> int:
	var ready: int = 0
	for other: ItemInstance in slots(e):
		if other != null and other.ability != null and other.def.id == def.id:
			ready = maxi(ready, other.ability.ready_tick)
	return ready
