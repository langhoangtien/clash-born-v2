class_name Scenery3D
extends Node3D
## Cảnh vật 3D tự dựng từ dữ liệu bản đồ (D-158) — sửa map thì cảnh tự đổi theo, không đặt tay:
## cây rải trong vùng rừng (forest_shapes), đá dọc mép vách (cliff_shapes), bụi cỏ (D-160), cửa hàng ở shop_points,
## đống đổ nát chỗ trụ đã đổ. Cây / đá vẽ bằng MultiMesh chia theo ô CHUNK px để ô ngoài khung
## nhìn tự bị bỏ. Chỉ hình ảnh: không chặn đường, không che tầm nhìn (luật vẫn theo MapLayout).
## Vị trí ngẫu nhiên lấy từ RNG riêng với hạt cố định (VIEW, không phải SIM).

## Cạnh ô chia MultiMesh (px thế giới).
const CHUNK: float = 1056.0
const SEED: int = 7

var _rubble: Dictionary[StringName, bool] = {}
var _layout: MapLayout


func build(layout: MapLayout) -> void:
	_layout = layout
	var cfg: Dictionary = ModelLibrary.scenery()
	if cfg.is_empty():
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 1
	_place(cfg["trees"], tree_items(layout))
	var rocks: Array[Array] = []
	for shape: MapShape in layout.cliff_shapes:
		for p: Vector2 in _along(shape.outer, cfg["rock_spacing"], rng):
			rocks.append([p, rng.randi() % cfg["rocks"].size(), rng.randf_range(cfg["rock_scale"][0], cfg["rock_scale"][1]), rng.randf() * TAU])
	_place(cfg["rocks"], rocks)
	if cfg.has("bushes"):  # D-160: bụi cỏ (VIS-06) — tạm dùng cụm cây tròn ép thấp
		var bushes: Array[Array] = []
		for poly: PackedVector2Array in layout.bushes.polygons:
			var shape: MapShape = MapShape.new()
			shape.outer = poly
			for p: Vector2 in _fill(shape, cfg["bush_spacing"], 10.0, rng):
				bushes.append([p, rng.randi() % cfg["bushes"].size(), rng.randf_range(cfg["bush_scale"][0], cfg["bush_scale"][1]), rng.randf() * TAU, cfg["bush_squash"]])
		_place(cfg["bushes"], bushes)
	if cfg.has("edge_grass"):  # thử phối màu: khóm cỏ thưa mọc lấn mép lane và bờ nước
		var tufts: Array[Array] = []
		for p: Vector2 in _edges(layout, cfg["edge_spacing"], rng):
			tufts.append([p, rng.randi() % cfg["edge_grass"].size(), rng.randf_range(cfg["edge_scale"][0], cfg["edge_scale"][1]), rng.randf() * TAU])
		_place(cfg["edge_grass"], tufts)
	for i: int in layout.shop_points.size():
		_add_static(cfg["shop"], layout.shop_points[i], 0.0)


## Cây trong vùng rừng: [vị trí, loại, cỡ, góc]. Cố định theo map (RNG riêng) — bóng cây nướng
## xuống đất (GroundShadows) dùng đúng danh sách này.
static func tree_items(layout: MapLayout) -> Array[Array]:
	var cfg: Dictionary = ModelLibrary.scenery()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var trees: Array[Array] = []
	for shape: MapShape in layout.forest_shapes:
		for p: Vector2 in _fill(shape, cfg["tree_spacing"], cfg["tree_inset"], rng):
			trees.append([p, rng.randi() % cfg["trees"].size(), rng.randf_range(cfg["tree_scale"][0], cfg["tree_scale"][1]), rng.randf() * TAU])
	return trees


## Mỗi khung: thêm đống đổ nát chỗ trụ vừa đổ (DEF-06).
func update(world: World) -> void:
	if _layout == null or not ModelLibrary.scenery().has("rubble"):
		return
	for i: int in _layout.tower_ids.size():
		var id: StringName = StringName(_layout.tower_ids[i])
		if world.destroyed_structures.has(id) and not _rubble.has(id):
			_rubble[id] = true
			_add_static(ModelLibrary.scenery()["rubble"], _layout.tower_points[i], float(i))


