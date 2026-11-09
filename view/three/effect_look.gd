class_name EffectLook
extends RefCounted
## D-322: hình của tướng thay theo hiệu ứng đang có — `effect_looks` trong cấu hình mô hình (units_3d.json), khóa = id hiệu
## ứng: `skin` (ảnh màu thay, đường dẫn từ assets/models/, vd Gorran Cuồng Hóa da đỏ) cho bề mặt dùng ảnh `skin_of`, `attack` / `impact` (hoạt ảnh đánh
## thay, vd chém hai kiếm). Chỉ VIEW; hết hiệu ứng thì trả hình gốc.

static var _skinned: Dictionary[String, Material] = {}


## Mục hình của hiệu ứng đầu tiên (theo thứ tự trên đơn vị) có khai báo; không có thì rỗng.
static func of(cfg: Dictionary, e: Entity) -> Dictionary:
	var looks: Dictionary = cfg.get("effect_looks", {})
	if looks.is_empty():
		return {}
	for inst: EffectInstance in e.effects:
		if looks.has(String(inst.def.id)):
			return looks[String(inst.def.id)]
	return {}


## Đặt ảnh màu `skin` ("" = gốc) cho mọi bề mặt: sửa `solid` (vật liệu đặc đang dùng, theo `base` gốc) rồi áp lại
## (đang mờ thì áp bản mờ của vật liệu mới).
## Chỉ bề mặt có ảnh màu tên `from` (ảnh da gốc) mới đổi — vũ khí gắn tay có ảnh riêng giữ nguyên.
static func apply_skin(meshes: Array[GeometryInstance3D], base: Array[Array], solid: Array[Array], skin: String, from: String, faded: bool) -> void:
	for i: int in meshes.size():
		var mi: MeshInstance3D = meshes[i] as MeshInstance3D
		if mi == null:
			continue
		for k: int in mi.mesh.get_surface_count():
			solid[i][k] = base[i][k] if skin.is_empty() or not _is_skin(base[i][k], from) else _skin_of(base[i][k], skin)
			mi.set_surface_override_material(k, ModelLibrary.faded_material(solid[i][k]) if faded else solid[i][k])


static func _is_skin(m: Material, from: String) -> bool:
	return m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null \
		and (m as BaseMaterial3D).albedo_texture.resource_path.get_file() == from


static func _skin_of(base: Material, skin: String) -> Material:
	var key: String = "%d:%s" % [base.get_instance_id(), skin]
	if not _skinned.has(key):
		var m: Material = base.duplicate()
		if m is BaseMaterial3D:
			(m as BaseMaterial3D).albedo_texture = load(ModelLibrary.MODELS + skin) as Texture2D
		_skinned[key] = m
	return _skinned[key]
