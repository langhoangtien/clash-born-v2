class_name ActionRunner
extends RefCounted
## Thực thi hành động (ARCHITECTURE 3.5): Damage, Heal, ApplyEffect, RemoveEffect, Area,
## Dispel, Purge. Các loại còn lại thêm ở mốc của hero cần chúng. `source_id`: kẻ được tính
## là gây ra (sát thương, hiệu ứng).


static func run(world: World, actions: Array[ActionDef], ctx: ExprContext, source_id: int) -> void:
	for action: ActionDef in actions:
		if action is AreaAction:
			_area(world, action, ctx, source_id)
			continue
		var receiver: Entity = receiver_of(action.target, ctx)
		if receiver == null or not receiver.alive:
			continue
		if action is DamageAction:
			_damage(world, action, ctx, receiver, source_id)
		elif action is HealAction:
			heal(world, receiver, ExprEval.evaluate((action as HealAction).amount, ctx), source_id)
		elif action is ApplyEffectAction:
			var a: ApplyEffectAction = action
			var duration: String = "" if a.duration.is_empty() else str(ExprEval.evaluate(a.duration, ctx))
			Effects.apply(world, receiver, a.effect, ctx.owner, ctx.values, duration)
		elif action is RemoveEffectAction:
			for inst: EffectInstance in receiver.effects.duplicate():
				if inst.def == (action as RemoveEffectAction).effect:
					Effects.remove(world, receiver, inst, &"removed")
		elif action is DispelAction:
			_strip(world, receiver, &"debuff", (action as DispelAction).level, ctx, [], source_id)
		elif action is PurgeAction:
			var p: PurgeAction = action
			_strip(world, receiver, &"buff", p.level, ctx, p.on_each, source_id)
		else:
			push_error("ActionRunner: %s chưa làm" % action.get_script().get_global_name())


static func receiver_of(target: ActionDef.Target, ctx: ExprContext) -> Entity:
	match target:
		ActionDef.Target.SELF:
			return ctx.owner
		ActionDef.Target.EVENT_SOURCE:
			return ctx.event_source
		ActionDef.Target.EVENT_TARGET:
			return ctx.event_target
	return ctx.target


## Hồi máu, không quá máu tối đa.
static func heal(_world: World, e: Entity, amount: float, _source_id: int) -> void:
	e.health = minf(e.stats.get_stat(StatId.Id.MAX_HP), e.health + maxf(0.0, amount))


static func _damage(world: World, d: DamageAction, ctx: ExprContext, receiver: Entity, source_id: int) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source_id
	r.target_id = receiver.id
	r.raw = ExprEval.evaluate(d.amount, ctx)
	r.damage_type = d.damage_type
	world.damage_requests.append(r)


## EFF-07: gỡ hiệu ứng mang `tag` mà mức `level` gỡ được (BASIC ≤ STRONG; NONE không bao giờ).
static func _strip(world: World, receiver: Entity, tag: StringName, level: EffectDef.Dispel, ctx: ExprContext,
		on_each: Array[ActionDef], source_id: int) -> void:
	var removed: int = 0
	for inst: EffectInstance in receiver.effects.duplicate():
		var d: EffectDef = inst.def
		if d.tags.has(tag) and d.dispel != EffectDef.Dispel.NONE and d.dispel <= level:
			Effects.remove(world, receiver, inst, &"dispelled")
			removed += 1
			run(world, on_each, ctx.with_target(receiver), source_id)
	if removed > 0:
		world.emit(&"dispelled", source_id, receiver.id, removed)


## ABL-06/07/13: chốt tâm (CIRCLE) lúc tung; có độ trễ thì chờ, không thì chạy ngay.
static func _area(world: World, a: AreaAction, ctx: ExprContext, source_id: int) -> void:
	var anchor: Entity = receiver_of(a.target, ctx)
	var p: PendingArea = PendingArea.new()
	p.action = a
	p.ctx = ctx
	p.source_id = source_id
	p.center = ctx.point if ctx.point.is_finite() else (anchor.position if anchor != null else Vector2.ZERO)
	var delay: float = ExprEval.evaluate(a.delay, ctx)
	p.due_tick = world.tick + SimClock.seconds_to_ticks(delay)
	if delay <= 0.0:
		fire_area(world, p)
	else:
		world.pending_areas.append(p)


## Chạy vùng: mọi đơn vị địch (không phải công trình) trong vùng, theo id, thành `target`.
static func fire_area(world: World, p: PendingArea) -> void:
	var a: AreaAction = p.action
	var owner: Entity = p.ctx.owner
	var radius: float = ExprEval.evaluate(a.radius, p.ctx)
	var length: float = ExprEval.evaluate(a.length, p.ctx)
	var half_width: float = ExprEval.evaluate(a.width, p.ctx) * 0.5
	var dir: Vector2 = p.ctx.direction if p.ctx.direction != Vector2.ZERO else owner.facing
	var start: Vector2 = owner.position
	var reach: float = radius if a.shape == AreaAction.Shape.CIRCLE else length + half_width
	var around: Vector2 = p.center if a.shape == AreaAction.Shape.CIRCLE else start
	for e: Entity in world.spatial_near(around, reach, World.Phase.TRIGGER):
		if not _area_accepts(p.ctx, owner, e):
			continue
		var hit: bool
		if a.shape == AreaAction.Shape.CIRCLE:
			hit = e.position.distance_to(p.center) - e.radius <= radius
		else:
			var rel: Vector2 = e.position - start
			var along: float = rel.dot(dir.normalized())
			hit = along >= -e.radius and along <= length + e.radius and absf(rel.cross(dir.normalized())) <= half_width + e.radius
		if hit:
			run(world, a.actions, p.ctx.with_target(e), p.source_id)


## ABL-07: vùng của kỹ năng lọc theo target_filter; không có kỹ năng → địch không phải công trình (EFF-15).
static func _area_accepts(ctx: ExprContext, owner: Entity, e: Entity) -> bool:
	if ctx.ability != null:
		return Abilities.accepts(owner, ctx.ability, e)
	return not Rules.is_structure(e) and Rules.is_targetable(owner, e)
