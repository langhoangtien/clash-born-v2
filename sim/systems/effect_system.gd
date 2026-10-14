class_name EffectSystem
extends SimSystem
## Pha 2: hiệu ứng chạy theo chu kỳ (lần đầu sau một chu kỳ, lần cuối đúng lúc hết hạn) rồi
## gỡ hiệu ứng hết hạn (lý do `expired`). Theo id đơn vị, rồi thứ tự áp (D-30).


func run(world: World) -> void:
	for e: Entity in world.entities:
		if not e.alive or e.effects.is_empty():
			continue
		for inst: EffectInstance in e.effects.duplicate():
			_tick(world, e, inst)


func _tick(world: World, e: Entity, inst: EffectInstance) -> void:
	while inst.period_ticks > 0 and world.tick >= inst.next_period_tick \
			and (inst.end_tick < 0 or inst.next_period_tick <= inst.end_tick):
		inst.next_period_tick += inst.period_ticks
		ActionRunner.run(world, inst.def.periodic_actions, Effects.context(world, e, inst), inst.source_id)
	if inst.end_tick >= 0 and world.tick >= inst.end_tick:
		Effects.remove(world, e, inst, &"expired")
