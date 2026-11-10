class_name SwordTrail3D
extends MeshInstance3D
## D-326: vệt chém bám lưỡi kiếm (người chơi: đòn chém "như chặt thịt, chưa lực") — dải sáng nối các vị trí gần đây của
## lưỡi kiếm (từ chân tới mũi), mờ dần theo tuổi; chỉ hiện khi mũi kiếm vung nhanh (đi lại cầm kiếm không có vệt).
## Khai báo ở look của hiệu ứng (units_3d.json effect_looks.<id>.trail: bones, from / to = đoạn lưỡi tính từ gốc xương
## bàn tay dọc hướng lưỡi, đơn vị mô hình; anims + window = chỉ trong các hoạt ảnh đó, đoạn [đầu, cuối] (phần độ dài) —
## nhát chém, không phải lúc giơ / thu kiếm; color, alpha); EffectLook gắn khi đã rút kiếm, gỡ khi cất. Chỉ VIEW.
## Kiếm gắn bằng place_prop --rot 90,0,0: lưỡi hướng +z mô hình ở tư thế nghỉ.

const NAME: StringName = &"SwordTrail"
const TAIL: float = 0.12       ## giây đuôi vệt
const MIN_SPEED: float = 7.0   ## tốc mũi kiếm (đơn vị mô hình / giây) bắt đầu có vệt (nhát chém ~14; giơ kiếm, rút kiếm,
                               ## đi lại chậm hơn nhiều); gấp đôi thì rõ hẳn
const MAX_SAMPLES: int = 12
const SUBDIV: int = 4          ## điểm nội suy (Catmull-Rom) giữa hai mẫu — vệt cong mượt dù khung thưa

var _skel: Skeleton3D
var _bones: Array[int] = []
var _axis: Array[Vector3] = []
var _from: float = 0.0
var _to: float = 0.5
var _color: Color = Color.WHITE
var _hist: Array[Array] = []   ## mỗi xương: [[giây, chân, mũi, độ đậm], …] mới nhất trước
var _im: ImmediateMesh = ImmediateMesh.new()
var _clock: float = 0.0       ## giây khung hình đã chạy (tuổi các mẫu)
var _anim: AnimationPlayer
var _anims: Array = []
var _window: Vector2 = Vector2(0, 1)
var _prime: int = 0           ## > 0: còn vẽ thử chừng này khung (ShaderWarmup — Vulkan dựng đường vẽ trước)
static var _material: StandardMaterial3D  ## dùng chung mọi vệt (L-0015: tạo mới mỗi lần → khựng khi bật R)


## Gắn (spec có bones) hoặc gỡ (spec rỗng) vệt chém trên bộ xương của lưới đầu tiên.
static func attach(meshes: Array[GeometryInstance3D], spec: Dictionary) -> void:
	var mi: MeshInstance3D = meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	var skel: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi != null else null
	if skel == null:
		return
	var old: Node = skel.get_node_or_null(NodePath(NAME))
	if old != null:
		skel.remove_child(old)
		old.queue_free()
	if spec.get("bones", []).is_empty():
		return
	var t: SwordTrail3D = SwordTrail3D.new()
	t.name = NAME
	t._setup(skel, spec)
	skel.add_child(t)


func _setup(skel: Skeleton3D, spec: Dictionary) -> void:
	_skel = skel
	for b: String in spec["bones"]:
		var i: int = skel.find_bone(b)
		if i < 0:
			continue
		_bones.append(i)
		_axis.append((skel.get_bone_global_rest(i).basis.inverse() * Vector3(0, 0, 1)).normalized())
		_hist.append([])
	_from = float(spec.get("from", 0.0))
	_to = float(spec.get("to", 0.5))
	var owner_root: Node = skel.owner if skel.owner != null else skel.get_parent()
	var players: Array[Node] = owner_root.find_children("*", "AnimationPlayer", true, false)
	_anim = players[0] as AnimationPlayer if not players.is_empty() else null
	_anims = spec.get("anims", [])
	var win: Array = spec.get("window", [0.0, 1.0])
	_window = Vector2(float(win[0]), float(win[1]))
	_color = Color(spec.get("color", "#ffffff"))
	_color.a = float(spec.get("alpha", 0.6))
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.vertex_color_use_as_albedo = true
	material_override = _material


