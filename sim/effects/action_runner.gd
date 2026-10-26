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
		if action is ProjectileAction:
			_skill_shot(world, action, ctx, source_id)
			continue
		if action is ZoneAction:
			_zone(world, action, ctx, source_id)
			continue
		if action is DashAction:
			_dash(world, action, ctx, source_id)
			continue
		if action is DuelAction:
			_duel(world, action, ctx, source_id)
			continue
		if action is PlaceWardAction:
			place_ward(world, (action as PlaceWardAction).ward, ctx.owner, ctx.point)
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
			Effects.apply(world, receiver, a.effect, ctx.owner, ctx.values, duration, ctx.item_slot, _pierces(ctx))
		elif action is RemoveEffectAction:
			for inst: EffectInstance in receiver.effects.duplicate():
				if inst.def == (action as RemoveEffectAction).effect:
					Effects.remove(world, receiver, inst, &"removed")
		elif action is PushAction:
			_push(world, action, ctx, receiver, source_id)
		elif action is ModifyCooldownAction:
			_modify_cooldown(world, action, ctx, receiver)
		elif action is ManaBurnAction:
			_mana_burn(world, receiver, ExprEval.evaluate((action as ManaBurnAction).amount, ctx), source_id)
		elif action is DispelAction:
			_strip(world, receiver, &"debuff", (action as DispelAction).level, ctx, [], source_id)
		elif action is PurgeAction:
			var p: PurgeAction = action
			if receiver.team != ctx.owner.team and not _pierces(ctx) and Rules.has_state(receiver, UnitState.Id.MAGIC_IMMUNE):
				continue  # EFF-07 (D-79): tước buff địch đang miễn phép cần nguồn xuyên miễn phép
			_strip(world, receiver, &"buff", p.level, ctx, p.on_each, source_id)
		else:
			push_error("ActionRunner: %s chưa làm" % action.get_script().get_global_name())


## WRD-01/02: ward mới của phe `owner` ở đất đi được gần `at` nhất, tàng hình, hết hạn sau `lifetime`.
static func place_ward(world: World, def: UnitDef, owner: Entity, at: Vector2) -> Entity:
	var spot: Vector2 = world.navigation(def.stats.collision_radius).nearest_clear(at) if world.map != null else at
	var w: Entity = UnitFactory.unit(world, def, Entity.Kind.WARD, owner.team, spot)
	w.health = w.stats.get_stat(StatId.Id.MAX_HP)
	w.true_sight_range = def.true_sight_range
	w.expire_tick = world.tick + SimClock.seconds_to_ticks(def.lifetime) if def.lifetime > 0.0 else -1
	Effects.refresh_states(w)
	world.emit(&"unit_spawned", owner.id, w.id)
	return w


## ST-15: hành động của kỹ năng có cờ xuyên miễn phép.
static func _pierces(ctx: ExprContext) -> bool:
	return ctx.ability != null and ctx.ability.pierces_magic_immunity


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
	r.raw = ExprEval.evaluate(d.amount, ctx) * ctx.scale
	if ctx.owner != null and not d.reflected and d.amplified:  # CMB-13: sát thương chiêu / đồ nhân khuếch đại phép của nguồn
		r.raw *= 1.0 + maxf(0.0, ctx.owner.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION))
	r.damage_type = d.damage_type
	r.reflected = d.reflected
	r.pierces_magic_immunity = _pierces(ctx)
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
	p.center = _center_of(ctx, anchor)
	p.radius = ExprEval.evaluate(a.radius, ctx)
	p.team = ctx.owner.team
	p.start_tick = world.tick
	var delay: float = ExprEval.evaluate(a.delay, ctx)
	p.due_tick = world.tick + SimClock.seconds_to_ticks(delay)
	if delay <= 0.0:
		fire_area(world, p)
	else:
		world.pending_areas.append(p)


static func _center_of(ctx: ExprContext, anchor: Entity) -> Vector2:
	return ctx.point if ctx.point.is_finite() else (anchor.position if anchor != null else Vector2.ZERO)


## ABL-17: vùng tồn tại; chốt tâm, bán kính, thời điểm lúc tung, ZoneSystem cho tác dụng định kỳ.
static func _zone(world: World, a: ZoneAction, ctx: ExprContext, source_id: int) -> void:
	var z: ActiveZone = ActiveZone.new()
	z.action = a
	z.ctx = ctx
	z.source_id = source_id
	z.center = _center_of(ctx, receiver_of(a.target, ctx))
	z.radius = ExprEval.evaluate(a.radius, ctx)
	z.team = ctx.owner.team
	z.start_tick = world.tick + SimClock.seconds_to_ticks(maxf(0.0, ExprEval.evaluate(a.delay, ctx)))
	z.end_tick = z.start_tick + SimClock.seconds_to_ticks(ExprEval.evaluate(a.duration, ctx))
	z.interval_ticks = maxi(1, SimClock.seconds_to_ticks(ExprEval.evaluate(a.interval, ctx)))
	z.next_tick = z.start_tick
	if z.end_tick > z.start_tick:
		world.zones.append(z)


