class_name BowString3D
extends MeshInstance3D
## D-349: dây cung vẽ bằng code (mảnh, kéo được) thay dây cứng Tripo dựng liền cây cung — chỉ VIEW. Hai đầu dây bám đầu
## cung (toạ độ trong xương cầm cung, units_3d.json `bow_string.tips`); trong pha kéo của các hoạt ảnh `release` (trước
## điểm buông = phần độ dài) điểm giữa dây là tay kéo (`pull_bone`) → hình chữ V căng; buông / ngoài lúc bắn: dây thẳng.

var _skel: Skeleton3D
var _anim: AnimationPlayer
var _bone: int = -1
var _pull: int = -1
var _tips: Array[Vector3] = []
var _release: Dictionary = {}
var _max_pull: float = 0.5
var _lines: ImmediateMesh = ImmediateMesh.new()


## Gắn dây cho mô hình (null nếu cấu hình sai / không có xương).
static func attach(model: Node3D, cfg: Dictionary) -> BowString3D:
	var skels: Array = model.find_children("*", "Skeleton3D", true, false)
	var anims: Array = model.find_children("*", "AnimationPlayer", true, false)
	if skels.is_empty() or anims.is_empty():
		return null
	var s: BowString3D = BowString3D.new()
	s._skel = skels[0]
	s._anim = anims[0]
	s._bone = s._skel.find_bone(String(cfg.get("bone", "hand_l")))
	s._pull = s._skel.find_bone(String(cfg.get("pull_bone", "hand_r")))
	for t: Array in cfg.get("tips", []):
		s._tips.append(Vector3(t[0], t[1], t[2]))
	s._release = cfg.get("release", {})
	s._max_pull = float(cfg.get("max_pull", 0.5))
	if s._bone < 0 or s._tips.size() != 2:
		return null
	s.top_level = true
	s.mesh = s._lines
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(String(cfg.get("color", "#efe6cf")))
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(s)
	return s


func _process(_delta: float) -> void:
	var pts: PackedVector3Array = points()
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p: Vector3 in pts:
		_lines.surface_add_vertex(p)
	_lines.surface_end()


## Ba điểm của dây (đầu trên, giữa, đầu dưới) trong không gian thế giới — cũng dùng trong test.
func points() -> PackedVector3Array:
	var xf: Transform3D = _skel.global_transform * _skel.get_bone_global_pose(_bone)
	var a: Vector3 = xf * _tips[0]
	var b: Vector3 = xf * _tips[1]
	var mid: Vector3 = (a + b) * 0.5
	if pulling() and _pull >= 0:
		var hand: Vector3 = (_skel.global_transform * _skel.get_bone_global_pose(_pull)).origin
		if hand.distance_to(mid) <= _max_pull * a.distance_to(b):
			mid = hand
	return PackedVector3Array([a, mid, b])


## Đang trong pha kéo dây: hoạt ảnh có trong `release` và chưa tới điểm buông.
func pulling() -> bool:
	var name: String = _anim.current_animation
	if not _anim.is_playing() or not _release.has(name):
		return false
	var length: float = maxf(0.001, _anim.current_animation_length)
	return _anim.current_animation_position / length < float(_release[name])
