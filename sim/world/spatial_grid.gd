class_name SpatialGrid
extends RefCounted
## Lưới tra cứu đơn vị theo vị trí, dựng lại khi cần (hằng số kỹ thuật: ô 256, lưới phẳng
## SIDE × SIDE ô; đơn vị ngoài lưới vào ô biên gần nhất nên vẫn tìm thấy). Kết quả sắp theo
## id (D-30); `sorted = false` nhanh hơn, người gọi phải tự phân xử hòa theo id.

const CELL: float = 256.0
## 40 × 256 = 10240 > cạnh map 8448.
const SIDE: int = 40

var built_tick: int = -1
var built_phase: int = -1
## Ô thứ (y × SIDE + x) → đơn vị trong ô, theo id tăng dần (dựng theo thứ tự danh sách).
var _cells: Array[Array] = []
var _used: PackedInt32Array = PackedInt32Array()
var _max_radius: float = 0.0


func _init() -> void:
	_cells.resize(SIDE * SIDE)
	for i: int in range(_cells.size()):
		_cells[i] = []


func rebuild(entities: Array[Entity], tick: int, phase: int) -> void:
	if built_tick == tick and built_phase == phase:
		return
	built_tick = tick
	built_phase = phase
	for i: int in _used:
		_cells[i].clear()
	_used.clear()
	_max_radius = 0.0
	for e: Entity in entities:
		if not e.alive:
			continue  # hero chờ hồi sinh không chiếm chỗ, không bị tìm thấy (ECO-04)
		var index: int = _axis(e.position.y) * SIDE + _axis(e.position.x)
		var bucket: Array = _cells[index]
		if bucket.is_empty():
			_used.append(index)
		bucket.append(e)
		_max_radius = maxf(_max_radius, e.radius)


## Đơn vị có tâm cách `point` không quá `radius` + bán kính lớn nhất (lọc thô; người gọi tự
## kiểm tra khoảng cách chính xác).
func near(point: Vector2, radius: float, sorted: bool = true) -> Array[Entity]:
	var reach: float = radius + _max_radius
	var reach_sq: float = reach * reach
	var x0: int = _axis(point.x - reach)
	var x1: int = _axis(point.x + reach)
	var out: Array[Entity] = []
	for y: int in range(_axis(point.y - reach), _axis(point.y + reach) + 1):
		var row: int = y * SIDE
		for x: int in range(x0, x1 + 1):
			for e: Entity in _cells[row + x]:
				if e.position.distance_squared_to(point) <= reach_sq:
					out.append(e)
	if sorted and out.size() > 1:
		out.sort_custom(func(a: Entity, b: Entity) -> bool: return a.id < b.id)
	return out


func _axis(v: float) -> int:
	return clampi(floori(v / CELL), 0, SIDE - 1)
