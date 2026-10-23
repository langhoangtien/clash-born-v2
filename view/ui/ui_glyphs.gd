class_name UiGlyphs
extends RefCounted
## Icon giao diện vẽ bằng nét (D-130), dùng tới khi có ảnh `ui_<name>`: giỏ hàng, đóng, các thẻ
## danh mục shop. `s` = nửa cạnh ô icon.


static func draw(c: CanvasItem, name: StringName, at: Vector2, s: float, col: Color) -> void:
	var w: float = maxf(2.0, s * 0.16)
	match name:
		&"cart":
			c.draw_polyline(_p(at, s, [[-1, -0.7], [-0.7, -0.7], [-0.45, 0.35], [0.75, 0.35], [0.95, -0.4], [-0.6, -0.4]]), col, w, true)
			c.draw_circle(at + Vector2(-0.3, 0.75) * s, s * 0.14, col)
			c.draw_circle(at + Vector2(0.6, 0.75) * s, s * 0.14, col)
		&"close":
			c.draw_line(at + Vector2(-0.7, -0.7) * s, at + Vector2(0.7, 0.7) * s, col, w * 1.3, true)
			c.draw_line(at + Vector2(0.7, -0.7) * s, at + Vector2(-0.7, 0.7) * s, col, w * 1.3, true)
		&"cat_all":
			for k: Vector2 in [Vector2(-1, -1), Vector2(0.15, -1), Vector2(-1, 0.15), Vector2(0.15, 0.15)]:
				c.draw_rect(Rect2(at + k * s * 0.85, Vector2(s, s) * 0.72), col)
		&"cat_basic":
			_sword(c, at, s, col, w, -0.785)
		&"cat_attack":
			_sword(c, at, s, col, w, -0.785)
			_sword(c, at, s, col, w, 0.785)
		&"cat_magic":
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in range(40):
				var t: float = i / 39.0 * TAU * 1.6
				pts.append(at + Vector2.from_angle(t) * s * (0.15 + 0.55 * i / 39.0))
			c.draw_polyline(pts, col, w, true)
		&"cat_defense":
			c.draw_polyline(_p(at, s, [[-0.75, -0.75], [0, -0.95], [0.75, -0.75], [0.7, 0.1], [0, 0.95], [-0.7, 0.1], [-0.75, -0.75]]), col, w, true)
		&"cat_utility":
			c.draw_polyline(_p(at, s, [[-0.35, -0.95], [0.15, -0.95], [0.15, 0.2], [0.9, 0.45], [0.9, 0.9], [-0.35, 0.9], [-0.35, -0.95]]), col, w, true)
		&"cat_secret":
			c.draw_polyline(_p(at, s, [[-0.9, -0.2], [0, -0.75], [0.9, -0.2], [0.9, 0.7], [-0.9, 0.7], [-0.9, -0.2], [0.9, -0.2]]), col, w, true)
		_:
			c.draw_circle(at, s * 0.4, col)


static func _sword(c: CanvasItem, at: Vector2, s: float, col: Color, w: float, angle: float) -> void:
	var d: Vector2 = Vector2.from_angle(angle)
	var n: Vector2 = Vector2(-d.y, d.x)
	c.draw_line(at - d * s * 0.85, at + d * s * 0.95, col, w * 1.2, true)
	c.draw_line(at - d * s * 0.45 - n * s * 0.35, at - d * s * 0.45 + n * s * 0.35, col, w, true)


static func _p(at: Vector2, s: float, pts: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for q: Array in pts:
		out.append(at + Vector2(q[0], q[1]) * s)
	return out
