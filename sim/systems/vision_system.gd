class_name VisionSystem
extends SimSystem
## Pha 4 (VIS-01): đội T thấy đơn vị E khi E cùng đội, hoặc có đơn vị sống của T với
## khoảng cách tâm–tâm tới E ≤ vision_range của nó. Kết quả ghi vào `Entity.visible_mask`
## (bit = đội). Rừng/vách không che. World không có hệ thống này thì mọi đơn vị thấy hết
## (mặc định của visible_mask), dùng cho test cơ chế.

## Hằng số kỹ thuật: số đội có tầm nhìn (0, 1, trung lập 2).
const TEAMS: int = 3


func run(world: World) -> void:
	var eyes: Array[PackedVector2Array] = []
	var reach: Array[PackedFloat32Array] = []
	for t: int in range(TEAMS):
		eyes.append(PackedVector2Array())
		reach.append(PackedFloat32Array())
	for o: Entity in world.entities:
		if o.alive and o.stats != null and o.team >= 0 and o.team < TEAMS:
			var sight: float = o.stats.get_stat(StatId.Id.VISION_RANGE)
			if sight > 0.0:
				eyes[o.team].append(o.position)
				reach[o.team].append(sight * sight)
	for e: Entity in world.entities:
		var mask: int = 1 << e.team
		if e.alive:
			for t: int in range(TEAMS):
				if t != e.team and _seen(e.position, eyes[t], reach[t]):
					mask |= 1 << t
		e.visible_mask = mask


static func _seen(at: Vector2, eyes: PackedVector2Array, reach: PackedFloat32Array) -> bool:
	for i: int in range(eyes.size()):
		if at.distance_squared_to(eyes[i]) <= reach[i]:
			return true
	return false
