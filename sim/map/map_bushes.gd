class_name MapBushes
extends RefCounted
## Bụi cỏ của map (VIS-06, D-72): đa giác theo tọa độ map, chỉ số = id bụi.

var polygons: Array[PackedVector2Array] = []
var _bounds: Array[Rect2] = []


func load_from(data: Array) -> void:
	polygons.clear()
	_bounds.clear()
	for poly: Array in data:
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Array in poly:
			pts.append(Vector2(float(p[0]), float(p[1])))
		polygons.append(pts)
		var r: Rect2 = Rect2(pts[0], Vector2.ZERO)
		for p: Vector2 in pts:
			r = r.expand(p)
		_bounds.append(r)


## Id bụi chứa `point`, -1 nếu không ở trong bụi nào.
func at(point: Vector2) -> int:
	for i: int in range(polygons.size()):
		if _bounds[i].has_point(point) and Geometry2D.is_point_in_polygon(point, polygons[i]):
			return i
	return -1
