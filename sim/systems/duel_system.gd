class_name DuelSystem
extends SimSystem
## Pha STATE (D-135): Quyết Đấu hết giờ thì kết thúc không ai thắng (DUL-02); còn thì ép hai
## bên đánh nhau (DUL-03). Chết thì DamageSystem gọi Duels.on_death (DUL-05).


func run(world: World) -> void:
	for e: Entity in world.entities:
		var d: DuelState = e.duel
		if d == null or d.knight_id != e.id and world.find_entity(d.knight_id) != null:
			continue  # mỗi Quyết Đấu xử lý một lần, theo hiệp sĩ
		if world.tick >= d.end_tick:
			Duels.finish(world, d, null)
		else:
			Duels.force_orders(world, d)
