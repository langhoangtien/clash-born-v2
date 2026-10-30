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
	for p: Vector2 in layout.camp_points:
		c.draw_arc(p, 48, 0, TAU, 28, MapView.GOLD, 6.0)
	c.commit()
