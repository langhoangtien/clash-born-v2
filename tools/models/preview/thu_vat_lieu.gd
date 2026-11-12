extends RefCounted
## D-361: vật liệu bản thử chuẩn cảnh vật (chỉ dùng trong công cụ xem trước, không vào game).
##   "A" — lá về phía đá / đất: tán cây, bụi, hoa lá có vân nét cọ (sáng tối của ảnh cỏ vẽ tay) + tông trầm;
##   "B" — đá về phía lá: đá, tảng, lan can bỏ vân, chỉ còn màu đỉnh phẳng.
const LEAF_SHADER: Shader = preload("res://art_inbox/kiem_ke/thu_canh_vat/thu_la.gdshader")
const KIT_SHADER: Shader = preload("res://view/three/kit.gdshader")
const LEAVES: Array[String] = ["pine_", "tree_", "bush_", "plant_", "grass_tuft", "reeds", "flowers"]
const ROCKS: Array[String] = ["rock_", "boulder_", "parapet"]
const LEAF_TEX: String = "grass_dark"

static var _cache: Dictionary[String, Material] = {}


## Vật liệu thay cho mô hình `model` (tên file không đuôi) ở phương án `variant`; null = giữ vật liệu của trận.
static func material_for(model: String, variant: String) -> Material:
	if variant == "A" and _starts(model, LEAVES):
		return _leaf()
	if variant == "B" and _starts(model, ROCKS):
		return _flat()
	return null


## Tên mô hình của một lưới nhập từ GLB (đường dẫn tài nguyên `…/style/<tên>.glb::…`).
static func model_of(mesh: Mesh) -> String:
	return mesh.resource_path.get_slice("::", 0).get_file().get_basename()


static func _starts(model: String, keys: Array[String]) -> bool:
	for k: String in keys:
		if model.begins_with(k):
			return true
	return false


static func _leaf() -> Material:
	if not _cache.has("leaf"):
		var t: Texture2D = Terrain3D.texture(LEAF_TEX)
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = LEAF_SHADER
		m.set_shader_parameter("face_tex", t)
		m.set_shader_parameter("face_mean", Terrain3D._mean(t))
		_cache["leaf"] = m
	return _cache["leaf"]


static func _flat() -> Material:
	if not _cache.has("flat"):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = KIT_SHADER
		_cache["flat"] = m
	return _cache["flat"]
