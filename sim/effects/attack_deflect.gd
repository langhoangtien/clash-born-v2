class_name AttackDeflect
extends RefCounted
## CMB-15 (D-143): khiên hất đòn — đòn đánh thường trúng (không né) có xác suất (PRD) bị hất ngược:
## mục tiêu không nhận gì (như đòn trượt), kẻ đánh nhận `phần` × sát thương đòn trước giáp.
## Nhiều nguồn: nguồn đầu tiên trúng tính (theo thứ tự áp).


## Yêu cầu sát thương hất ngược (null = không hất).
static func check(world: World, r: DamageRequest, attacker: Entity, target: Entity) -> DamageRequest:
	if not r.is_attack or r.reflected or attacker == null:
		return null
	for inst: EffectInstance in target.effects:
		var d: EffectDef = inst.def
		if d.deflect_chance.is_empty():
			continue
		if d.tags.has(&"passive") and Rules.has_state(target, UnitState.Id.HEXED):
			continue  # ST-16
		var ctx: ExprContext = Effects.context(world, target, inst)
		if not Prd.roll(world, Prd.key(target.id, inst.serial * 16 + 14), ExprEval.evaluate(d.deflect_chance, ctx)):
			continue
		var back: DamageRequest = DamageRequest.new()
		back.source_id = target.id
		back.target_id = attacker.id
		back.raw = r.raw * ExprEval.evaluate(d.deflect_fraction, ctx)
		back.reflected = true  # CMB-09
		return back
	return null
