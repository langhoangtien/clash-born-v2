class_name SkillShotSystem
extends SimSystem
## Pha 7 (sau AbilitySystem): đạn kỹ năng bay (ABL-05). Mỗi tick: đi tối đa speed × tick, không
## quá tầm; gặp vách/rừng thì đoạn bay dừng ở đó và đạn mất. Đơn vị hợp lệ có thân chạm dải đạn
## quét qua bị trúng theo thứ tự dọc đường bay (hòa: id nhỏ); không xuyên thì chỉ kẻ đầu tiên.

## Hằng số kỹ thuật: bước dò địa hình dọc đường bay.
const TERRAIN_STEP: float = 16.0


func run(world: World) -> void:
	if world.skill_shots.is_empty():
		return
	var flying: Array[SkillShot] = []
	for s: SkillShot in world.skill_shots:
		if _advance(world, s):
			flying.append(s)
	world.skill_shots = flying


## Trả về false khi đạn kết thúc.
func _advance(world: World, s: SkillShot) -> bool:
	var length: float = minf(s.speed * SimClock.TICK_SECONDS, s.max_range - s.travelled)
	var blocked: float = _first_blocked(world, s.position, s.direction, length)
	var reach: float = blocked if blocked >= 0.0 else length
	var start: Vector2 = s.position
	for e: Entity in _hits(world, s, start, reach):
		s.hit_ids[e.id] = true
		var ctx: ExprContext = s.ctx.with_target(e)
		ctx.point = e.position
		ActionRunner.run(world, s.actions, ctx, s.source_id)
		world.emit(&"projectile_hit", s.source_id, e.id)
		if not s.pierce:
			return false
	s.position = start + s.direction * reach
	s.travelled += reach
	return blocked < 0.0 and s.travelled < s.max_range - 0.001


func _first_blocked(world: World, from: Vector2, dir: Vector2, length: float) -> float:
	if world.map == null:
		return -1.0
	var d: float = TERRAIN_STEP
	while d < length + TERRAIN_STEP:
		var at: float = minf(d, length)
		if world.map.clearance_at(from + dir * at) <= 0.0:
			return maxf(0.0, at - TERRAIN_STEP)
		d += TERRAIN_STEP
	return -1.0


func _hits(world: World, s: SkillShot, start: Vector2, reach: float) -> Array[Entity]:
	var found: Array = []
	var middle: Vector2 = start + s.direction * reach * 0.5
	var owner: Entity = s.ctx.owner
	for e: Entity in world.spatial_near(middle, reach * 0.5 + s.half_width, World.Phase.ABILITY):
		if s.hit_ids.has(e.id) or not _accepts(s, owner, e):
			continue
		var rel: Vector2 = e.position - start
		var along: float = rel.dot(s.direction)
		if along < -e.radius or along > reach + e.radius:
			continue
		if absf(rel.cross(s.direction)) <= s.half_width + e.radius:
			found.append([along, e])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1].id < b[1].id))
	var out: Array[Entity] = []
	for pair: Array in found:
		out.append(pair[1])
	return out


func _accepts(s: SkillShot, owner: Entity, e: Entity) -> bool:
	if s.ctx.ability != null:
		return Abilities.accepts(owner, s.ctx.ability, e)
	return not Rules.is_structure(e) and e.alive and e.team != s.team and not e.locked
