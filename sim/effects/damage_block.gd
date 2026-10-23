class_name DamageBlock
extends RefCounted
## CMB-15 (D-137): chặn sát thương đòn đánh (kiểu khiên Vanguard). Mỗi nguồn chặn trên mục tiêu
## tung PRD riêng; nhiều nguồn trúng thì lấy lượng chặn lớn nhất. Trừ vào sát thương trước giáp.


static func amount(world: World, attacker: Entity, target: Entity) -> float:
	var best: float = 0.0
	for inst: EffectInstance in target.effects:
		var d: EffectDef = inst.def
		if d.block_chance.is_empty():
			continue
		if d.tags.has(&"passive") and Rules.has_state(target, UnitState.Id.HEXED):
			continue  # ST-16
		var ctx: ExprContext = Effects.context(world, target, inst)
		if not Prd.roll(world, Prd.key(target.id, inst.serial * 16 + 14), ExprEval.evaluate(d.block_chance, ctx)):
			continue
		var value: float = ExprEval.evaluate(d.block_amount, ctx)
		if attacker != null and attacker.projectile_speed > 0.0 and not d.block_ranged.is_empty():
			value *= ExprEval.evaluate(d.block_ranged, ctx)
		best = maxf(best, value)
	return best
