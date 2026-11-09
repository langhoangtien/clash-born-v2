class_name GroundMarks
extends RefCounted
## D-180: dấu cố định trên mặt đất trận 3D, dựng một lần vào GroundCanvas (thay các lớp Bushes / Shops /
## Overlay của MapView từng vẽ vào lớp 2D): vùng bụi (VIS-06, tô + viền), vòng mua quanh shop (SHOP-02),
## vòng trại. Hình 3D (bụi, shop, trụ) do Scenery3D / Actor3D vẽ.

const MapPainter = preload("res://view/map/map_painter.gd")


static func paint(c: GroundCanvas, layout: MapLayout, shop_radius: float) -> void:
	c.begin()
	for poly: PackedVector2Array in layout.bushes.polygons:
		c.draw_colored_polygon(poly, MapPainter.BUSH)
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		c.draw_polyline(closed, MapPainter.BUSH_DARK, 10.0)
	for p: Vector2 in layout.shop_points:
		c.draw_arc(p, shop_radius, 0, TAU, 64, Color(1.0, 0.8, 0.2, 0.35), 6.0)
	for i: int in layout.camp_points.size():
		var p: Vector2 = layout.camp_points[i]
		c.draw_arc(p, 48, 0, TAU, 28, MapView.GOLD, 6.0)
		if layout.camp_sides[i] < 0:
			_rune_circle(c, p)
	c.commit()


## D-308b: vòng rune cam mờ trên nền bãi đấu boss quanh chân boss (như ảnh mẫu người dùng gửi).
static func _rune_circle(c: GroundCanvas, at: Vector2) -> void:
	var col: Color = Color(0.95, 0.55, 0.2, 0.32)
	c.draw_arc(at, 230.0, 0, TAU, 64, col, 7.0)
	c.draw_arc(at, 270.0, 0, TAU, 64, col, 4.0)
	for k: int in 12:
		var a: float = TAU * k / 12.0
		c.draw_line(at + Vector2.from_angle(a) * 236.0, at + Vector2.from_angle(a) * 264.0, col, 5.0)
