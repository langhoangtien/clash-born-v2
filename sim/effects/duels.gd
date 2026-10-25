class_name Duels
extends RefCounted
## Quyết Đấu (DUL-01..08, D-135): bắt đầu, phản sát thương, kết thúc khi một bên chết hoặc hết
## giờ, thưởng / phạt đúng một lần, sát thương vĩnh viễn. DuelSystem lo hết giờ và ép đánh.

## Hằng số kỹ thuật: nguồn modifier của sát thương vĩnh viễn (số âm, không trùng serial).
const PERMANENT_SOURCE: int = -18


## DUL-01/02: bắt đầu giữa `a` (người tung) và `b`. Không bắt đầu được → false.
static func start(world: World, a: Entity, b: Entity, values: Dictionary[StringName, float],
		duel_effect: EffectDef = null, self_effect: EffectDef = null, self_values: Dictionary = {}) -> bool:
	if a == null or b == null or a == b or not a.alive or not b.alive or a.duel != null or b.duel != null:
		return false
	var d: DuelState = DuelState.new()
	d.knight_id = a.id
	d.foe_id = b.id
	d.values = values.duplicate()
	var seconds: float = values.get(&"duration", 0.0)
	d.end_tick = world.tick + maxi(1, SimClock.seconds_to_ticks(seconds))
	a.duel = d
	b.duel = d
	var length: String = str(seconds)
	if duel_effect != null:
		for e: Entity in [a, b]:
			d.effects.append(Effects.apply(world, e, duel_effect, a, {}, length))
	if self_effect != null:
		d.effects.append(Effects.apply(world, a, self_effect, a, self_values, length))
	force_orders(world, d)
	world.emit(&"duel_started", a.id, b.id)
	return true


## DUL-03 / ST-19: mỗi bên đánh bên kia; hủy về thành và lệnh đang chờ.
static func force_orders(world: World, d: DuelState) -> void:
	for id: int in [d.knight_id, d.foe_id]:
		var e: Entity = world.find_entity(id)
		if e == null or not e.alive:
			continue
		e.recall_until_tick = -1
		e.queued_order = null
		if e.order.type != Order.Type.ATTACK or e.order.target_id != d.other(id) or e.order.finished:
			e.order = Order.attack(d.other(id))


## DUL-04: đòn đánh `r` của đối thủ vừa trúng hiệp sĩ còn sống → yêu cầu sát thương phản (hoặc null).
static func reflect_for(r: DamageRequest, target: Entity) -> DamageRequest:
	var d: DuelState = target.duel
	if d == null or not r.is_attack or r.reflected or target.id != d.knight_id or r.source_id != d.foe_id:
		return null
	if r.damage_type != DamageFormulas.DamageType.PHYSICAL or not target.alive or target.reincarnate_tick >= 0:
		return null
	var back: DamageRequest = DamageRequest.new()
	back.source_id = target.id
	back.target_id = d.foe_id
	back.raw = r.raw * d.values.get(&"reflect", 0.0)
	back.reflected = true  # CMB-09
	back.heal_source = d.values.get(&"reflect_heal", 0.0)  # DUL-04b
	return back if back.raw > 0.0 else null


## DUL-05: `dead` vừa chết → bên kia thắng.
static func on_death(world: World, dead: Entity) -> void:
	if dead.duel != null:
		finish(world, dead.duel, world.find_entity(dead.duel.other(dead.id)))


## DUL-06/08: kết thúc; `winner` null = hết giờ. Bên thua (A hoặc B) −lose_damage (D-166).
static func finish(world: World, d: DuelState, winner: Entity) -> void:
	var a: Entity = world.find_entity(d.knight_id)
	var b: Entity = world.find_entity(d.foe_id)
	for e: Entity in [a, b]:
		if e != null and e.duel == d:
			e.duel = null
	for inst: EffectInstance in d.effects:
		var owner: Entity = world.find_entity(inst.owner_id) if inst != null else null
		if owner != null:
			Effects.remove(world, owner, inst, &"removed")
	if winner != null:
		var win: float = d.values.get(&"win_damage", 0.0)
		add_permanent(winner, win)
		winner.gold += int(d.values.get(&"win_gold", 0.0))
		add_permanent(a if winner == b else b, -d.values.get(&"lose_damage", 0.0))  # D-166: ai thua cũng bị trừ
	world.emit(&"duel_ended", winner.id if winner != null else -1, d.foe_id if winner == a else d.knight_id,
		0.0, &"won" if winner != null else &"timeout")


## DUL-07: cộng `amount` vào sát thương vĩnh viễn (modifier nguồn riêng, không mất khi chết).
static func add_permanent(e: Entity, amount: float) -> void:
	if e == null or amount == 0.0:
		return
	e.duel_damage += amount
	e.stats.remove_source(PERMANENT_SOURCE)
	e.stats.add_modifier(StatModifier.make(StatId.Id.PHYSICAL_DAMAGE, ModifierDef.Op.ADD, e.duel_damage, PERMANENT_SOURCE))