## Điểm lưới lệch ngẫu nhiên nằm trong `shape` (trừ lỗ), cách mép ít nhất `inset`.
static func _fill(shape: MapShape, spacing: float, inset: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(shape.outer, -inset)
	var box: Rect2 = _rect(shape.outer)
	var y: float = box.position.y
	while y < box.end.y:
		var x: float = box.position.x
		while x < box.end.x:
			var p: Vector2 = Vector2(x, y) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * spacing
			if _inside(inner, p) and not _inside(shape.holes, p):
				out.append(p)
			x += spacing
		y += spacing * 0.87
	return out


## Điểm dọc mép `poly`, mỗi `spacing` px, lệch nhẹ vào trong / ra ngoài.
static func _along(poly: PackedVector2Array, spacing: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var steps: int = maxi(1, int(a.distance_to(b) / spacing))
		var normal: Vector2 = (b - a).orthogonal().normalized()
		for k: int in steps:
			out.append(a.lerp(b, (k + rng.randf()) / steps) + normal * rng.randf_range(-20.0, 20.0))
	return out


## Điểm dọc hai mép lane (ngay ngoài mép) và mép nước, mỗi `spacing` px.
static func _edges(layout: MapLayout, spacing: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for lane: String in layout.lanes:
		var pts: PackedVector2Array = layout.lanes[lane]
		for i: int in pts.size() - 1:
			var side: Vector2 = (pts[i + 1] - pts[i]).normalized().orthogonal() * (layout.lane_width * 0.5 + 6.0)
			for p: Vector2 in _along(PackedVector2Array([pts[i], pts[i + 1]]), spacing, rng):
				out.append(p + side * (1.0 if rng.randf() < 0.5 else -1.0))
	for shape: MapShape in layout.water_shapes:
		out.append_array(_along(shape.outer, spacing, rng))
	return out


static func _inside(polys: Array, p: Vector2) -> bool:
	for poly: PackedVector2Array in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


static func _rect(poly: PackedVector2Array) -> Rect2:
	var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		r = r.expand(p)
	return r


## Gom `items` ([vị trí, loại, cỡ, góc]) theo (ô, loại) rồi dựng một MultiMesh cho mỗi nhóm.
func _place(models: Array, items: Array[Array]) -> void:
	var groups: Dictionary[Vector3i, Array] = {}
	for it: Array in items:
		var key: Vector3i = Vector3i(floori(it[0].x / CHUNK), floori(it[0].y / CHUNK), it[1])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	for key: Vector3i in groups:
		_multimesh(models[key.z], groups[key])


func _multimesh(model: String, items: Array) -> void:
	var src: Node3D = ModelLibrary.static_scene(model).instantiate() as Node3D
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	ModelLibrary.use_vertex_colors(mi.mesh)  # D-167
	var base: Transform3D = ModelLibrary._relative(src, mi)
	var box: AABB = base * mi.mesh.get_aabb()  # D-167: đặt gốc ở giữa đáy (mô hình tự làm có gốc lệch)
	base = Transform3D(Basis(), -Vector3(box.get_center().x, box.position.y, box.get_center().z)) * base
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	mm.instance_count = items.size()
	for i: int in items.size():
		var it: Array = items[i]
		var squash: float = it[4] if it.size() > 4 else 1.0
		var t: Transform3D = Transform3D(Basis(Vector3.UP, it[3]).scaled(Vector3(it[2], it[2] * squash, it[2])), Vector3(it[0].x, 0, it[0].y) * MatchView3D.S)
		mm.set_instance_transform(i, t * base)
	src.free()
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _add_static(cfg: Dictionary, at: Vector2, angle: float) -> void:
	var n: Node3D = ModelLibrary.static_scene(cfg["model"]).instantiate() as Node3D
	ModelLibrary.use_vertex_colors_in(n)
	add_child(n)
	var box: AABB = ModelLibrary.bounds(n)
	var k: float = cfg["height"] / maxf(0.01, box.size.y)
	n.scale = Vector3.ONE * k
	n.rotation.y = angle
	n.position = Vector3(at.x, 0, at.y) * MatchView3D.S - Vector3(box.get_center().x, box.position.y, box.get_center().z).rotated(Vector3.UP, angle) * k
