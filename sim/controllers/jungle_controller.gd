class_name JungleController
extends SimSystem
## Pha 5: quái rừng theo trại (JGL-01..04, D-76). IDLE đứng yên; bị gây sát thương → cả trại
## đánh kẻ gây sát thương gần đây nhất (AGGRO); mục tiêu mất / ra ngoài leash / hết
## `jungle_aggro_time` → RETURN_HOME: mỗi con về chỗ đứng, bỏ qua mọi đòn, tới nơi hồi đầy máu.

## Hằng số kỹ thuật: cách chỗ đứng chừng này coi như đã về tới.
const ARRIVE: float = 16.0


func run(world: World) -> void:
	for c: CampState in world.camps:
		var members: Array[Entity] = _alive(world, c)
		if members.is_empty():
			c.target_id = -1
			c.returning = false
			continue
		if c.returning:
			_return(world, c, members)
			continue
		_note_hits(world, c)
		if c.target_id >= 0:
			_aggro(world, c, members)


func _alive(world: World, c: CampState) -> Array[Entity]:
	var out: Array[Entity] = []
	var ids: Array[int] = []
	for id: int in c.unit_ids:
		var e: Entity = world.find_entity(id)
		if e != null and e.alive:
			out.append(e)
			ids.append(id)
	c.unit_ids = ids
	return out


## JGL-01: đòn ở tick trước lên quái của trại → mục tiêu = kẻ gây gần đây nhất.
func _note_hits(world: World, c: CampState) -> void:
	for ev: GameEvent in world.previous_events:
		if ev.type != &"damage_taken" or not c.unit_ids.has(ev.target_id):
			continue
		var source: Entity = world.find_entity(ev.source_id)
		if source != null and source.alive and source.team != 2:
			c.target_id = source.id
			c.aggro_until_tick = world.tick + SimClock.seconds_to_ticks(world.balance.jungle_aggro_time)


func _aggro(world: World, c: CampState, members: Array[Entity]) -> void:
	var target: Entity = world.find_entity(c.target_id)
	var leash: float = world.balance.jungle_leash
	var lost: bool = target == null or not Rules.is_attackable(members[0], target) or world.tick > c.aggro_until_tick \
		or target.position.distance_to(c.center) > leash
	for e: Entity in members:
		lost = lost or e.position.distance_to(c.center) > leash
	if lost:
		_start_return(world, c, members)
		return
	for e: Entity in members:
		if e.order.type != Order.Type.ATTACK or e.order.target_id != target.id or e.order.finished:
			world.submit(Command.attack(e.id, target.id))


func _start_return(world: World, c: CampState, members: Array[Entity]) -> void:
	c.target_id = -1
	c.returning = true
	for e: Entity in members:
		world.submit(Command.move_to(e.id, e.home_point))


## JGL-02: về chỗ đứng; tới nơi thì hồi đầy máu và đứng yên; cả trại tới thì xong.
func _return(world: World, c: CampState, members: Array[Entity]) -> void:
	var home: bool = true
	for e: Entity in members:
		if e.position.distance_to(e.home_point) <= ARRIVE or (e.order.type == Order.Type.MOVE and e.order.finished):
			e.health = e.stats.get_stat(StatId.Id.MAX_HP)
			if e.order.type != Order.Type.IDLE:
				world.submit(Command.stop(e.id))
		else:
			home = false
			if e.order.type != Order.Type.MOVE:
				world.submit(Command.move_to(e.id, e.home_point))
	if home:
		c.returning = false
