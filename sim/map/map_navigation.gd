class_name MapNavigation
extends RefCounted
## Tìm đường theo bán kính trên trường khoảng trống của map (MAP-01).
## Ô đi được khi vật bán kính `agent_radius` đứng ở tâm ô không chạm địa hình và không
## chạm thân trụ. Đường từ AStarGrid2D rồi kéo thẳng bằng kiểm tra tầm đi, nên đơn vị
## đi đường thẳng thay vì zig-zag theo ô. Mỗi bán kính một instance. Xác định (D-30).

## Hằng số kỹ thuật: biên an toàn khi đánh dấu ô, số vòng ô tìm ô bắt đầu.
const SAFETY_MARGIN: float = 4.0
const START_SEARCH_RINGS: int = 3

var layout: MapLayout
var grid: AStarGrid2D = AStarGrid2D.new()
var agent_radius: float
var tower_body_radius: float
var cell_size: float


func _init(map: MapLayout, radius: float, tower_radius: float) -> void:
	layout = map
	agent_radius = maxf(0.0, radius)
	tower_body_radius = maxf(0.0, tower_radius)
	cell_size = map.nav_cell
	var cells: Vector2i = Vector2i(ceili(map.world_size().x / cell_size), ceili(map.world_size().y / cell_size))
	grid.region = Rect2i(Vector2i.ZERO, cells)
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = Vector2.ONE * cell_size * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.jumping_enabled = true
	grid.update()
	_mark_terrain(cells)
	_mark_towers()


## Ô đi được khi MỌI pixel khoảng trống trong ô đủ rộng, nên mọi điểm trong ô đều đứng
## được và đi giữa hai ô kề nhau không bao giờ cắt vật cản (MOV-05).
func _mark_terrain(cells: Vector2i) -> void:
	var per_cell: int = maxi(1, roundi(cell_size / layout.clearance_pixel))
	for y: int in range(cells.y):
		for x: int in range(cells.x):
			if _cell_min_clearance(Vector2i(x, y), per_cell) < agent_radius:
				grid.set_point_solid(Vector2i(x, y), true)


func _cell_min_clearance(cell: Vector2i, per_cell: int) -> float:
	var lowest: float = INF
	for py: int in range(per_cell):
		for px: int in range(per_cell):
			lowest = minf(lowest, _pixel_clearance(cell * per_cell + Vector2i(px, py)))
	return lowest


## Thân trụ là vật cản cố định khi lập đường.
func _mark_towers() -> void:
	var reach: float = tower_body_radius + agent_radius + SAFETY_MARGIN
	for tower: Vector2 in layout.tower_points:
		var first: Vector2i = _cell(tower - Vector2.ONE * reach)
		var last: Vector2i = _cell(tower + Vector2.ONE * reach)
		for y: int in range(first.y, last.y + 1):
			for x: int in range(first.x, last.x + 1):
				var cell: Vector2i = Vector2i(x, y)
				if grid.is_in_boundsv(cell) and _center(cell).distance_to(tower) < reach:
					grid.set_point_solid(cell, true)


## Vật bán kính này đứng được ở `point` (không chạm địa hình, không chạm thân trụ).
func point_is_clear(point: Vector2) -> bool:
	if not point.is_finite() or layout.clearance_at(point) < agent_radius:
		return false
	for tower: Vector2 in layout.tower_points:
		if point.distance_to(tower) < tower_body_radius + agent_radius:
			return false
	return true


## Điểm đứng được gần `point` nhất (tính cả thân trụ).
func nearest_clear(point: Vector2, max_distance: float = 1600.0) -> Vector2:
	return MapLayout.search_rings(point, layout.clearance_pixel, max_distance, point_is_clear)


## Đi thẳng từ a tới b không chạm địa hình và trụ.
## Kiểm tra chính xác: mọi pixel của trường khoảng trống mà đoạn thẳng đi qua (duyệt
## theo lưới, không lấy mẫu) và khoảng cách từ đoạn tới mọi thân trụ.
func has_line_of_walk(a: Vector2, b: Vector2) -> bool:
	if not a.is_finite() or not b.is_finite():
		return false
	for tower: Vector2 in layout.tower_points:
		if Geometry2D.get_closest_point_to_segment(tower, a, b).distance_to(tower) < tower_body_radius + agent_radius:
			return false
	return _terrain_clear_along(a, b)


