class_name TriggerSystem
extends SimSystem
## Pha 10: vùng có độ trễ tới hạn, rồi xử lý sự kiện theo thứ tự (cả sự kiện do trigger sinh
## ra trong lúc xử lý). Mỗi sự kiện: trigger vai SOURCE trên kẻ gây, vai TARGET trên đối
## tượng (EFF-08); sát thương của trigger tính ngay; rồi gỡ hiệu ứng `removed_by` (EFF-05).
## Sự kiện tầng ≥ MAX_DEPTH không kích hoạt trigger nữa (EFF-04). Sự kiện phát sau pha này
## (chết, hồi sinh…) được xử lý ở tick sau.

const MAX_DEPTH: int = 4

var _done_seq: int = 0


func run(world: World) -> void:
	_fire_due_areas(world)
	for ev: GameEvent in world.previous_events:
		if ev.seq > _done_seq:
			_handle(world, ev)
	var i: int = 0
	while i < world.events.size():
		var ev: GameEvent = world.events[i]
		if ev.seq > _done_seq:
			_handle(world, ev)
		i += 1
	world.emit_depth = 0


func _fire_due_areas(world: World) -> void:
	var waiting: Array[PendingArea] = []
	var due: Array[PendingArea] = []
	for p: PendingArea in world.pending_areas:
		(due if world.tick >= p.due_tick else waiting).append(p)
	world.pending_areas = waiting
	for p: PendingArea in due:
		ActionRunner.fire_area(world, p)
	DamageSystem.resolve(world)


func _handle(world: World, ev: GameEvent) -> void:
	_done_seq = ev.seq
	var source: Entity = world.find_entity(ev.source_id) if ev.source_id >= 0 else null
	var target: Entity = world.find_entity(ev.target_id) if ev.target_id >= 0 else null
	var source_has: bool = source != null and not source.effects.is_empty()
	var target_has: bool = target != null and not target.effects.is_empty()
	if not source_has and not target_has and ev.effect == null:
		return  # không ai có hiệu ứng: không trigger, không removed_by
	if ev.depth < MAX_DEPTH:
		world.emit_depth = ev.depth + 1
		_fire_on(world, ev, source, target, TriggerDef.Role.SOURCE)
		_fire_on(world, ev, target, source, TriggerDef.Role.TARGET)
		if ev.type == &"effect_removed" and ev.effect != null and target != null:
			_fire_instance(world, ev, target, source, ev.effect, TriggerDef.Role.TARGET, true)
		if not world.damage_requests.is_empty():
			DamageSystem.resolve(world)
	if source_has:
		_remove_by_event(world, ev, source)


## Trigger vai `role` trên các hiệu ứng của `owner` (đơn vị còn sống).
func _fire_on(world: World, ev: GameEvent, owner: Entity, other: Entity, role: TriggerDef.Role) -> void:
	if owner == null or not owner.alive or owner.effects.is_empty():
		return
	for inst: EffectInstance in owner.effects.duplicate():
		if owner.effects.has(inst):
			_fire_instance(world, ev, owner, other, inst, role, false)


func _fire_instance(world: World, ev: GameEvent, owner: Entity, other: Entity, inst: EffectInstance,
		role: TriggerDef.Role, removed_self: bool) -> void:
	if removed_self and not owner.alive:
		return
	var triggers: Array[TriggerDef] = inst.def.triggers
	for index: int in range(triggers.size()):
		var t: TriggerDef = triggers[index]
		if t.event != ev.type or t.role != role:
			continue
		if not _condition_ok(t.condition, ev, inst, other, removed_self):
			continue
		if world.tick < inst.trigger_ready.get(index, 0) or not _group_winner(owner, inst, t):
			continue
		var ctx: ExprContext = _context(world, ev, owner, other, inst)
		if not t.chance.is_empty() and not Prd.roll(world, Prd.key(owner.id, inst.serial * 16 + index), ExprEval.evaluate(t.chance, ctx)):
			continue  # RNG-01
		if not t.cooldown.is_empty():
			inst.trigger_ready[index] = world.tick + SimClock.seconds_to_ticks(ExprEval.evaluate(t.cooldown, ctx))
		ActionRunner.run(world, t.actions, ctx, owner.id)


## EFF-08: điều kiện có tên. this_effect_* chỉ đúng với chính bản vừa bị gỡ.
func _condition_ok(condition: StringName, ev: GameEvent, inst: EffectInstance, other: Entity, removed_self: bool) -> bool:
	match condition:
		&"":
			return not removed_self
		&"target_not_structure":
			return not removed_self and other != null and not Rules.is_structure(other)
		&"target_is_hero":
			return not removed_self and other != null and other.kind == Entity.Kind.HERO
		&"this_effect_depleted":
			return removed_self and ev.effect == inst and ev.reason == &"depleted"
		&"this_effect_ended":
			return removed_self and ev.effect == inst and ev.reason != &"owner_died"
	push_error("EFF-08: điều kiện không có trong luật: %s" % condition)
	return false


## STAT-05 (D-55): trong nhóm, chỉ bản có ô đồ lớn nhất (hòa: số thứ tự nhỏ hơn) được tung.
func _group_winner(owner: Entity, inst: EffectInstance, t: TriggerDef) -> bool:
	if t.unique_group.is_empty():
		return true
	for other: EffectInstance in owner.effects:
		if other == inst:
			continue
		for ot: TriggerDef in other.def.triggers:
			if ot.unique_group == t.unique_group and (other.item_slot > inst.item_slot \
					or (other.item_slot == inst.item_slot and other.serial < inst.serial)):
				return false
	return true


func _context(world: World, ev: GameEvent, owner: Entity, other: Entity, inst: EffectInstance) -> ExprContext:
	var ctx: ExprContext = ExprContext.make(owner, other, inst.values)
	ctx.event_source = world.find_entity(ev.source_id)
	ctx.event_target = world.find_entity(ev.target_id)
	if ev.type == &"damage_taken" or ev.type == &"attack_landed":
		ctx.event_damage = ev.amount
	return ctx


## EFF-05: hiệu ứng của kẻ gây sự kiện mất nếu `removed_by` có loại sự kiện này và sự kiện
## xảy ra sau khi áp. Trigger của cùng sự kiện đã chạy trước (ở _handle).
func _remove_by_event(world: World, ev: GameEvent, owner: Entity) -> void:
	for inst: EffectInstance in owner.effects.duplicate():
		if inst.def.removed_by.has(ev.type) and ev.seq > inst.applied_seq:
			Effects.remove(world, owner, inst, &"removed_by_event")