## Một lần tác dụng của vùng tồn tại: đơn vị hợp lệ có thân chạm vùng, theo id.
static func pulse_zone(world: World, z: ActiveZone) -> void:
	var owner: Entity = z.ctx.owner
	for e: Entity in world.spatial_near(z.center, z.radius, World.Phase.TRIGGER):
		if _area_accepts(z.ctx, owner, e) and e.position.distance_to(z.center) - e.radius <= z.radius:
			var each: ExprContext = z.ctx.with_target(e)
			each.point = z.center
			run(world, z.action.actions, each, z.source_id)


## Chạy vùng: mọi đơn vị địch (không phải công trình) trong vùng, theo id, thành `target`.
static func fire_area(world: World, p: PendingArea) -> void:
	var a: AreaAction = p.action
	var owner: Entity = p.ctx.owner
	var radius: float = ExprEval.evaluate(a.radius, p.ctx)
	var length: float = ExprEval.evaluate(a.length, p.ctx)
	var half_width: float = ExprEval.evaluate(a.width, p.ctx) * 0.5
	var dir: Vector2 = _area_direction(a, p.ctx, owner)
	var start: Vector2 = owner.position
	var reach: float = radius if a.shape != AreaAction.Shape.RECT else length + half_width
	world.recent_areas = world.recent_areas.filter(func(r: Array) -> bool: return world.tick - r[2] < 30)
	var angle: float = ExprEval.evaluate(a.angle, p.ctx) if a.shape == AreaAction.Shape.CONE else 0.0
	world.recent_areas.append([p.center if a.shape == AreaAction.Shape.CIRCLE else start, radius, world.tick, owner.team,
		a.shape, dir.normalized(), angle, length, half_width])  # chỉ cho VIEW (D-144)
	var around: Vector2 = p.center if a.shape == AreaAction.Shape.CIRCLE else start
	for e: Entity in world.spatial_near(around, reach, World.Phase.TRIGGER):
		if not _area_accepts(p.ctx, owner, e) or (a.exclude_target and e == p.ctx.target):
			continue  # ABL-22: đánh lan không trúng lại mục tiêu chính
		if AreaShapes.contains(a, p, e, start, dir, radius, length, half_width):
			var each: ExprContext = p.ctx.with_target(e)
			if not a.falloff.is_empty() and radius > 0.0:  # giảm dần theo khoảng cách tới tâm
				each.scale = 1.0 - ExprEval.evaluate(a.falloff, p.ctx) * clampf(e.position.distance_to(p.center) / radius, 0.0, 1.0)
			run(world, a.actions, each, p.source_id)


## ABL-20 / ABL-22: hướng chọn lúc tung; vùng bỏ mục tiêu chính thì hướng về mục tiêu đó; không thì hướng nhìn.
static func _area_direction(a: AreaAction, ctx: ExprContext, owner: Entity) -> Vector2:
	if ctx.direction != Vector2.ZERO:
		return ctx.direction
	if a.exclude_target and ctx.target != null and ctx.target.position != owner.position:
		return ctx.target.position - owner.position
	return owner.facing


## ABL-07: vùng của kỹ năng lọc theo target_filter; không có kỹ năng → địch không phải công trình (EFF-15).
static func _area_accepts(ctx: ExprContext, owner: Entity, e: Entity) -> bool:
	if ctx.ability != null:
		return Abilities.accepts(owner, ctx.ability, e, false)
	return not Rules.is_structure(e) and e.kind != Entity.Kind.WARD and Rules.is_hittable(owner, e)


## CMB-10: đốt tối đa bằng mana đang có; sự kiện mang lượng thực tế (`event.burned_mana`).
static func _mana_burn(world: World, receiver: Entity, amount: float, source_id: int) -> void:
	var burned: float = clampf(amount, 0.0, receiver.mana)
	receiver.mana -= burned
	world.emit(&"mana_burned", source_id, receiver.id, burned)


