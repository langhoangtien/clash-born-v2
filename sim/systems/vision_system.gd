class_name VisionSystem
extends SimSystem
## Pha 4 (VIS-01..08): ai thấy ai, ghi vào `Entity.visible_mask` (bit = đội). Đội T thấy E
## (khác đội) khi một trong các điều sau đúng, theo thứ tự:
##   1. E bị REVEALED bởi đội T (VIS-08), ở mọi nơi;
##   2. E trong true sight fountain của T (VIS-03);
##   3. E không tàng hình (VIS-02) và: cùng bụi với người của T (VIS-06), hoặc không bị bụi
##      che (ngoài bụi / đang lộ VIS-07) và trong tầm nhìn một đơn vị của T (VIS-01).
## World không có hệ thống này thì mọi đơn vị thấy hết (mặc định của visible_mask).

## Hằng số kỹ thuật: số đội có tầm nhìn (0, 1, trung lập 2).
const TEAMS: int = 3
const REVEAL_EVENTS: Array[StringName] = [&"attack_started", &"ability_cast"]

var _eyes: Array[PackedVector2Array] = []
var _reach: Array[PackedFloat32Array] = []
var _occupied: Array[Dictionary] = []


func run(world: World) -> void:
	_mark_reveals(world)
	_collect(world)
	var sight_sq: float = world.balance.fountain_true_sight * world.balance.fountain_true_sight
	for e: Entity in world.entities:
		var mask: int = 1 << e.team
		if e.alive:
			var revealed: int = _revealed_by(e)
			var invisible: bool = Rules.has_state(e, UnitState.Id.INVISIBLE)
			var covered: bool = e.bush_id >= 0 and world.tick > e.reveal_until_tick
			for t: int in range(TEAMS):
				if t != e.team and (revealed & (1 << t) != 0 or _true_sight(world, t, e, sight_sq) \
						or (not invisible and _plain_seen(e, t, covered))):
					mask |= 1 << t
		e.visible_mask = mask


func _collect(world: World) -> void:
	_eyes.clear()
	_reach.clear()
	_occupied.clear()
	for t: int in range(TEAMS):
		_eyes.append(PackedVector2Array())
		_reach.append(PackedFloat32Array())
		_occupied.append({})
	for o: Entity in world.entities:
		o.bush_id = world.map.bushes.at(o.position) if world.map != null and o.alive else -1
		if not o.alive or o.team < 0 or o.team >= TEAMS:
			continue
		if o.bush_id >= 0:
			_occupied[o.team][o.bush_id] = true
		var sight: float = o.stats.get_stat(StatId.Id.VISION_RANGE) if o.stats != null else 0.0
		if sight > 0.0:
			_eyes[o.team].append(o.position)
			_reach[o.team].append(sight * sight)


## VIS-06 + VIS-01.
func _plain_seen(e: Entity, t: int, covered: bool) -> bool:
	if e.bush_id >= 0 and _occupied[t].has(e.bush_id):
		return true
	return not covered and _seen(e.position, _eyes[t], _reach[t])


## VIS-08: các đội thấy E nhờ REVEALED (đội kẻ áp; không có kẻ áp thì mọi đội khác).
static func _revealed_by(e: Entity) -> int:
	if not Rules.has_state(e, UnitState.Id.REVEALED):
		return 0
	var bits: int = 0
	for inst: EffectInstance in e.effects:
		if inst.active_tick < 0 and inst.def.states.has(UnitState.Id.REVEALED):
			bits |= ~(1 << e.team) if inst.source_team < 0 or inst.source_team == e.team else 1 << inst.source_team
	return bits


## VIS-03: true sight quanh fountain của đội `t` (chỉ hai đội có fountain).
static func _true_sight(world: World, t: int, e: Entity, sight_sq: float) -> bool:
	if world.map == null or t > 1 or world.map.fountain_points.size() <= t:
		return false
	return e.position.distance_squared_to(world.map.fountain_point(t)) <= sight_sq


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
