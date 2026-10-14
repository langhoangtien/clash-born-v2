class_name StructureController
extends SimSystem
## Pha 5: trụ chọn mục tiêu (STR-01), sinh Command cho tick sau. Thứ tự: (1) hero địch vừa
## gây giao tranh hero lên hero phe trụ, cả hai trong tầm, trong `tower_aggro_time`;
## (2) giữ mục tiêu hiện tại nếu còn trong tầm và nhắm được; (3) lính địch gần nhất;
## (4) hero địch gần nhất. Hòa khoảng cách → id nhỏ hơn.


func run(world: World) -> void:
	for tower: Entity in world.entities:
		if tower.kind == Entity.Kind.TOWER and tower.alive:
			_remember_aggro(world, tower)
			_choose(world, tower)


func _remember_aggro(world: World, tower: Entity) -> void:
	for ev: GameEvent in world.previous_hero_fights():
		var attacker: Entity = world.find_entity(ev.source_id)
		var victim: Entity = world.find_entity(ev.target_id)
		if attacker == null or victim == null or victim.team != tower.team:
			continue
		if Rules.in_attack_range(tower, attacker) and Rules.in_attack_range(tower, victim):
			tower.aggro_target_id = attacker.id
			tower.aggro_until_tick = world.tick + SimClock.seconds_to_ticks(world.balance.tower_aggro_time)


func _choose(world: World, tower: Entity) -> void:
	var pick: Entity = _valid(world, tower, tower.aggro_target_id) if world.tick <= tower.aggro_until_tick else null
	if pick == null and tower.order.type == Order.Type.ATTACK and not tower.order.finished:
		pick = _valid(world, tower, tower.order.target_id)
	if pick == null:
		var nearby: Array[Entity] = _in_range(world, tower)
		pick = _nearest(tower, nearby, Entity.Kind.LANE_CREEP)
		if pick == null:
			pick = _nearest(tower, nearby, Entity.Kind.HERO)
	var current: int = tower.order.target_id if tower.order.type == Order.Type.ATTACK and not tower.order.finished else -1
	if pick != null and pick.id != current:
		world.submit(Command.attack(tower.id, pick.id))
	elif pick == null and current != -1:
		world.submit(Command.stop(tower.id))


func _valid(world: World, tower: Entity, id: int) -> Entity:
	var e: Entity = world.find_entity(id)
	return e if Rules.is_targetable(tower, e) and Rules.in_attack_range(tower, e) else null


func _in_range(world: World, tower: Entity) -> Array[Entity]:
	var out: Array[Entity] = []
	var reach: float = tower.stats.get_stat(StatId.Id.ATTACK_RANGE) + tower.radius
	for e: Entity in world.spatial_near(tower.position, reach, World.Phase.CONTROLLER, false):
		if Rules.is_targetable(tower, e) and Rules.in_attack_range(tower, e):
			out.append(e)
	return out


func _nearest(tower: Entity, candidates: Array[Entity], kind: Entity.Kind) -> Entity:
	var best: Entity = null
	var best_d: float = INF
	for e: Entity in candidates:
		if e.kind != kind:
			continue
		var d: float = Rules.edge_distance(tower, e)
		if d < best_d or (d == best_d and e.id < best.id):
			best = e
			best_d = d
	return best
