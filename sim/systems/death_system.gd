class_name DeathSystem
extends SimSystem
## Pha 11: gỡ đơn vị đã chết. Công trình đổ → ghi vào `destroyed_structures`, phát
## `structure_destroyed`, tính lại khóa (STR-02). Hero không bị gỡ: chờ rồi hồi sinh ở
## fountain (ECO-04). Thưởng vàng/XP ở M2.5.


func run(world: World) -> void:
	var structure_fell: bool = false
	var gone: Array[Entity] = []
	for e: Entity in world.entities:
		if e.alive:
			continue
		if e.kind == Entity.Kind.HERO:
			_hero_waits(world, e)
			continue
		if Rules.is_structure(e):
			world.destroyed_structures[e.structure_id] = true
			world.emit(&"structure_destroyed", -1, e.id)
			structure_fell = true
		gone.append(e)
	for e: Entity in gone:
		world.remove_entity(e)
	if structure_fell:
		Objectives.refresh_locks(world)


func _hero_waits(world: World, e: Entity) -> void:
	if e.respawn_tick < 0:
		var wait: float = world.balance.respawn_base + world.balance.respawn_per_level * e.stats.level()
		e.respawn_tick = world.tick + SimClock.seconds_to_ticks(wait)
		e.order = Order.idle()
		e.path = PackedVector2Array()
		e.path_index = 0
		e.attack_phase = Entity.AttackPhase.NONE
		e.lock_target_id = -1
		world.emit(&"hero_died", -1, e.id)
	elif world.tick >= e.respawn_tick:
		_respawn(world, e)


func _respawn(world: World, e: Entity) -> void:
	e.respawn_tick = -1
	e.alive = true
	if world.map != null:
		e.position = world.map.fountain_point(e.team)
	e.health = e.stats.get_stat(StatId.Id.MAX_HP)
	e.mana = e.stats.get_stat(StatId.Id.MAX_MANA)
	e.order = Order.idle()
	world.emit(&"hero_respawned", -1, e.id)
