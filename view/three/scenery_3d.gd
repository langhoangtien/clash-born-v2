class_name Scenery3D
extends Node3D
## Cảnh vật 3D dựng từ dữ liệu bản đồ — sửa map thì cảnh tự đổi theo, không đặt tay (D-158). D-178: cây, đá
## viền bục, bờ sông, rào, tường thành đặt sẵn bởi decor.py (Terrain3D.items); bụi cỏ (D-160) rải trong vùng bụi;
## cửa hàng ở shop_points; đống đổ nát chỗ trụ đã đổ. Vẽ bằng MultiMesh chia theo ô CHUNK px để ô ngoài khung
## nhìn tự bị bỏ. Chỉ hình ảnh: không chặn đường, không che tầm nhìn (luật vẫn theo MapLayout).
## Vị trí ngẫu nhiên (bụi) lấy từ RNG riêng với hạt cố định (VIEW, không phải SIM).

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
	_place_decor(Terrain3D.items())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var bushes: Array[Array] = []
	for poly: PackedVector2Array in layout.bushes.polygons:
		var shape: MapShape = MapShape.new()
		shape.outer = poly
		for p: Vector2 in _fill(shape, cfg["bush_spacing"], 10.0, rng):
			bushes.append([p, rng.randi() % cfg["bushes"].size(), rng.randf_range(cfg["bush_scale"][0], cfg["bush_scale"][1]), rng.randf() * TAU, cfg["bush_squash"]])
	_place(cfg["bushes"], bushes)
	for i: int in layout.shop_points.size():
		_add_static(cfg["shop"], layout.shop_points[i], 0.0)


## Mỗi khung: thêm đống đổ nát chỗ trụ vừa đổ (DEF-06).
func update(world: World) -> void:
	if _layout == null or not ModelLibrary.scenery().has("rubble"):
		return
	for i: int in _layout.tower_ids.size():
		var id: StringName = StringName(_layout.tower_ids[i])
		if world.destroyed_structures.has(id) and not _rubble.has(id):
			_rubble[id] = true
			_add_static(ModelLibrary.scenery()["rubble"], _layout.tower_points[i], float(i))


## D-178: cảnh vật decor.py [mô hình, x, z, góc, cỡ, (y m)] gom theo (ô, mô hình), vật liệu theo Terrain3D.
func _place_decor(items: Array) -> void:
	var groups: Dictionary[String, Array] = {}
	for it: Array in items:
		var key: String = "%d:%d:%s" % [floori(float(it[1]) / CHUNK), floori(float(it[2]) / CHUNK), it[0]]
		if not groups.has(key):
			groups[key] = []
		groups[key].append([Vector2(float(it[1]), float(it[2])), 0, float(it[4]), float(it[3]), 1.0, float(it[5]) if it.size() > 5 else 0.0])
	for key: String in groups:
		var model: String = key.get_slice(":", 2)
		_multimesh(Terrain3D.MODEL_DIR + model, groups[key], Terrain3D.material_for(model))


## Điểm lưới lệch ngẫu nhiên nằm trong `shape` (trừ lỗ), cách mép ít nhất `inset`.
static func _fill(shape: MapShape, spacing: float, inset: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(shape.outer, -inset)
	var box: Rect2 = _rect(shape.outer)
	var outer_cw: bool = Geometry2D.is_polygon_clockwise(shape.outer)
	var y: float = box.position.y
	while y < box.end.y:
		var x: float = box.position.x
		while x < box.end.x:
			var p: Vector2 = Vector2(x, y) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * spacing
			if _inside_rings(inner, p, outer_cw) and not _inside(shape.holes, p):
				out.append(p)
			x += spacing
		y += spacing * 0.87
	return out


## Trong kết quả offset_polygon: vòng cùng chiều với đa giác gốc là phần trong, ngược chiều là lỗ.
static func _inside_rings(rings: Array[PackedVector2Array], p: Vector2, outer_cw: bool) -> bool:
	var hit: bool = false
	for ring: PackedVector2Array in rings:
		if Geometry2D.is_point_in_polygon(p, ring):
			if Geometry2D.is_polygon_clockwise(ring) != outer_cw:
				return false
			hit = true
	return hit


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


## Gom `items` ([vị trí, loại, cỡ, góc, (ép dọc)]) theo (ô, loại) rồi dựng một MultiMesh cho mỗi nhóm.
func _place(models: Array, items: Array[Array]) -> void:
	var groups: Dictionary[Vector3i, Array] = {}
	for it: Array in items:
		var key: Vector3i = Vector3i(floori(it[0].x / CHUNK), floori(it[0].y / CHUNK), it[1])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	for key: Vector3i in groups:
		_multimesh(models[key.z], groups[key], null)


## `items`: [vị trí, loại, cỡ, góc, (ép dọc), (y m)]; `material` (nếu có) thay vật liệu của mô hình.
func _multimesh(model: String, items: Array, material: Material) -> void:
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
		var y: float = it[5] if it.size() > 5 else 0.0
		var t: Transform3D = Transform3D(Basis(Vector3.UP, it[3]).scaled(Vector3(it[2], it[2] * squash, it[2])), Vector3(it[0].x * MatchView3D.S, y, it[0].y * MatchView3D.S))
		mm.set_instance_transform(i, t * base)
	src.free()
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
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
