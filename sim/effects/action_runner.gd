class_name ActionRunner
extends RefCounted
## Thực thi hành động (ARCHITECTURE 3.5). M3.1 có Damage và Heal (dùng cho periodic);
## các loại khác thêm ở M3.3.


static func run(world: World, actions: Array[ActionDef], ctx: ExprContext, source_id: int) -> void:
	for action: ActionDef in actions:
		var receiver: Entity = ctx.owner if action.target == ActionDef.Target.SELF else ctx.target
		if receiver == null or not receiver.alive:
			continue
		if action is DamageAction:
			var d: DamageAction = action
			var r: DamageRequest = DamageRequest.new()
			r.source_id = source_id
			r.target_id = receiver.id
			r.raw = ExprEval.evaluate(d.amount, ctx)
			r.damage_type = d.damage_type
			world.damage_requests.append(r)
		elif action is HealAction:
			heal(world, receiver, ExprEval.evaluate((action as HealAction).amount, ctx), source_id)
		else:
			push_error("ActionRunner: %s chưa làm (M3.3)" % action.get_script().get_global_name())


## Hồi máu, không quá máu tối đa.
static func heal(_world: World, e: Entity, amount: float, _source_id: int) -> void:
	e.health = minf(e.stats.get_stat(StatId.Id.MAX_HP), e.health + maxf(0.0, amount))
