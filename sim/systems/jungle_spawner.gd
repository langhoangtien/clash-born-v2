class_name JungleSpawner
extends SimSystem
## Pha 12 (JGL-05, 06): mọi trại xuất hiện ở `jungle_first_spawn`; sau đó mỗi
## `jungle_respawn_check` giây, trại trống hồi lại nếu không có đơn vị sống nào trong
## `camp_spawn_box` quanh tâm trại. Quái đứng quanh tâm trại theo thứ tự trong CampDef.
## D-307: trại boss theo `first_spawn` / `respawn` riêng (JGL-10); quái mang hiệu ứng thường trực (JGL-13) và
## mạnh dần theo phút (JGL-12).

## Hằng số kỹ thuật: khoảng cách chỗ đứng của các con quanh tâm trại.
const RING: float = 70.0


func run(world: World) -> void:
	var first: int = SimClock.seconds_to_ticks(world.balance.jungle_first_spawn)
	var every: int = maxi(1, SimClock.seconds_to_ticks(world.balance.jungle_respawn_check))
	var check: bool = world.tick >= first and (world.tick - first) % every == 0
	for c: CampState in world.camps:
		if c.def.is_boss():
			_boss(world, c)
		elif check and (world.tick == first or (c.unit_ids.is_empty() and _clear(world, c))):
			spawn(world, c)
	if world.tick > 0 and world.tick % SimClock.seconds_to_ticks(60.0) == 0:
		for c: CampState in world.camps:
			for id: int in c.unit_ids:
				grow(world, world.find_entity(id))


## JGL-10: lần đầu ở `first_spawn`; sau đó `respawn` giây kể từ lúc trại trống, chờ chỗ trống nếu cần.
static func _boss(world: World, c: CampState) -> void:
	if world.tick < SimClock.seconds_to_ticks(c.def.first_spawn):
		return
	if c.empty_since_tick < 0:
		if world.tick == SimClock.seconds_to_ticks(c.def.first_spawn):
			spawn(world, c)
		elif _all_dead(world, c):
			c.empty_since_tick = world.tick
		return
	if world.tick - c.empty_since_tick >= SimClock.seconds_to_ticks(c.def.respawn) and _clear(world, c):
		spawn(world, c)


static func _all_dead(world: World, c: CampState) -> bool:
	for id: int in c.unit_ids:
		var e: Entity = world.find_entity(id)
		if e != null and e.alive:
			return false
	return true


static func _clear(world: World, c: CampState) -> bool:
	for e: Entity in world.spatial_near(c.center, world.balance.camp_spawn_box, World.Phase.SPAWN, false):
		if e.alive and e.position.distance_to(c.center) <= world.balance.camp_spawn_box:
			return false
	return true


static func spawn(world: World, c: CampState) -> void:
	var n: int = c.def.units.size()
	c.unit_ids.clear()
	for i: int in range(n):
		var def: UnitDef = c.def.units[i]
		var at: Vector2 = c.center if i == 0 else c.center + Vector2.from_angle(TAU * (i - 1) / maxf(1.0, n - 1)) * RING
		at = world.navigation(def.stats.collision_radius).nearest_clear(at)
		var e: Entity = UnitFactory.unit(world, def, Entity.Kind.NEUTRAL, 2, at)
		e.camp_index = c.index
		e.home_point = at
		for p: EffectDef in def.passives:  # JGL-13
			Effects.apply(world, e, p, e)
		grow(world, e)
		e.stats.recompute()
		e.health = e.stats.get_stat(StatId.Id.MAX_HP)
		c.unit_ids.append(e.id)
	c.target_id = -1
	c.returning = false
	c.empty_since_tick = -1


## JGL-12: số tầng hiệu ứng mạnh dần = số phút trọn của trận; máu tối đa tăng thì máu hiện tại tăng theo.
static func grow(world: World, e: Entity) -> void:
	if e == null or not e.alive or e.growth == null:
		return
	var minutes: int = world.tick / SimClock.seconds_to_ticks(60.0)
	if minutes <= 0:
		return
	e.stats.recompute()
	var before: float = e.stats.get_stat(StatId.Id.MAX_HP)
	var inst: EffectInstance = null
	for x: EffectInstance in e.effects:
		if x.def == e.growth:
			inst = x
	if inst == null:
		inst = Effects.apply(world, e, e.growth, e)
	Effects.set_stacks(e, inst, minutes)
	e.stats.recompute()
	e.health += e.stats.get_stat(StatId.Id.MAX_HP) - before
