class_name CampfireFx
extends Node3D
## D-319: ngọn lửa bập bùng + ánh lửa trên đất cho mô hình `campfire` (decor.py đặt; mô hình chỉ còn đá + củi + than).
## Chỉ hình. Dựng từ Scenery3D theo vị trí các vật `campfire` trong decor.

const FLAME: Shader = preload("res://view/three/flame.gdshader")
const GLOW: Shader = preload("res://view/three/fire_glow.gdshader")
const FLAME_SIZE: Vector2 = Vector2(0.85, 1.15)  ## m ở cỡ vật 1
const GLOW_RADIUS: float = 1.6  ## m ở cỡ vật 1

static var _flame_mat: ShaderMaterial
static var _glow_mat: ShaderMaterial


static func make(at: Vector3, scale_k: float) -> CampfireFx:
	var fx: CampfireFx = CampfireFx.new()
	fx.position = at
	var flame: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = FLAME_SIZE * scale_k
	quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)
	flame.mesh = quad
	flame.position.y = 0.12 * scale_k
	flame.material_override = _material(true)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(flame)
	var glow: MeshInstance3D = MeshInstance3D.new()
	var disc: PlaneMesh = PlaneMesh.new()
	disc.size = Vector2.ONE * GLOW_RADIUS * 2.0 * scale_k
	glow.mesh = disc
	glow.position.y = 0.02
	glow.material_override = _material(false)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(glow)
	return fx


static func _material(flame: bool) -> ShaderMaterial:
	if flame and _flame_mat == null:
		_flame_mat = ShaderMaterial.new()
		_flame_mat.shader = FLAME
	if not flame and _glow_mat == null:
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = GLOW
	return _flame_mat if flame else _glow_mat
