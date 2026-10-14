class_name DeathSystem
extends SimSystem
## Pha 11: gỡ đơn vị đã chết khỏi trận. Hero hồi sinh, thưởng vàng/XP thêm ở M2.4 / M2.5.


func run(world: World) -> void:
	var dead: Array[Entity] = world.entities.filter(func(e: Entity) -> bool: return not e.alive)
	for e: Entity in dead:
		world.remove_entity(e)
