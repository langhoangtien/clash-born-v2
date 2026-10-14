class_name VisionSystem
extends SimSystem
## Pha 4 (VIS-01, 06, 07): đội T thấy đơn vị E khi E cùng đội, hoặc có đơn vị sống của T với
## khoảng cách tâm–tâm tới E ≤ vision_range của nó. E đứng trong bụi thì T chỉ thấy khi T có
## người cùng bụi, hoặc E đang lộ vì vừa ra tay. Kết quả ghi vào `Entity.visible_mask`
## (bit = đội). Rừng/vách không che. World không có hệ thống này thì mọi đơn vị thấy hết
## (mặc định của visible_mask), dùng cho test cơ chế.

## Hằng số kỹ thuật: số đội có tầm nhìn (0, 1, trung lập 2).
const TEAMS: int = 3
const REVEAL_EVENTS: Array[StringName] = [&"attack_started", &"ability_cast"]


func run(world: World) -> void:
	_mark_reveals(world)
	var eyes: Array[PackedVector2Array] = []
	var reach: Array[PackedFloat32Array] = []
	var occupied: Array[Dictionary] = []
	for t: int in range(TEAMS):
		eyes.append(PackedVector2Array())
		reach.append(PackedFloat32Array())
		occupied.append({})
	for o: Entity in world.entities:
		o.bush_id = world.map.bushes.at(o.position) if world.map != null and o.alive else -1
		if not o.alive or o.team < 0 or o.team >= TEAMS:
			continue
		if o.bush_id >= 0:
			occupied[o.team][o.bush_id] = true
		var sight: float = o.stats.get_stat(StatId.Id.VISION_RANGE) if o.stats != null else 0.0
		if sight > 0.0:
			eyes[o.team].append(o.position)
			reach[o.team].append(sight * sight)
	for e: Entity in world.entities:
		var mask: int = 1 << e.team
		if e.alive:
			var hidden: bool = e.bush_id >= 0 and world.tick > e.reveal_until_tick  # VIS-06/07
			for t: int in range(TEAMS):
				if t == e.team:
					continue
				var same_bush: bool = e.bush_id >= 0 and occupied[t].has(e.bush_id)
				if same_bush or (not hidden and _seen(e.position, eyes[t], reach[t])):
					mask |= 1 << t
		e.visible_mask = mask


## VIS-07: ra tay ở tick trước → lộ bush_reveal_time tính từ tick này.
func _mark_reveals(world: World) -> void:
	var ticks: int = SimClock.seconds_to_ticks(world.balance.bush_reveal_time)
	for ev: GameEvent in world.previous_events:
		if REVEAL_EVENTS.has(ev.type):
			var e: Entity = world.find_entity(ev.source_id)
			if e != null:
				e.reveal_until_tick = world.tick - 1 + ticks


static func _seen(at: Vector2, eyes: PackedVector2Array, reach: PackedFloat32Array) -> bool:
	for i: int in range(eyes.size()):
		if at.distance_squared_to(eyes[i]) <= reach[i]:
			return true
	return false
