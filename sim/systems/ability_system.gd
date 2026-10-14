class_name AbilitySystem
extends SimSystem
## Pha 7: dùng chiêu (ABL-02, ABL-03, D-59). Lệnh CAST: kiểm tra lại điều kiện; chiêu nhắm
## đơn vị ngoài tầm thì chờ MovementSystem đưa tới. Bắt đầu tung: trừ mana, tính hồi chiêu,
## phát `ability_cast`; hết `cast_time` thì chạy on_cast, phát `ability_finished`. Bị
## STUNNED/SILENCED khi đang tung → hủy, không hoàn mana. Tung xong (hoặc hủy) thì áp lệnh chờ.


func run(world: World) -> void:
	for e: Entity in world.entities:
		if not e.alive:
			if e.cast != null:
				_end(e, true)
			continue
		if e.cast != null:
			_continue(world, e)
		elif e.order.type == Order.Type.CAST and not e.order.finished:
			_try_start(world, e)


func _try_start(world: World, e: Entity) -> void:
	var a: AbilityInstance = Abilities.of(e, e.order.slot)
	if Abilities.problem(world, e, a) != Abilities.Problem.NONE:
		e.order.finished = true  # điều kiện đổi trong lúc đi tới (hết mana, bị câm…)
		return
	var target: Entity = null
	if a.def.targeting == AbilityDef.Targeting.UNIT:
		target = world.find_entity(e.order.target_id)
		if not Abilities.accepts(e, a.def, target):
			e.order.finished = true
			return
		if not in_cast_range(e, a, target):
			return  # MovementSystem đưa tới tầm
	e.mana -= Abilities.value(e, a, &"mana")
	a.ready_tick = world.tick + SimClock.seconds_to_ticks(Abilities.value(e, a, &"cooldown"))
	var c: CastState = CastState.new()
	c.ability = a
	c.target_id = target.id if target != null else -1
	c.point = e.order.point
	c.direction = e.order.direction
	var cast_time: float = ExprEval.evaluate(a.def.cast_time, Abilities.context(e, a, e))
	c.release_tick = world.tick + SimClock.seconds_to_ticks(cast_time)
	e.cast = c
	e.attack_phase = Entity.AttackPhase.NONE
	_face(e, c, target)
	world.emit(&"ability_cast", e.id, c.target_id, a.slot)
	if world.tick >= c.release_tick:
		_release(world, e)


func _continue(world: World, e: Entity) -> void:
	if not Rules.can_cast(e):
		_end(e, true)  # ABL-03: hủy, không hoàn mana
	elif world.tick >= e.cast.release_tick:
		_release(world, e)


func _release(world: World, e: Entity) -> void:
	var c: CastState = e.cast
	var target: Entity = world.find_entity(c.target_id) if c.target_id >= 0 else e
	if c.target_id >= 0 and (target == null or not target.alive):
		_end(e, true)  # mục tiêu biến mất trước khi chiêu ra
		return
	var ctx: ExprContext = Abilities.context(e, c.ability, target)
	ctx.point = c.point
	ctx.direction = c.direction if c.direction != Vector2.ZERO else e.facing
	ActionRunner.run(world, c.ability.def.on_cast, ctx, e.id)
	world.emit(&"ability_finished", e.id, c.target_id, c.ability.slot)
	_end(e, false)


func _end(e: Entity, _cancelled: bool) -> void:
	e.cast = null
	if e.order.type == Order.Type.CAST:
		e.order.finished = true
	if e.queued_order != null:
		e.order = e.queued_order
		e.queued_order = null


func _face(e: Entity, c: CastState, target: Entity) -> void:
	var toward: Vector2 = Vector2.ZERO
	if target != null and target != e:
		toward = target.position - e.position
	elif c.point.is_finite():
		toward = c.point - e.position
	elif c.direction != Vector2.ZERO:
		toward = c.direction
	if toward.length() > 0.001:
		e.facing = toward.normalized()


## Tầm chiêu nhắm đơn vị: mép–mép ≤ cast_range (0 = không giới hạn).
static func in_cast_range(e: Entity, a: AbilityInstance, target: Entity) -> bool:
	var reach: float = Abilities.value(e, a, &"cast_range")
	return reach <= 0.0 or Rules.edge_distance(e, target) <= reach
