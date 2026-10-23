class_name AreaShapes
extends RefCounted
## Đơn vị có nằm trong vùng không: tròn (ABL-07), chữ nhật, quạt (ABL-20).


static func contains(a: AreaAction, p: PendingArea, e: Entity, start: Vector2, dir: Vector2,
		radius: float, length: float, half_width: float) -> bool:
	match a.shape:
		AreaAction.Shape.CIRCLE:
			return e.position.distance_to(p.center) - e.radius <= radius
		AreaAction.Shape.CONE:
			return in_cone(e, start, dir, radius, ExprEval.evaluate(a.angle, p.ctx))
	var rel: Vector2 = e.position - start
	var along: float = rel.dot(dir.normalized())
	return along >= -e.radius and along <= length + e.radius and absf(rel.cross(dir.normalized())) <= half_width + e.radius


## ABL-20: mép thân trong bán kính, thân chạm góc `angle_deg` quanh `dir` tính từ `apex`.
static func in_cone(e: Entity, apex: Vector2, dir: Vector2, radius: float, angle_deg: float) -> bool:
	var rel: Vector2 = e.position - apex
	var dist: float = rel.length()
	if dist - e.radius > radius:
		return false
	if dist <= e.radius:
		return true
	var slack: float = asin(clampf(e.radius / dist, 0.0, 1.0))
	return absf(dir.normalized().angle_to(rel)) <= deg_to_rad(angle_deg) * 0.5 + slack