func _terrain_clear_along(a: Vector2, b: Vector2) -> bool:
	var size: float = layout.clearance_pixel
	var pa: Vector2 = a / size
	var pb: Vector2 = b / size
	var cell: Vector2i = Vector2i(floori(pa.x), floori(pa.y))
	var last: Vector2i = Vector2i(floori(pb.x), floori(pb.y))
	var d: Vector2 = pb - pa
	var step: Vector2i = Vector2i(signi(int(signf(d.x))), signi(int(signf(d.y))))
	var t_delta: Vector2 = Vector2(absf(1.0 / d.x) if d.x != 0.0 else INF, absf(1.0 / d.y) if d.y != 0.0 else INF)
	var t_max: Vector2 = Vector2(
		((cell.x + 1 - pa.x) if step.x > 0 else (pa.x - cell.x)) * t_delta.x if d.x != 0.0 else INF,
		((cell.y + 1 - pa.y) if step.y > 0 else (pa.y - cell.y)) * t_delta.y if d.y != 0.0 else INF)
	var guard: int = absi(last.x - cell.x) + absi(last.y - cell.y) + 2
	while guard > 0:
		if _pixel_clearance(cell) < agent_radius:
			return false
		if cell == last:
			return true
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += t_delta.x
		else:
			cell.y += step.y
			t_max.y += t_delta.y
		guard -= 1
	return true


func _pixel_clearance(pixel: Vector2i) -> float:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= layout.clearance_size.x or pixel.y >= layout.clearance_size.y:
		return 0.0
	return float(layout.clearance_bytes[pixel.y * layout.clearance_size.x + pixel.x]) * layout.clearance_unit


## Đường từ `from` tới `to`; rỗng khi `to` không đứng được hoặc không tới được.
## Điểm đầu là `from`, điểm cuối đúng bằng `to`.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not from.is_finite() or not point_is_clear(to):
		return PackedVector2Array()
	if point_is_clear(from) and has_line_of_walk(from, to):
		return PackedVector2Array([from, to])
	var start: Vector2i = _walkable_cell_near(from, START_SEARCH_RINGS)
	var end: Vector2i = _walkable_cell_near(to, 1)
	if start.x < 0 or end.x < 0:
		return PackedVector2Array()
	var cells: PackedVector2Array = grid.get_point_path(start, end)
	if cells.is_empty():
		return PackedVector2Array()
	var raw: PackedVector2Array = PackedVector2Array([from])
	# Đoạn đầu/cuối nối điểm thật với lưới: không đi thẳng được thì đi qua tâm ô.
	var first: int = 1 if cells.size() > 1 and has_line_of_walk(from, cells[1]) else 0
	for i: int in range(first, cells.size()):
		raw.append(cells[i])
	if raw[-1].distance_to(to) > 0.001:
		if not has_line_of_walk(raw[-1], to):
			return PackedVector2Array()  # điểm đến chỉ tới được bằng cách cắt góc
		raw.append(to)
	return _smooth(raw)


func lane_path(from: Vector2, lane: String, team: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var current: Vector2 = from
	for waypoint: Vector2 in layout.route(lane, team):
		if current.distance_to(waypoint) < 1.0:
			continue
		var leg: PackedVector2Array = path(current, waypoint)
		if leg.is_empty():
			return PackedVector2Array()
		for point: Vector2 in leg:
			if result.is_empty() or result[-1].distance_to(point) > 0.001:
				result.append(point)
		current = waypoint
	return result


## Kéo dây: chỉ giữ các góc mà đường thẳng thật sự cần.
func _smooth(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var result: PackedVector2Array = PackedVector2Array([points[0]])
	var anchor: int = 0
	while anchor < points.size() - 1:
		var next: int = anchor + 1
		while next + 1 < points.size() and has_line_of_walk(points[anchor], points[next + 1]):
			next += 1
		result.append(points[next])
		anchor = next
	return result


## Ô đi được gần `point` nhất trong vài vòng ô (đơn vị bị đẩy sát tường vẫn cần ô bắt đầu).
func _walkable_cell_near(point: Vector2, rings: int) -> Vector2i:
	var origin: Vector2i = _cell(point)
	if grid.is_in_boundsv(origin) and not grid.is_point_solid(origin):
		return origin
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: float = INF
	for ring: int in range(1, rings + 1):
		for y: int in range(origin.y - ring, origin.y + ring + 1):
			for x: int in range(origin.x - ring, origin.x + ring + 1):
				var cell: Vector2i = Vector2i(x, y)
				if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
					continue
				var distance: float = point.distance_to(_center(cell))
				if distance < best_distance:
					best_distance = distance
					best = cell
		if best.x >= 0:
			return best
	return best


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size
