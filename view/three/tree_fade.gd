class_name TreeFade
extends RefCounted
## D-176: vật liệu chung của cây rừng — cây nằm giữa camera và tướng đang thấy được vẽ thưa (tree_fade.gdshader)
## để rừng cao không che tướng. Chỉ hình ảnh.

## Số tướng tối đa được làm mờ cây cùng lúc (khớp mảng `focus` trong shader).
const MAX_FOCUS: int = 10
## Điểm nhìn: giữa thân tướng (đơn vị 3D trên mặt đất).
const FOCUS_HEIGHT: float = 0.6
const SHADER: Shader = preload("res://view/three/tree_fade.gdshader")

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		set_focus(PackedVector3Array())
	return _material


## Vị trí chân các tướng (đơn vị 3D); quá MAX_FOCUS thì bỏ phần sau.
static func set_focus(feet: PackedVector3Array) -> void:
	var focus: PackedVector4Array = PackedVector4Array()
	focus.resize(MAX_FOCUS)
	for i: int in mini(feet.size(), MAX_FOCUS):
		focus[i] = Vector4(feet[i].x, feet[i].y + FOCUS_HEIGHT, feet[i].z, 1.0)
	material().set_shader_parameter("focus", focus)
