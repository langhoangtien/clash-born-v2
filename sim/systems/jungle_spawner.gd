class_name JungleSpawner
extends SimSystem
## Pha 12 (JGL-05, 06): mọi trại xuất hiện ở `jungle_first_spawn`; sau đó mỗi
## `jungle_respawn_check` giây, trại trống hồi lại nếu không có đơn vị sống nào trong
## `camp_spawn_box` quanh tâm trại. Quái đứng quanh tâm trại theo thứ tự trong CampDef.

## Hằng số kỹ thuật: khoảng cách chỗ đứng của các con quanh tâm trại.
const RING: float = 70.0


func run(world: World) -> void:
	var first: int = SimClock.seconds_to_ticks(world.balance.jungle_first_spawn)
	var every: int = maxi(1, SimClock.seconds_to_ticks(world.balance.jungle_respawn_check))
	if world.tick < first or (world.tick - first) % every != 0:
		return
	for c: CampState in world.camps:
		if world.tick == first or (c.unit_ids.is_empty() and _clear(world, c)):
			spawn(world, c)


static func _clear(world: World, c: CampState) -> bool:
	for e: Entity in world.spatial_near(c.center, world.balance.camp_spawn_box, World.Phase.SPAWN, false):
		if e.alive and e.position.distance_to(c.center) <= world.balance.camp_spawn_box:
			return false
	return true


static func spawn(world: World, c: CampState) -> void:
	var n: int = c.def.units.size()
	for i: int in range(n):
		var def: UnitDef = c.def.units[i]
		var at: Vector2 = c.center if i == 0 else c.center + Vector2.from_angle(TAU * (i - 1) / maxf(1.0, n - 1)) * RING
		at = world.navigation(def.stats.collision_radius).nearest_clear(at)
		var e: Entity = UnitFactory.unit(world, def, Entity.Kind.NEUTRAL, 2, at)
		e.camp_index = c.index
		e.home_point = at
		c.unit_ids.append(e.id)
	c.target_id = -1
	c.returning = false
