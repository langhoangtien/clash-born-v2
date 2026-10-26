class_name RiverBank3D
extends RefCounted
## Bờ sông liền mạch (D-170, MAP-07): mỗi đường bờ (`rock_lines` loại "bank") dựng thành một dải
## đất nổi — mặt cỏ phía bờ → mép đất → mặt dốc đất sẫm dần xuống sát nước — thay cho hàng đá nhỏ.
## Dải phủ đúng bề ngang vật cản bờ nên nhìn thấy là biết không đi qua được. Một mesh cho cả map.

## Mặt cắt ngang dải bờ từ phía đất (0) tới phía nước (1): [vị trí, cao (m), màu].
const PROFILE: Array = [
	[0.0, 0.0, Color(0.30, 0.42, 0.17)],
	[0.18, 0.42, Color(0.40, 0.55, 0.22)],
	[0.38, 0.5, Color(0.47, 0.52, 0.25)],
	[0.55, 0.36, Color(0.42, 0.33, 0.20)],
	[0.8, 0.12, Color(0.27, 0.21, 0.14)],
	[1.0, 0.0, Color(0.14, 0.13, 0.11)],
]
## Hai đầu dải (ở lối xuống) thấp dần trong đoạn này (px).
const TAPER: float = 70.0


static func build(layout: MapLayout) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any: bool = false
	for i: int in layout.rock_lines.size():
		if layout.rock_line_kinds[i] == "bank":
			_ribbon(st, layout, layout.rock_lines[i], layout.rock_line_widths[i])
			any = true
	if not any:
		return null
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _ribbon(st: SurfaceTool, layout: MapLayout, line: PackedVector2Array, width: float) -> void:
	var side: float = _water_side(layout, line, width)
	var length: float = 0.0
	var total: float = _length(line)
	var rows: Array[PackedVector3Array] = []
	for k: int in line.size():
		if k > 0:
			length += line[k].distance_to(line[k - 1])
		var n: Vector2 = _normal(line, k) * side
		var lift: float = clampf(minf(length, total - length) / TAPER, 0.15, 1.0)
		var row: PackedVector3Array = PackedVector3Array()
		for pr: Array in PROFILE:
			var p: Vector2 = line[k] + n * (pr[0] - 0.5) * width
			row.append(Vector3(p.x * MatchView3D.S, pr[1] * lift, p.y * MatchView3D.S))
		rows.append(row)
	for k: int in rows.size() - 1:
		for j: int in PROFILE.size() - 1:
			_quad(st, rows[k][j], rows[k][j + 1], rows[k + 1][j + 1], rows[k + 1][j], PROFILE[j][2], PROFILE[j + 1][2])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color) -> void:
	for v: Array in [[a, ca], [b, cb], [c, cb], [a, ca], [c, cb], [d, ca]]:
		st.set_color(v[1])
		st.add_vertex(v[0])


## Pháp tuyến (đã chuẩn hoá, bên phải theo chiều đường) tại đỉnh k — trung bình hai đoạn kề.
static func _normal(line: PackedVector2Array, k: int) -> Vector2:
	var a: Vector2 = line[maxi(0, k - 1)]
	var b: Vector2 = line[mini(line.size() - 1, k + 1)]
	var t: Vector2 = (b - a).normalized()
	return Vector2(-t.y, t.x)


## +1 nếu nước ở bên phải đường, -1 nếu bên trái: so khoảng cách tới nước của hai bên tại mọi đoạn.
static func _water_side(layout: MapLayout, line: PackedVector2Array, width: float) -> float:
	var vote: float = 0.0
	for k: int in line.size() - 1:
		var mid: Vector2 = (line[k] + line[k + 1]) * 0.5
		var n: Vector2 = _normal(line, k) * width
		vote += _to_water(layout, mid - n) - _to_water(layout, mid + n)
	return 1.0 if vote >= 0.0 else -1.0


static func _to_water(layout: MapLayout, p: Vector2) -> float:
	var best: float = INF
	for shape: MapShape in layout.water_shapes:
		if Geometry2D.is_point_in_polygon(p, shape.outer):
			return 0.0
		for i: int in shape.outer.size():
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, shape.outer[i], shape.outer[(i + 1) % shape.outer.size()])
			best = minf(best, p.distance_to(q))
	return best


static func _length(line: PackedVector2Array) -> float:
	var out: float = 0.0
	for k: int in range(1, line.size()):
		out += line[k].distance_to(line[k - 1])
	return out
