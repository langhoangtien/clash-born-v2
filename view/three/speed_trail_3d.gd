class_name SpeedTrail3D
extends Node3D
## D-256: vệt tốc độ kiểu Triệu Vân (Liên Quân) — các dải sáng bám theo **đường đã chạy** (lưu vị trí vài phần mười
## giây gần nhất), đầu sáng sát người, đuôi mảnh dần rồi tan; rẽ thì vệt cong theo. D-298: bỏ đốm sáng rơi lại
## (hạt — gây giật lúc tạo, L-0009). D-300: vẽ bằng tia gió dịu (vfx_soft dạng 16: đường mảnh uốn lượn trong dải),
## không dùng ảnh. D-303: `vertical` — dải dựng đứng (tấm khí kéo sau lưng). Chỉ là hình, SkillVfx3D cấp vị trí mỗi khung.

const MIN_STEP: float = 0.04  ## hằng số kỹ thuật: khoảng cách tối thiểu (đơn vị 3D) giữa hai điểm lưu

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
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(_points.size() - 1, -1, -1):
		var a: Vector3 = _points[mini(i + 1, _points.size() - 1)]
		var b: Vector3 = _points[maxi(i - 1, 0)]
		var dir: Vector3 = Vector3(a.x - b.x, 0, a.z - b.z).normalized()
		var side: Vector3 = Vector3.UP if _part.get("vertical", false) else Vector3(-dir.z, 0, dir.x)  # D-303: tấm khí đứng
		var age: float = clampf((_clock - _times[i]) / tail, 0.0, 1.0)
		var w: float = width * (1.0 - 0.7 * age)
		m.surface_set_uv(Vector2(age, 0.0))
		m.surface_add_vertex(_points[i] + up + side * w)
		m.surface_set_uv(Vector2(age, 1.0))
		m.surface_add_vertex(_points[i] + up - side * w)
	m.surface_end()

