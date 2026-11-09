class_name SpeedTrail3D
extends Node3D
## D-256: vệt tốc độ kiểu Triệu Vân (Liên Quân) — các dải sáng bám theo **đường đã chạy** (lưu vị trí vài phần mười
## giây gần nhất), đầu sáng sát người, đuôi mảnh dần rồi tan; rẽ thì vệt cong theo. D-298: bỏ đốm sáng rơi lại
## (hạt — gây giật lúc tạo, L-0009). D-300: vẽ bằng tia gió dịu (vfx_soft dạng 16: đường mảnh uốn lượn trong dải),
## không dùng ảnh. D-303: `vertical` — dải dựng đứng (tấm khí kéo sau lưng); D-305: dải đứng quay về camera (rẽ về
## phía camera không còn bị nhìn cạnh mỏng thành vết cắt). Chỉ là hình, SkillVfx3D cấp vị trí mỗi khung.

const MIN_STEP: float = 0.04  ## hằng số kỹ thuật: khoảng cách tối thiểu (đơn vị 3D) giữa hai điểm lưu
const SMOOTH_PASSES: int = 3  ## hằng số hiển thị: số lượt làm mượt cạnh dải đứng (D-306)

var _part: Dictionary
var _points: Array[Vector3] = []
var _times: Array[float] = []
var _clock: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _material: ShaderMaterial


static func make(part: Dictionary, material: ShaderMaterial) -> SpeedTrail3D:
	var t: SpeedTrail3D = SpeedTrail3D.new()
	t._part = part
	t._material = material
	var ribbons: Array = part.get("ribbons", [0.4])
	for k: int in ribbons.size():
		var h: float = ribbons[k]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.material_override = material
		mi.set_instance_shader_parameter("phase", k * 2.1)  # D-300: mỗi dải gió uốn lệch nhau
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("height", h)
		t.add_child(mi)
		t._meshes.append(mi)
	return t


## Đầu vệt (vị trí mới nhất của chủ chiêu).
func head() -> Vector3:
	return _points[-1] if not _points.is_empty() else Vector3.INF


func set_fade(alpha: float) -> void:
	_material.set_shader_parameter("fade", alpha)


func update(at: Vector3, moving: bool, delta: float) -> void:
	_clock += delta
	if moving and (_points.is_empty() or at.distance_to(_points[-1]) > MIN_STEP):
		_points.append(at)
		_times.append(_clock)
	var tail: float = float(_part.get("tail", 0.4))
	while not _times.is_empty() and _clock - _times[0] > tail:
		_points.pop_front()
		_times.pop_front()
	for mi: MeshInstance3D in _meshes:
		_build(mi.mesh as ImmediateMesh, float(mi.get_meta("height")), at, tail)


## Dải nằm ngang theo đường chạy: u = tuổi (0 đầu → 1 đuôi), v = ngang dải; bề rộng thu nhỏ về đuôi.
func _build(m: ImmediateMesh, height: float, at: Vector3, tail: float) -> void:
	m.clear_surfaces()
	if _points.size() < 2:
		return
	var width: float = float(_part.get("width", 0.15))
	var up: Vector3 = Vector3(0, height, 0)
	var face: bool = _part.get("vertical", false)
	var sides: PackedVector3Array = _sides(face)
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(_points.size() - 1, -1, -1):
		var age: float = clampf((_clock - _times[i]) / tail, 0.0, 1.0)
		var w: float = width * (1.0 - 0.7 * age)
		if face:  # D-306: làn khí nhọn dần về phía người (không cắt ngang thẳng)
			w *= 0.3 + 0.7 * smoothstep(0.0, 0.2, age)
		m.surface_set_uv(Vector2(age, 0.0))
		m.surface_add_vertex(_points[i] + up + sides[i] * w)
		m.surface_set_uv(Vector2(age, 1.0))
		m.surface_add_vertex(_points[i] + up - sides[i] * w)
	m.surface_end()


## Cạnh dải ở từng điểm. Dải đứng (D-303) quay về camera (D-305); D-306: làm mượt qua các điểm kề — rẽ gắt không
## gấp thành nếp sáng.
func _sides(face: bool) -> PackedVector3Array:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in _points.size():
		var a: Vector3 = _points[mini(i + 1, _points.size() - 1)]
		var b: Vector3 = _points[maxi(i - 1, 0)]
		var dir: Vector3 = Vector3(a.x - b.x, 0, a.z - b.z).normalized()
		if not face:
			out.append(Vector3(-dir.z, 0, dir.x))
		else:
			out.append(facing_side(dir, cam.global_position - _points[i]) if cam != null else Vector3.UP)
	if face:
		for _pass: int in SMOOTH_PASSES:
			var prev: PackedVector3Array = out.duplicate()
			for i: int in range(1, out.size() - 1):
				out[i] = (prev[i - 1] + prev[i] * 2.0 + prev[i + 1]).normalized()
	return out


## D-305: cạnh dải quay về mắt — vuông góc với hướng chạy và hướng tới mắt (chạy ngang màn hình: gần như đứng).
static func facing_side(dir: Vector3, to_eye: Vector3) -> Vector3:
	var side: Vector3 = dir.cross(to_eye)
	return side.normalized() if side.length_squared() > 0.000001 else Vector3.UP
