class_name RockWalls3D
extends RefCounted
## Đá và rào của bản đồ v3 (D-168, D-169), dựng từ dữ liệu map — chỉ hình ảnh, chặn đường vẫn theo
## MapLayout. Bề ngang mảnh = đúng độ dày vật cản, mảnh không lòi ra quá đầu đoạn (không đi xuyên đá,
## không có tường vô hình). Phần tử trả về cùng dạng Scenery3D._place: [vị trí, loại, cỡ, góc, (ép dọc)].
##   wall_items   khối tường dọc `rock_lines` một loại (rào base / fountain); post_items cột rào
##   ring_items   vòng đá ổ quái: lối vào của mô hình (`ring_open`, độ) xoay về hướng ghi trong map
##   pillar_items cột hai bên mỗi lối xuống sông (bậc thang vẽ dưới nền, D-170 — mô hình bậc nổi che mất chân)

static var _bounds: Dictionary[String, AABB] = {}


static func wall_items(layout: MapLayout, models: Array, kind: String, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	for i: int in layout.rock_lines.size():
		if layout.rock_line_kinds[i] != kind:
			continue
		var line: PackedVector2Array = layout.rock_lines[i]
		for k: int in line.size() - 1:
			var end: bool = k == 0 or k == line.size() - 2
			_segment(out, line[k], line[k + 1], layout.rock_line_widths[i], models, rng, kind == "rock", end)
	return out


## Chia đoạn a→b thành các mảnh dài bằng mô hình (theo bề ngang), mảnh đầu / cuối nằm gọn trong đoạn.
## Đoạn giữa đường: mảnh giữ đúng bề ngang, được chồng sang đoạn kề; đoạn đầu / cuối (cạnh cổng) thì thu
## mảnh cho gọn trong đoạn.
static func _segment(out: Array[Array], a: Vector2, b: Vector2, width: float, models: Array,
		rng: RandomNumberGenerator, rough: bool, end: bool) -> void:
	var dir: Vector2 = (b - a).normalized()
	var length: float = a.distance_to(b)
	var kind: int = rng.randi() % models.size()
	var box: AABB = model_bounds(models[kind])
	var k: float = width * MatchView3D.S / minf(box.size.x, box.size.z)
	var piece: float = maxf(box.size.x, box.size.z) * k / MatchView3D.S
	if piece > length and end:
		k *= length / piece
		piece = length
	var count: int = maxi(1, ceili((length - piece) / (piece * 0.8)) + 1)
	for j: int in count:
		var t: float = 0.5 if count == 1 else float(j) / (count - 1)
		var at: Vector2 = a + dir * (piece * 0.5 + (length - piece) * t) if piece <= length else (a + b) * 0.5
		var jitter: float = rng.randf_range(-0.08, 0.08) if rough else 0.0
		var flip: float = PI if rough and rng.randf() < 0.5 else 0.0
		out.append([at, kind if not rough else rng.randi() % models.size(), k, align(dir, box) + flip + jitter])


## Cột rào ở hai đầu mỗi đoạn rào và dọc đường, cách nhau khoảng `post_spacing`.
static func post_items(layout: MapLayout, cfg: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var k: float = cfg["post_height"] * MatchView3D.S / model_bounds(cfg["pillar"]).size.y
	for i: int in layout.rock_lines.size():
		if layout.rock_line_kinds[i] != "fence":
			continue
		var line: PackedVector2Array = layout.rock_lines[i]
		var since: float = 0.0
		for j: int in line.size():
			since += line[j].distance_to(line[j - 1]) if j > 0 else 0.0
			if j == 0 or j == line.size() - 1 or since >= cfg["post_spacing"]:
				out.append([line[j], 0, k, 0.0])
				since = 0.0
	return out


static func ring_items(layout: MapLayout, cfg: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for i: int in layout.ring_points.size():
		var turn: float = deg_to_rad(cfg["ring_open"]) - layout.ring_angles[i]
		out.append([layout.ring_points[i], layout.ring_models[i] % cfg["rings"].size(), layout.ring_scales[i], turn])
	return out


static func pillar_items(layout: MapLayout, cfg: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var k: float = cfg["pillar_height"] * MatchView3D.S / model_bounds(cfg["pillar"]).size.y
	for i: int in layout.ramp_points.size():
		var along: Vector2 = Vector2.from_angle(layout.ramp_angles[i])
		for side: float in [-1.0, 1.0]:
			out.append([layout.ramp_points[i] + along * side * cfg["stairs_width"] * 0.58, 0, k, layout.ramp_angles[i]])
	return out


## Góc quay quanh trục đứng để chiều dài mô hình (trục ngang dài hơn) nằm theo hướng `dir` (map).
static func align(dir: Vector2, box: AABB) -> float:
	if box.size.z > box.size.x:
		return atan2(dir.x, dir.y)
	return atan2(-dir.y, dir.x)


## Hộp bao mô hình tĩnh (đơn vị mô hình), nhớ theo đường dẫn.
static func model_bounds(path: String) -> AABB:
	if not _bounds.has(path):
		var n: Node3D = ModelLibrary.static_scene(path).instantiate() as Node3D
		_bounds[path] = ModelLibrary.bounds(n)
		n.free()
	return _bounds[path]
