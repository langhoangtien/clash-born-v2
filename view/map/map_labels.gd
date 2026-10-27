class_name MapLabels
extends RefCounted
## Ký hiệu map dev (M5.6, D-77) để gọi tên khi cân bằng: lưới ô cờ A1…P16, trụ
## (X-TOP-1, Đ-BOT-2, X-NHÀ-T…), trại (TX1…, TĐ1…), bụi (B1…B7 / B1'…), dốc (D…),
## khối rừng lớn (R…), khe (K…). Cặp đối xứng xoay 180°: nửa xanh số thường, nửa đỏ thêm "'".
## Tầng VIEW: chỉ đọc MapLayout.

const GRID: int = 16
const COLUMNS: String = "ABCDEFGHIJKLMNOP"
## Khối rừng nhỏ hơn diện tích này (đơn vị²) không đặt tên.
const FOREST_MIN_AREA: float = 250000.0

enum Kind { TOWER, CAMP, BUSH, FOREST, LANDMARK, SHOP }


class Mark:
	var text: String
	var position: Vector2
	var kind: Kind

	static func make(t: String, p: Vector2, k: Kind) -> Mark:
		var l: Mark = Mark.new()
		l.text = t
		l.position = p
		l.kind = k
		return l


static func cell_size(layout: MapLayout) -> float:
	return layout.world_size().x / GRID


## Tên ô lưới chứa `point`, vd "H9" (cột A–P trái → phải, hàng 1–16 trên → dưới).
static func cell_name(layout: MapLayout, point: Vector2) -> String:
	var s: float = cell_size(layout)
	var col: int = clampi(int(point.x / s), 0, GRID - 1)
	var row: int = clampi(int(point.y / s), 0, GRID - 1)
	return COLUMNS[col] + str(row + 1)


static func build(layout: MapLayout) -> Array[Mark]:
	var out: Array[Mark] = []
	for i: int in range(layout.tower_ids.size()):
		out.append(Mark.make(tower_name(layout.tower_ids[i]), layout.tower_points[i], Kind.TOWER))
	for i: int in range(layout.camp_ids.size()):
		out.append(Mark.make(camp_name(layout.camp_ids[i]), layout.camp_points[i], Kind.CAMP))
	var bush_centers: PackedVector2Array = PackedVector2Array()
	for poly: PackedVector2Array in layout.bushes.polygons:
		bush_centers.append(_centroid(poly))
	out.append_array(_paired(layout, bush_centers, "B", Kind.BUSH))
	var forests: PackedVector2Array = PackedVector2Array()
	for shape: MapShape in layout.forest_shapes + layout.rock_shapes:  # D-169: khối rừng hoặc núi đá
		if absf(_area(shape.outer)) >= FOREST_MIN_AREA and not _is_border(layout, shape.outer):
			forests.append(_inside_point(shape.outer))
	out.append_array(_paired(layout, forests, "R", Kind.FOREST, 300.0))
	for i: int in range(layout.shop_names.size()):
		out.append(Mark.make(layout.shop_names[i], layout.shop_points[i], Kind.SHOP))
	for i: int in range(layout.landmark_names.size()):
		out.append(Mark.make(layout.landmark_names[i], layout.landmark_points[i], Kind.LANDMARK))
	return out


## "blue_top_t1" → "X-TOP-1"; "red_base_guard_left" → "Đ-NHÀ-T".
static func tower_name(id: String) -> String:
	var side: String = "X" if id.begins_with("blue") else "Đ"
	if id.contains("base_guard"):
		return "%s-NHÀ-%s" % [side, "T" if id.ends_with("left") else "P"]
	var parts: PackedStringArray = id.split("_")
	return "%s-%s-%s" % [side, parts[1].to_upper(), parts[2].trim_prefix("t")]


## "camp_blue_03" → "TX3"; "camp_red_06" → "TĐ6".
static func camp_name(id: String) -> String:
	var parts: PackedStringArray = id.split("_")
	return ("TX" if parts[1] == "blue" else "TĐ") + str(int(parts[2]))


## Đánh số các điểm nửa xanh (dưới đường chéo: y > x) theo thứ tự đọc (trên → dưới, trái →
## phải); điểm nửa đỏ lấy số của điểm xanh đối xứng (size − p) kèm "'"; điểm trên trục không dấu.
static func _paired(layout: MapLayout, points: PackedVector2Array, prefix: String, kind: Kind, tolerance: float = 64.0) -> Array[Mark]:
	var size: Vector2 = layout.world_size()
	var blue: Array[Vector2] = []
	for p: Vector2 in points:
		if p.y - p.x > 1.0:
			blue.append(p)
	blue.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y - 1.0 or (absf(a.y - b.y) <= 1.0 and a.x < b.x))
	var out: Array[Mark] = []
	for i: int in range(blue.size()):
		out.append(Mark.make("%s%d" % [prefix, i + 1], blue[i], kind))
	var next: int = blue.size()
	for p: Vector2 in points:
		if p.y - p.x > 1.0:
			continue
		var best: int = -1
		for i: int in range(blue.size()):
			if (size - p).distance_to(blue[i]) < tolerance and (best < 0 or (size - p).distance_to(blue[i]) < (size - p).distance_to(blue[best])):
				best = i
		if best >= 0 and absf(p.y - p.x) > 1.0:
			out.append(Mark.make("%s%d'" % [prefix, best + 1], p, kind))
		else:
			next += 1
			out.append(Mark.make("%s%d" % [prefix, next], p, kind))
	return out


## Rừng viền ngoài map (bao quá 1/3 cạnh map) không đặt tên.
static func _is_border(layout: MapLayout, poly: PackedVector2Array) -> bool:
	var box: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		box = box.expand(p)
	return maxf(box.size.x, box.size.y) > layout.world_size().x / 3.0


## Tâm nếu nằm trong đa giác, không thì đỉnh gần tâm nhất dời vào trong một chút.
static func _inside_point(poly: PackedVector2Array) -> Vector2:
	var c: Vector2 = _centroid(poly)
	if Geometry2D.is_point_in_polygon(c, poly):
		return c
	var best: Vector2 = poly[0]
	for p: Vector2 in poly:
		if p.distance_to(c) < best.distance_to(c):
			best = p
	return best.move_toward(c, 80.0)


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for p: Vector2 in poly:
		sum += p
	return sum / maxf(1.0, poly.size())


static func _area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in range(poly.size()):
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5
