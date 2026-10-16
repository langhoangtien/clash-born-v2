class_name DashSystem
extends SimSystem
## Pha 6, trước MovementSystem (ABL-08, D-74): đơn vị đang lướt đi thẳng về phía mục tiêu,
## xuyên qua đơn vị khác; chạm mép thì chạy `on_arrive`. Dừng sớm (không chạy) khi gặp
## vật cản, bị STUNNED, mục tiêu mất hoặc không còn nhắm được. Lướt xong thì làm lệnh đã chờ.

## Hằng số kỹ thuật: bước dò địa hình dọc đường lướt.
const TERRAIN_STEP: float = 16.0


func run(world: World) -> void:
	for e: Entity in world.entities:
		if e.dash != null:
			_advance(world, e)


func _advance(world: World, e: Entity) -> void:
	var target: Entity = world.find_entity(e.dash.target_id)
	if not e.alive or Rules.has_state(e, UnitState.Id.STUNNED) or not _valid(e, target):
		_end(e)
		return
	var gap: float = maxf(0.0, Rules.edge_distance(e, target))
	var dir: Vector2 = (target.position - e.position).normalized()
	var move: float = minf(e.dash.speed * SimClock.TICK_SECONDS, gap)
	var reached: float = clear_reach(world, e, dir, move)
	e.position += dir * reached
	if dir != Vector2.ZERO:
		e.facing = dir
	if reached < move - 0.001:
		_end(e)  # vướng vách / rừng / thân trụ
		return
	if move >= gap - 0.001:
		var d: DashState = e.dash
		_end(e)
		world.emit(&"dash_arrived", e.id, target.id)
		ActionRunner.run(world, d.actions, d.ctx.with_target(target), d.source_id)


static func _valid(e: Entity, target: Entity) -> bool:
	if target == null or not target.alive:
		return false
	return target.team == e.team or Rules.is_targetable(e, target)


## Quãng đi được dọc `dir` (≤ `move`) mà không chạm vật cản.
static func clear_reach(world: World, e: Entity, dir: Vector2, move: float) -> float:
	if world.map == null:
		return move
	var nav: MapNavigation = world.navigation(e.radius)
	var d: float = TERRAIN_STEP
	while d < move + TERRAIN_STEP:
		var at: float = minf(d, move)
		if not nav.point_is_clear(e.position + dir * at):
			return maxf(0.0, at - TERRAIN_STEP)
		d += TERRAIN_STEP
	return move


static func _end(e: Entity) -> void:
	e.dash = null
	Effects.refresh_states(e)
	if e.queued_order != null:
		e.order = e.queued_order
		e.queued_order = null
