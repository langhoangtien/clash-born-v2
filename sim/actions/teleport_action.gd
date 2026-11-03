class_name TeleportAction
extends ActionDef
## Tốc biến (ABL-24, D-226): chủ dịch chuyển tức thời đúng `distance` theo hướng nhắm; điểm đến bị chặn thì lùi
## dần về phía điểm đi tới chỗ đứng được đầu tiên.

## Hằng số kỹ thuật: bước lùi khi tìm chỗ đứng được (đơn vị thế giới).
const BACKOFF_STEP: float = 16.0

@export var distance: String


static func run(world: World, a: TeleportAction, ctx: ExprContext) -> void:
	var owner: Entity = ctx.owner
	if owner == null or not owner.alive:
		return
	var dir: Vector2 = ctx.direction
	if dir == Vector2.ZERO and ctx.point.is_finite():
		dir = ctx.point - owner.position
	dir = dir.normalized() if dir != Vector2.ZERO else owner.facing
	var full: float = maxf(0.0, ExprEval.evaluate(a.distance, ctx))
	var dest: Vector2 = owner.position
	var nav: MapNavigation = world.navigation(owner.radius) if world.map != null else null
	var d: float = full
	while d > 0.0:
		var p: Vector2 = owner.position + dir * d
		if nav == null or nav.point_is_clear(p):
			dest = p
			break
		d -= BACKOFF_STEP
	owner.position = dest
	owner.facing = dir
	owner.attack_phase = Entity.AttackPhase.NONE  # CMB-06: hủy vung tay
	owner.order = Order.idle()
	owner.path = PackedVector2Array()
	owner.path_index = 0
	world.emit(&"teleported", owner.id, owner.id)
