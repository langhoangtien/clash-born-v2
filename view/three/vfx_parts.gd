class_name VfxParts
extends RefCounted
## D-296: mảnh hiệu ứng "dịu" (shader vfx_soft, không cần ảnh) cho SkillVfx3D / SkillShots3D. Mảnh trong vfx.json:
##   ring  — vành loang trên đất (radius px, from, width) · disc — đĩa lóe trên đất (radius px) ·
##   pillar — cột sáng (radius px, tall m) · glow — đốm sáng quay về camera (size m) ·
##   aura — hào quang dưới chân, đi theo đơn vị suốt `life` (radius px) · wave — sóng chạy dọc hướng tung (length,
##   width px) · shot — vệt đạn kỹ năng (size m; SkillShots3D) · D-297: dome — bong bóng khiên quanh người (radius px),
##   wisps — làn sáng bốc lên quanh người (radius px, tall m) — cả hai đi theo đơn vị như aura · zone / pending — vũng
##   của vùng tồn tại / vùng có độ trễ (ZoneView3D, cỡ theo vùng trong SIM) · D-298: tornado — lốc xoáy (radius px,
##   tall m), chains — vòng xích dưới chân, ice — khối băng bao người, cone — vệt quét hình quạt (radius, angle độ);
##   meteors — sao băng rơi xuống vùng có độ trễ (count, ZoneView3D).
## Chung: color, edge (lõi), alpha (độ đục tối đa — giữ ≤ 0,85 để 5v5 không chói), life (giây hoặc tên giá trị kỹ năng),
## height (m), at = caster | point | target.

const SHADER: Shader = preload("res://view/three/vfx_soft.gdshader")
const MODES: Dictionary[String, int] = {"ring": 0, "disc": 1, "pillar": 2, "glow": 3, "aura": 4, "shot": 5, "wave": 6,
	"zone": 7, "pending": 8, "dome": 9, "wisps": 10, "tornado": 11, "chains": 12, "cone": 13, "ice": 14}
## Mảnh đi theo đơn vị suốt `life` (SkillVfx3D, EffectVfx3D).
const FOLLOW: Array[String] = ["aura", "dome", "wisps", "tornado", "chains", "ice"]
## Độ cao mặc định (m) của mảnh nằm trên đất — trên mặt đất một chút để không chìm.
const GROUND_LIFT: float = 0.05


static func is_soft(type: String) -> bool:
	return MODES.has(type)


## Dựng mảnh `part`; `size` = bán kính (m) cho mảnh tròn / cột, cạnh (m) cho đốm, [dài, rộng] (m) cho sóng / vệt.
static func make(part: Dictionary, size: Variant) -> MeshInstance3D:
	var mode: int = MODES[part["type"]]
	var mi: MeshInstance3D = MeshInstance3D.new()
	match part["type"]:
		"dome", "ice":
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = float(size)
			sph.height = float(size) * 2.0
			sph.radial_segments = 24
			sph.rings = 12
			mi.mesh = sph
			mi.position.y = float(size) * 0.55
		"pillar", "wisps", "tornado":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = float(size) * (1.7 if part["type"] == "tornado" else 1.0)
			cyl.bottom_radius = float(size)
			cyl.height = float(part.get("tall", 2.0 if part["type"] == "pillar" else 1.4))
			cyl.cap_top = false
			cyl.cap_bottom = false
			cyl.radial_segments = 16
			mi.mesh = cyl
			mi.position.y = cyl.height * 0.5
		"glow":
			mi.mesh = _quad(Vector2.ONE * float(size))
		"shot":
			mi.mesh = _quad(size as Vector2)
			mi.rotation.x = -PI * 0.5
		"wave":
			var q: QuadMesh = _quad(size as Vector2)
			q.center_offset = Vector3(0, (size as Vector2).y * 0.5, 0)  # gốc sóng ở chủ chiêu
			mi.mesh = q
			mi.rotation.x = -PI * 0.5
		_:
			mi.mesh = _quad(Vector2.ONE * float(size) * 2.0)
			mi.rotation.x = -PI * 0.5
	mi.material_override = material(part, mode)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func material(part: Dictionary, mode: int) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("color", Color(part.get("color", "#9fc4ff")))
	mat.set_shader_parameter("edge", Color(part.get("edge", "#eef5ff")))
	mat.set_shader_parameter("alpha", float(part.get("alpha", 0.6)))
	mat.set_shader_parameter("width", float(part.get("width", 0.1)))
	mat.set_shader_parameter("from", float(part.get("from", 0.2)))
	mat.set_shader_parameter("billboard", mode == MODES["glow"])
	mat.set_shader_parameter("angle", deg_to_rad(float(part.get("angle_deg", 150.0))) * 0.5)
	return mat


## Đặt tiến độ 0..1 (mỗi khung).
static func animate(mi: MeshInstance3D, t: float) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("t", t)


static func _quad(s: Vector2) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = s
	return q
