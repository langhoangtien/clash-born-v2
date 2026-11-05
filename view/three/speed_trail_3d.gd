class_name SpeedTrail3D
extends Node3D
## D-256: vệt tốc độ kiểu Triệu Vân (Liên Quân) — các dải sáng bám theo **đường đã chạy** (lưu vị trí vài phần mười
## giây gần nhất), đầu sáng sát người, đuôi mảnh dần rồi tan; rẽ thì vệt cong theo. Kèm đốm sáng rơi lại phía sau
## (CPUParticles3D — chạy được trên trình vẽ Compatibility). Chỉ là hình, SkillVfx3D cấp vị trí mỗi khung.

const MIN_STEP: float = 0.04  ## hằng số kỹ thuật: khoảng cách tối thiểu (đơn vị 3D) giữa hai điểm lưu

var _part: Dictionary
var _points: Array[Vector3] = []
var _times: Array[float] = []
var _clock: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _sparks: CPUParticles3D


static func make(part: Dictionary, material: ShaderMaterial) -> SpeedTrail3D:
	var t: SpeedTrail3D = SpeedTrail3D.new()
	t._part = part
	t._material = material
	for h: float in part.get("ribbons", [0.4]):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("height", h)
		t.add_child(mi)
		t._meshes.append(mi)
	if part.has("sparks"):
		t._sparks = _make_sparks(part)
		t.add_child(t._sparks)
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
	if _sparks != null and _sparks.is_inside_tree():  # hạt cần nằm trong cây cảnh
		_sparks.position = at + Vector3(0, float(_part.get("spark_height", 0.45)), 0)
		_sparks.emitting = moving
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
		var side: Vector3 = Vector3(-dir.z, 0, dir.x)
		var age: float = clampf((_clock - _times[i]) / tail, 0.0, 1.0)
		var w: float = width * (1.0 - 0.7 * age)
		m.surface_set_uv(Vector2(age, 0.0))
		m.surface_add_vertex(_points[i] + up + side * w)
		m.surface_set_uv(Vector2(age, 1.0))
		m.surface_add_vertex(_points[i] + up - side * w)
	m.surface_end()


static func _make_sparks(part: Dictionary) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.local_coords = false
	p.amount = int(part.get("spark_count", 20))
	p.lifetime = float(part.get("spark_life", 0.45))
	p.emitting = false
	p.direction = Vector3(0, 0.3, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(Color(part.get("spark_color", "#9fd8ff")), 0.9))
	fade.set_color(1, Color(Color(part.get("spark_color", "#9fd8ff")), 0.0))
	p.color_ramp = fade
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * float(part.get("spark_size", 0.14))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = load(SkillVfx3D.TEXTURES % part["sparks"])
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	return p
