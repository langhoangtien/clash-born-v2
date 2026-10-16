class_name KnockbackSystem
extends SimSystem
## Pha 6, trước MovementSystem (ABL-10): đơn vị bị đẩy dời `per_tick` mỗi tick theo hướng đã
## chốt, xuyên qua đơn vị khác, dừng sớm khi chạm vách / rừng / thân trụ (không bao giờ
## xuyên vật cản). Hết thời gian hoặc bị chặn → hết bị đẩy, phát `knockback_finished`.


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.knockback != null:
			_advance(world, e)


func _advance(world: World, e: Entity) -> void:
	var k: KnockbackState = e.knockback
	if not e.alive:
		finish(world, e)
		return
	var reached: float = DashSystem.clear_reach(world, e, k.direction, k.per_tick)
	e.position += k.direction * reached
	if reached < k.per_tick - 0.001 or world.tick >= k.end_tick:
		finish(world, e)


static func finish(world: World, e: Entity) -> void:
	var source: int = e.knockback.source_id
	e.knockback = null
	Effects.refresh_states(e)
	world.emit(&"knockback_finished", source, e.id)
