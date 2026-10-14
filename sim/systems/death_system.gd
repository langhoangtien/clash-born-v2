class_name DeathSystem
extends SimSystem
## Pha 11: gỡ đơn vị đã chết. Công trình đổ → ghi vào `destroyed_structures`, phát
## `structure_destroyed`, tính lại khóa (STR-02). Hero hồi sinh, thưởng vàng/XP ở M2.4/M2.5.


func run(world: World) -> void:
	var dead: Array[Entity] = world.entities.filter(func(e: Entity) -> bool: return not e.alive)
	var structure_fell: bool = false
	for e: Entity in dead:
		if Rules.is_structure(e):
			world.destroyed_structures[e.structure_id] = true
			world.emit(&"structure_destroyed", -1, e.id)
			structure_fell = true
		world.remove_entity(e)
	if structure_fell:
		Objectives.refresh_locks(world)