## D-330 (L-0015): ShaderWarmup vẽ thử vệt vài khung (dải trong suốt) để Vulkan dựng đường vẽ trước khi vào trận.
static func prime(meshes: Array[GeometryInstance3D], frames: int) -> void:
	var mi: MeshInstance3D = meshes[0] as MeshInstance3D if not meshes.is_empty() else null
	var skel: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi != null else null
	var t: SwordTrail3D = skel.get_node_or_null(NodePath(NAME)) as SwordTrail3D if skel != null else null
	if t != null:
		t._prime = frames


func _process(delta: float) -> void:
	_clock += delta
	var now: float = _clock
	_im.clear_surfaces()
	if _prime > 0:
		_prime -= 1
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for v: Vector3 in [Vector3.ZERO, Vector3.UP * 0.1, Vector3.RIGHT * 0.1, Vector3(0.1, 0.1, 0)]:
			_im.surface_set_color(Color(_color, 0.01))
			_im.surface_add_vertex(v)
		_im.surface_end()
		return
	for k: int in _bones.size():
		var pose: Transform3D = _skel.get_bone_global_pose(_bones[k])
		var dir: Vector3 = (pose.basis * _axis[k]).normalized()
		var tip: Vector3 = pose.origin + dir * _to
		var h: Array = _hist[k]
		var speed: float = 0.0 if h.is_empty() else (tip - (h[0][2] as Vector3)).length() / maxf(delta, 0.001)
		h.push_front([now, pose.origin + dir * _from, tip, clampf(speed / MIN_SPEED - 1.0, 0.0, 1.0) * _in_window()])
		while h.size() > MAX_SAMPLES or (h.size() > 1 and now - float(h[-1][0]) > TAIL):
			h.pop_back()
		_strip(h, now)


## 1 khi đang trong đoạn chém của hoạt ảnh khai báo (không khai báo anims thì luôn 1).
func _in_window() -> float:
	if _anims.is_empty():
		return 1.0
	if _anim == null or not _anims.has(String(_anim.current_animation)) or _anim.current_animation_length <= 0.0:
		return 0.0
	var u: float = _anim.current_animation_position / _anim.current_animation_length
	return 1.0 if u >= _window.x and u <= _window.y else 0.0


## Dải tam giác hình lưỡi liềm: mép trong trong suốt, mũi đậm; mờ theo tuổi và theo tốc lúc ghi.
func _strip(h: Array, now: float) -> void:
	if h.size() < 2:
		return
	var shown: bool = false
	for s: Array in h:
		shown = shown or float(s[3]) > 0.0
	if not shown:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in h.size() - 1:
		var p0: Array = h[maxi(i - 1, 0)]
		var p1: Array = h[i]
		var p2: Array = h[i + 1]
		var p3: Array = h[mini(i + 2, h.size() - 1)]
		for j: int in SUBDIV:
			var t: float = float(j) / SUBDIV
			var a: float = lerpf(_alpha(p1, now), _alpha(p2, now), t)
			_im.surface_set_color(Color(_color, 0.0))
			_im.surface_add_vertex(_cr(p0[1], p1[1], p2[1], p3[1], t))
			_im.surface_set_color(Color(_color, a))
			_im.surface_add_vertex(_cr(p0[2], p1[2], p2[2], p3[2], t))
	var last: Array = h[-1]
	_im.surface_set_color(Color(_color, 0.0))
	_im.surface_add_vertex(last[1])
	_im.surface_set_color(Color(_color, _alpha(last, now)))
	_im.surface_add_vertex(last[2])
	_im.surface_end()


func _alpha(s: Array, now: float) -> float:
	return _color.a * float(s[3]) * clampf(1.0 - (now - float(s[0])) / TAIL, 0.0, 1.0)


static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t)
