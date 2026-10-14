class_name SpatialGrid
extends RefCounted
## Lưới tra cứu đơn vị theo vị trí, dựng lại khi cần (hằng số kỹ thuật: ô 256). Kết quả sắp
## theo id (D-30); `sorted = false` nhanh hơn, người gọi phải tự phân xử hòa theo id.

const CELL: float = 256.0

var built_tick: int = -1
var built_phase: int = -1
var _cells: Dictionary[Vector2i, Array] = {}
var _max_radius: float = 0.0


func rebuild(entities: Array[Entity], tick: int, phase: int) -> void:
	if built_tick == tick and built_phase == phase:
		return
	built_tick = tick
	built_phase = phase
	_cells.clear()
	_max_radius = 0.0
	for e: Entity in entities:
		if not e.alive:
			continue  # hero chờ hồi sinh không chiếm chỗ, không bị tìm thấy (ECO-04)
		var key: Vector2i = _key(e.position)
		if not _cells.has(key):
			_cells[key] = []
		_cells[key].append(e)
		_max_radius = maxf(_max_radius, e.radius)


## Đơn vị có tâm cách `point` không quá `radius` + bán kính lớn nhất (lọc thô; người gọi tự
## kiểm tra khoảng cách chính xác).
func near(point: Vector2, radius: float, sorted: bool = true) -> Array[Entity]:
	var reach: float = radius + _max_radius
	var lo: Vector2i = _key(point - Vector2(reach, reach))
	var hi: Vector2i = _key(point + Vector2(reach, reach))
	var out: Array[Entity] = []
	for y: int in range(lo.y, hi.y + 1):
		for x: int in range(lo.x, hi.x + 1):
			var bucket: Variant = _cells.get(Vector2i(x, y))
			if bucket != null:
				for e: Entity in bucket:
					if e.position.distance_to(point) <= reach:
						out.append(e)
	if sorted:
		out.sort_custom(func(a: Entity, b: Entity) -> bool: return a.id < b.id)
	return out


func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))
