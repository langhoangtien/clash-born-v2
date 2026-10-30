class_name GroundCanvas
extends MultiMeshInstance3D
## D-180: vẽ hình phẳng nằm trên mặt đất 3D (vòng đội, vùng chiêu, hiệu ứng, mũi nhắm, viền bụi…) thay
## lớp 2D vẽ vào SubViewport mỗi khung (D-145). Cùng kiểu lệnh với CanvasItem (toạ độ px thế giới) nên
## các painter giữ nguyên; mỗi hình là một ô vuông của MultiMesh, shader ground_shapes cắt thành đĩa / vành
## / quạt / tam giác. Gọi begin() đầu khung, các lệnh draw_*, rồi commit().

const SHADER: Shader = preload("res://view/three/ground_shapes.gdshader")
## Cao hơn mặt đất / mặt nước (m) cho khỏi chập hình.
const LIFT: float = 0.06
const RECT: float = 0.0
const DISC: float = 1.0
const TRI: float = 2.0
## Số float mỗi hình trong bộ đệm MultiMesh: 12 biến đổi + 4 màu + 4 custom.
const STRIDE: int = 20

var _buf: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _xf: Transform2D = Transform2D.IDENTITY


func _init() -> void:
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(2, 2)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SHADER
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func begin() -> void:
	_buf.resize(0)
	_count = 0
	_xf = Transform2D.IDENTITY


func commit() -> void:
	multimesh.instance_count = _count
	if _count > 0:
		multimesh.buffer = _buf


## Số hình đã vẽ từ begin() (cho test).
func shape_count() -> int:
	return _count


## Dữ liệu hình thứ `i` (STRIDE số: biến đổi, màu, custom) — cho test.
func shape(i: int) -> PackedFloat32Array:
	return _buf.slice(i * STRIDE, (i + 1) * STRIDE)


func draw_set_transform(pos: Vector2, rot: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	_xf = Transform2D(rot, scale, 0.0, pos)


func draw_circle(pos: Vector2, radius: float, color: Color, _filled: bool = true, _width: float = -1.0, _aa: bool = false) -> void:
	if radius > 0.0:
		_disc(pos, radius, color, 0.0, 0.0, TAU)


func draw_arc(center: Vector2, radius: float, start: float, end: float, _points: int, color: Color, width: float = -1.0, _aa: bool = false) -> void:
	var w: float = maxf(width, 2.0)
	var outer: float = radius + w * 0.5
	if outer > 0.0:
		_disc(center, outer, color, maxf(0.0, radius - w * 0.5) / outer, minf(start, end), absf(end - start))


## Hình quạt đầy (thay đa giác quạt của CanvasItem).
func draw_sector(center: Vector2, radius: float, start: float, end: float, color: Color) -> void:
	_disc(center, radius, color, 0.0, minf(start, end), absf(end - start))


func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, _aa: bool = false) -> void:
	var d: Vector2 = to - from
	if d.length_squared() < 0.0001:
		return
	var side: Vector2 = d.orthogonal().normalized() * maxf(width, 2.0) * 0.5
	_push((from + to) * 0.5, d * 0.5, side, color, RECT, 0.0, 0.0, TAU)


func draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, dash: float = 2.0, _aligned: bool = true, _aa: bool = false) -> void:
	var length: float = from.distance_to(to)
	var steps: int = maxi(1, floori(length / (dash * 2.0)))
	for i: int in steps:
		draw_line(from.lerp(to, i * 2.0 * dash / length), from.lerp(to, minf(1.0, (i * 2.0 + 1.0) * dash / length)), color, width)


func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, _aa: bool = false) -> void:
	for i: int in points.size() - 1:
		draw_line(points[i], points[i + 1], color, width)


func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, _aa: bool = false) -> void:
	if filled:
		_push(rect.get_center(), Vector2(rect.size.x * 0.5, 0), Vector2(0, rect.size.y * 0.5), color, RECT, 0.0, 0.0, TAU)
		return
	var c: PackedVector2Array = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
	draw_polyline(c, color, width)


## Đa giác bất kỳ: tách tam giác (chữ nhật bốn đỉnh thì một hình).
func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(points)
	for i: int in range(0, tris.size(), 3):
		var a: Vector2 = points[tris[i]]
		var b: Vector2 = points[tris[i + 1]]
		var c: Vector2 = points[tris[i + 2]]
		# Ô [-1,1] nửa dưới (s + t ≤ 1) với s theo a→b, t theo a→c: gốc ô = a + (b − a + c − a) / 2.
		_push(a + (b - a + c - a) * 0.5, (b - a) * 0.5, (c - a) * 0.5, color, TRI, 0.0, 0.0, TAU)


func _disc(center: Vector2, radius: float, color: Color, inner: float, start: float, span: float) -> void:
	_push(center, Vector2(radius, 0), Vector2(0, radius), color, DISC, inner, fposmod(start, TAU), span)


## Một hình: ô [-1,1] có tâm `at`, nửa trục `ax` (theo x cục bộ), `az` (theo z cục bộ), qua draw_set_transform.
func _push(at: Vector2, ax: Vector2, az: Vector2, color: Color, kind: float, inner: float, start: float, span: float) -> void:
	var o: Vector2 = _xf * at
	var x: Vector2 = _xf.basis_xform(ax) * MatchView3D.S
	var z: Vector2 = _xf.basis_xform(az) * MatchView3D.S
	var s: float = MatchView3D.S
	# Hàng của ma trận 3×4 (MultiMesh TRANSFORM_3D): [x.x y.x z.x o.x], [x.y y.y z.y o.y], [x.z y.z z.z o.z].
	_buf.append_array([x.x, 0.0, z.x, o.x * s, 0.0, 1.0, 0.0, LIFT, x.y, 0.0, z.y, o.y * s,
		color.r, color.g, color.b, color.a, kind, inner, start, span])
	_count += 1
