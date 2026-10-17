class_name Recall
extends SimSystem
## RCL-01..02 (pha DAMAGE, sau DamageSystem): về thành — kênh rồi dịch chuyển về fountain.


static func start(world: World, e: Entity) -> void:
	e.order = Order.idle()
	e.queued_order = null
	e.path = PackedVector2Array()
	e.path_index = 0
	e.attack_phase = Entity.AttackPhase.NONE
	e.recall_start_tick = world.tick
	e.recall_until_tick = world.tick + SimClock.seconds_to_ticks(world.balance.recall_time)
	world.emit(&"recall_started", e.id, e.id)


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.recall_until_tick < 0:
			continue
		if not e.alive or not Rules.can_use_item(e) or _hurt(world, e):
			e.recall_until_tick = -1
			world.emit(&"recall_cancelled", e.id, e.id)
		elif world.tick >= e.recall_until_tick:
			e.recall_until_tick = -1
			var home: Vector2 = world.map.fountain_point(e.team) if world.map != null else e.position
			e.position = world.navigation(e.radius).nearest_clear(home) if world.map != null else home
			e.order = Order.idle()
			world.emit(&"recall_finished", e.id, e.id)


static func _hurt(world: World, e: Entity) -> bool:
	for ev: GameEvent in world.events:
		if ev.type == &"damage_taken" and ev.target_id == e.id and ev.amount > 0.0:
			return true
	return false
