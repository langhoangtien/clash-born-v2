class_name TauntSystem
extends SimSystem
## Pha STATE, sau DuelSystem (ST-20, D-383): đơn vị bị khiêu khích bị ép đánh kẻ khiêu khích (bản áp sau cùng). Kẻ khiêu
## khích chết / không còn → gỡ hiệu ứng (`source_died`). Công trình, quái boss và đơn vị đang Quyết Đấu không bị ép.
## Chỉ ghi lệnh của đơn vị (như DuelSystem) và gỡ hiệu ứng TAUNTED.


func run(world: World) -> void:
	for e: Entity in world.entities:
		if not e.alive or not Rules.has_state(e, UnitState.Id.TAUNTED):
			continue
		_drop_orphans(world, e)
		if not Rules.is_taunted(world, e) or e.duel != null:
			continue  # ST-20: công trình / boss miễn; Quyết Đấu thắng
		var t: Entity = Rules.taunter(world, e)
		if t == null:
			continue
		Recall.cancel(world, e)
		e.queued_order = null
		if not Rules.is_attackable(e, t):
			if e.order.type != Order.Type.IDLE:
				e.order = Order.idle()  # ST-20: kẻ khiêu khích không nhắm được (tàng hình, GHOST, UNTARGETABLE) thì đứng chờ
		elif e.order.type != Order.Type.ATTACK or e.order.target_id != t.id or e.order.finished:
			e.order = Order.attack(t.id)


## Bản TAUNTED mà kẻ khiêu khích đã chết hoặc rời trận thì gỡ.
static func _drop_orphans(world: World, e: Entity) -> void:
	for inst: EffectInstance in e.effects.duplicate():
		if not inst.def.states.has(UnitState.Id.TAUNTED):
			continue
		var src: Entity = world.find_entity(inst.source_id)
		if src == null or not src.alive:
			Effects.remove(world, e, inst, &"source_died")