## ABL-05: đạn bay từ chủ kỹ năng theo hướng lúc tung (không có thì về phía mục tiêu / hướng nhìn).
static func _skill_shot(world: World, a: ProjectileAction, ctx: ExprContext, source_id: int) -> void:
	var owner: Entity = ctx.owner
	var dir: Vector2 = ctx.direction
	if dir.length() < 0.001 and ctx.target != null and ctx.target != owner:
		dir = ctx.target.position - owner.position
	if dir.length() < 0.001:
		dir = owner.facing
	var s: SkillShot = SkillShot.new()
	s.source_id = source_id
	s.origin = owner.position
	s.position = owner.position
	s.direction = dir.normalized()
	s.speed = ExprEval.evaluate(a.speed, ctx)
	s.max_range = ExprEval.evaluate(a.travel_range, ctx)
	s.half_width = ExprEval.evaluate(a.width, ctx) * 0.5
	s.pierce = ExprEval.evaluate(a.pierce, ctx) != 0.0
	s.actions = a.on_hit
	s.ctx = ctx
	s.team = owner.team
	world.skill_shots.append(s)


## ABL-08: chủ kỹ năng lướt tới đơn vị `target` (DashSystem đi từ tick sau).
static func _dash(world: World, a: DashAction, ctx: ExprContext, source_id: int) -> void:
	var target: Entity = receiver_of(a.target, ctx)
	var owner: Entity = ctx.owner
	if target == null or owner == null or target == owner or not owner.alive:
		return
	var d: DashState = DashState.new()
	d.target_id = target.id
	d.speed = ExprEval.evaluate(a.speed, ctx)
	d.actions = a.on_arrive
	d.ctx = ctx
	d.source_id = source_id
	d.untargetable = a.untargetable  # ABL-08b
	owner.dash = d
	owner.attack_phase = Entity.AttackPhase.NONE
	Effects.refresh_states(owner)
	world.emit(&"dash_started", owner.id, target.id)


## DUL-01: giá trị chụp lúc bắt đầu; bắt đầu được thì chạy on_start với mục tiêu là đối thủ.
static func _duel(world: World, a: DuelAction, ctx: ExprContext, source_id: int) -> void:
	var values: Dictionary[StringName, float] = {
		&"duration": ExprEval.evaluate(a.duration, ctx), &"reflect": ExprEval.evaluate(a.reflect, ctx),
		&"reflect_heal": ExprEval.evaluate(a.reflect_heal, ctx),
		&"win_damage": ExprEval.evaluate(a.win_damage, ctx), &"lose_damage": ExprEval.evaluate(a.lose_damage, ctx),
		&"win_gold": ExprEval.evaluate(a.win_gold, ctx)}
	if Duels.start(world, ctx.owner, ctx.target, values, a.duel_effect, a.self_effect, ctx.values):
		run(world, a.on_start, ctx, source_id)


## ABL-18: cộng `amount` giây vào hồi chiêu còn lại của ô `slot`; không xuống dưới 0.
static func _modify_cooldown(world: World, a: ModifyCooldownAction, ctx: ExprContext, receiver: Entity) -> void:
	var ability: AbilityInstance = Abilities.of(receiver, a.slot)
	if ability == null:
		return
	var delta: int = roundi(ExprEval.evaluate(a.amount, ctx) * SimClock.TICKS_PER_SECOND)
	ability.ready_tick = maxi(world.tick, maxi(ability.ready_tick, world.tick) + delta)


## ABL-10: đẩy `receiver` ra xa chủ kỹ năng; hủy lệnh, lướt, đòn đang vung; miễn phép chặn trừ nguồn xuyên.
static func _push(world: World, a: PushAction, ctx: ExprContext, receiver: Entity, source_id: int) -> void:
	var owner: Entity = ctx.owner
	if receiver.team != owner.team and not _pierces(ctx) and Rules.has_state(receiver, UnitState.Id.MAGIC_IMMUNE):
		return
	var dir: Vector2 = receiver.position - owner.position
	if dir.length() < 0.001:
		dir = ctx.direction if ctx.direction != Vector2.ZERO else owner.facing
	var ticks: int = maxi(1, SimClock.seconds_to_ticks(ExprEval.evaluate(a.duration, ctx)))
	var k: KnockbackState = KnockbackState.new()
	k.direction = dir.normalized()
	k.per_tick = ExprEval.evaluate(a.distance, ctx) / ticks
	k.end_tick = world.tick + ticks
	k.source_id = source_id
	receiver.knockback = k
	receiver.dash = null
	receiver.order = Order.idle()
	receiver.queued_order = null
	receiver.attack_phase = Entity.AttackPhase.NONE
	Effects.refresh_states(receiver)
