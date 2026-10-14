class_name Effects
extends RefCounted
## Áp / gỡ hiệu ứng (EFF-01, 02, 06, 09). Cách duy nhất để thêm hoặc bỏ hiệu ứng; modifier
## của hiệu ứng vào StatBlock với nguồn = số thứ tự của bản hiệu ứng.


## Áp `def` lên `owner`. `values`: giá trị có tên của kỹ năng (được chép lại). `duration`:
## thời lượng do hành động truyền vào khi `def.duration` rỗng. `item_slot`: ô đồ (D-55).
static func apply(world: World, owner: Entity, def: EffectDef, source: Entity, values: Dictionary = {},
		duration: String = "", item_slot: int = 0) -> EffectInstance:
	var source_id: int = source.id if source != null else -1
	if def.tags.has(&"debuff") and source != null and source.team != owner.team \
			and Rules.has_state(owner, UnitState.Id.INVULNERABLE):
		return null  # ST-17: bất tử chặn debuff mới từ phe địch
	var inst: EffectInstance = null
	if def.stacking != EffectDef.Stacking.INDEPENDENT:
		inst = _find(owner, def, source_id)  # EFF-02: nguồn khác → bản khác
	if inst == null:
		inst = EffectInstance.new()
		inst.serial = world.next_serial()
		inst.def = def
		inst.owner_id = owner.id
		inst.source_id = source_id
		inst.item_slot = item_slot
		inst.stacks = 1
		owner.effects.append(inst)
	elif def.stacking == EffectDef.Stacking.STACK:
		inst.stacks = mini(inst.stacks + 1, maxi(1, def.max_stacks))
	inst.values = values.duplicate()
	inst.applied_seq = world.event_seq  # EFF-05: chỉ sự kiện sau mốc này làm mất
	_start(world, owner, inst, duration)
	refresh_states(owner)
	world.emit(&"effect_applied", source_id, owner.id, inst.stacks)
	return inst


## Gỡ một bản hiệu ứng; `reason` theo EVT: expired, depleted, removed_by_event, dispelled, owner_died.
static func remove(world: World, owner: Entity, inst: EffectInstance, reason: StringName) -> void:
	if not owner.effects.has(inst):
		return
	owner.effects.erase(inst)
	owner.stats.remove_source(inst.serial)
	refresh_states(owner)
	world.emit(&"effect_removed", inst.source_id, owner.id, inst.stacks, reason).effect = inst


## ST: trạng thái = hợp các state của mọi hiệu ứng đang có.
static func refresh_states(owner: Entity) -> void:
	var bits: int = 0
	for inst: EffectInstance in owner.effects:
		for state: UnitState.Id in inst.def.states:
			bits |= 1 << state
	owner.states = bits


## DTH: chết thì gỡ mọi hiệu ứng trừ tag `passive` (D-56).
static func remove_on_death(world: World, owner: Entity) -> void:
	for inst: EffectInstance in owner.effects.duplicate():
		if not inst.def.tags.has(&"passive"):
			remove(world, owner, inst, &"owner_died")


## EFF-06: khiên hút `amount` (đã qua giáp và hệ số nhận), khiên áp trước trừ trước. Trả về
## phần còn lại trừ vào máu.
static func absorb(world: World, owner: Entity, amount: float) -> float:
	for inst: EffectInstance in owner.effects.duplicate():
		if amount <= 0.0:
			break
		if inst.absorb_left < 0.0:
			continue
		var taken: float = minf(inst.absorb_left, amount)
		inst.absorb_left -= taken
		amount -= taken
		if inst.absorb_left <= 0.0:
			remove(world, owner, inst, &"depleted")
	return amount


static func context(world: World, owner: Entity, inst: EffectInstance) -> ExprContext:
	return ExprContext.make(owner, world.find_entity(inst.source_id), inst.values)


static func _find(owner: Entity, def: EffectDef, source_id: int) -> EffectInstance:
	for inst: EffectInstance in owner.effects:
		if inst.def == def and inst.source_id == source_id:
			return inst
	return null


## Thời hạn, khiên, periodic và modifier (tính lại theo số tầng) của bản vừa áp / làm mới.
static func _start(world: World, owner: Entity, inst: EffectInstance, duration: String) -> void:
	var def: EffectDef = inst.def
	var ctx: ExprContext = ExprContext.make(owner, owner, inst.values)
	var length: String = def.duration if not def.duration.is_empty() else duration
	var seconds: float = ExprEval.evaluate(length, ctx)
	if def.tags.has(&"debuff") and seconds > 0.0:  # ST-09
		seconds *= 1.0 - owner.stats.get_stat(StatId.Id.STATUS_RESISTANCE)
	inst.start_tick = world.tick
	inst.end_tick = world.tick + maxi(1, SimClock.seconds_to_ticks(seconds)) if seconds > 0.0 else -1
	if not def.absorb.is_empty():
		inst.absorb_left = ExprEval.evaluate(def.absorb, ctx)
	if not def.periodic_interval.is_empty() and not def.periodic_actions.is_empty():
		inst.period_ticks = maxi(1, SimClock.seconds_to_ticks(ExprEval.evaluate(def.periodic_interval, ctx)))
		inst.next_period_tick = world.tick + inst.period_ticks
	owner.stats.remove_source(inst.serial)
	for m: ModifierDef in def.modifiers:
		var stat: int = StatId.from_name(m.stat)
		var value: float = ExprEval.evaluate(m.value, ctx)
		if m.op == ModifierDef.Op.ADD:
			value *= inst.stacks
		elif m.op == ModifierDef.Op.MULTIPLY:
			value = 1.0 + (value - 1.0) * inst.stacks
		owner.stats.add_modifier(StatModifier.make(stat, m.op, value, inst.serial, m.unique_group, inst.item_slot))
