class_name RockWalls3D
extends RefCounted
## Đá của bản đồ v3 (D-168), dựng từ dữ liệu map — chỉ hình ảnh, chặn đường vẫn theo MapLayout:
## mảnh vách đá nối tiếp dọc từng đoạn `rock_lines` (bề ngang mảnh ≈ độ dày vách × `wall_overhang`),
## bậc thang ở mỗi lối xuống sông (`ramp_points`) kèm hai cột hai bên, cụm đá phủ khối đá (`rock_shapes`).
## Phần tử trả về cùng dạng Scenery3D._place: [vị trí, loại, cỡ, góc, (ép dọc)].

static var _bounds: Dictionary[String, AABB] = {}


## Mảnh vách: mỗi đoạn chia đều, mảnh chồng nhau một chút (`wall_step` < 1) cho liền.
static func wall_items(layout: MapLayout, cfg: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	var models: Array = cfg["walls"]
	for i: int in layout.rock_lines.size():
		var line: PackedVector2Array = layout.rock_lines[i]
		var width: float = layout.rock_line_widths[i] * cfg["wall_overhang"]
		for k: int in line.size() - 1:
			_segment(out, line[k], line[k + 1], width, models, cfg, rng)
	return out


static func _segment(out: Array[Array], a: Vector2, b: Vector2, width: float, models: Array,
		cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind: int = rng.randi() % models.size()
	var box: AABB = model_bounds(models[kind])
	var k: float = width * MatchView3D.S / minf(box.size.x, box.size.z)
	var length: float = maxf(box.size.x, box.size.z) * k / MatchView3D.S
	var count: int = maxi(1, ceili(a.distance_to(b) / (length * cfg["wall_step"])))
	var dir: Vector2 = (b - a).normalized()
	for j: int in count:
		kind = rng.randi() % models.size()
		box = model_bounds(models[kind])
		k = width * MatchView3D.S / minf(box.size.x, box.size.z) * rng.randf_range(0.9, 1.1)
		var flip: float = PI if rng.randf() < 0.5 else 0.0
		out.append([a.lerp(b, (j + 0.5) / count), kind, k, align(dir, box) + flip + rng.randf_range(-0.12, 0.12)])


## Bậc thang mỗi lối xuống (nằm ngang theo bờ, ép thấp sát đất) và hai cột hai bên.
static func stair_items(layout: MapLayout, cfg: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var box: AABB = model_bounds(cfg["stairs"])
	for i: int in layout.ramp_points.size():
		var dir: Vector2 = Vector2.from_angle(layout.ramp_angles[i])
		var k: float = cfg["stairs_width"] * MatchView3D.S / maxf(box.size.x, box.size.z)
		out.append([layout.ramp_points[i], 0, k, align(dir, box), cfg["stairs_squash"]])
	return out


static func pillar_items(layout: MapLayout, cfg: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var k: float = cfg["pillar_height"] * MatchView3D.S / model_bounds(cfg["pillar"]).size.y
	for i: int in layout.ramp_points.size():
		var dir: Vector2 = Vector2.from_angle(layout.ramp_angles[i])
		for side: float in [-1.0, 1.0]:
			out.append([layout.ramp_points[i] + dir * side * cfg["stairs_width"] * 0.58, 0, k, layout.ramp_angles[i]])
	return out


## Cụm đá phủ kín khối đá: lưới lệch như rừng, cỡ ngẫu nhiên.
static func fill_items(layout: MapLayout, cfg: Dictionary, rng: RandomNumberGenerator) -> Array[Array]:
	var out: Array[Array] = []
	for shape: MapShape in layout.rock_shapes:
		var points: PackedVector2Array = Scenery3D._fill(shape, cfg["rock_spacing"], cfg["rock_inset"], rng)
		if points.is_empty():
			points.append(Scenery3D._rect(shape.outer).get_center())
		for p: Vector2 in points:
			out.append([p, rng.randi() % cfg["rocks"].size(), rng.randf_range(cfg["rock_scale"][0], cfg["rock_scale"][1]), rng.randf() * TAU])
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
