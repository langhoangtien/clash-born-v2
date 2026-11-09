class_name EffectLook
extends RefCounted
## D-322: hình của tướng thay theo hiệu ứng đang có — `effect_looks` trong cấu hình mô hình (units_3d.json), khóa = id hiệu
## ứng: `skin` (ảnh màu thay, đường dẫn từ assets/models/, vd Gorran Cuồng Hóa da đỏ) cho bề mặt dùng ảnh `skin_of`,
## `attack` / `impact` / `attack_alt` / `impact_alt` (hoạt ảnh đánh thay, vd chém luân phiên hai tay).
## D-323 / D-324: vật "rút ra" — bề mặt có vật liệu tên trong `props_drawn` (kiếm trên tay) chỉ hiện khi đã rút, trong
## `props_stowed` (cán kiếm sau lưng) chỉ hiện khi chưa rút; look có `props_after` (giây) thì rút sau từng ấy giây kể từ
## lúc có hiệu ứng (khớp lúc tay tới sau vai). Chỉ VIEW; hết hiệu ứng thì trả hình gốc.

static var _skinned: Dictionary[String, Material] = {}
static var _hidden: ShaderMaterial = null


## Mục hình của hiệu ứng đầu tiên (theo thứ tự trên đơn vị) có khai báo, kèm `drawn` (đã rút vật) nếu đơn vị có vật
## rút ra; đơn vị không có gì để đổi thì rỗng.
static func of(cfg: Dictionary, e: Entity, tick: int) -> Dictionary:
	var looks: Dictionary = cfg.get("effect_looks", {})
	var props: bool = cfg.has("props_drawn") or cfg.has("props_stowed")
	if looks.is_empty() and not props:
		return {}
	for inst: EffectInstance in e.effects:
		if looks.has(String(inst.def.id)):
			var look: Dictionary = (looks[String(inst.def.id)] as Dictionary).duplicate()
			var after: float = float(look.get("props_after", -1.0))
			if props:
				look["drawn"] = after >= 0.0 and tick - inst.start_tick >= SimClock.seconds_to_ticks(after)
			return look
	return {"drawn": false} if props else {}


## Khóa so sánh hai look: đổi thì phải đặt lại vật liệu (look rỗng ban đầu khác look "chưa rút" → đặt lần đầu).
static func key(look: Dictionary) -> String:
	return "%s|%s" % [look.get("skin", ""), look.get("drawn", null)]


## Đặt vật liệu mọi bề mặt theo look: sửa `solid` (vật liệu đặc đang dùng, theo `base` gốc) rồi áp lại (đang mờ thì áp
## bản mờ). Bề mặt có ảnh màu tên `skin_of` (da) đổi sang `skin` của look; vật rút ra ẩn / hiện theo `drawn`; còn lại
## giữ gốc.
static func apply(meshes: Array[GeometryInstance3D], base: Array[Array], solid: Array[Array], look: Dictionary, cfg: Dictionary, faded: bool) -> void:
	var skin: String = look.get("skin", "")
	var from: String = cfg.get("skin_of", "")
	var drawn: bool = look.get("drawn", false)
	var hide: Array = cfg.get("props_stowed", []) if drawn else cfg.get("props_drawn", [])
	for i: int in meshes.size():
		var mi: MeshInstance3D = meshes[i] as MeshInstance3D
		if mi == null:
			continue
		for k: int in mi.mesh.get_surface_count():
			var m: Material = base[i][k]
			if _is_skin(m, from):
				solid[i][k] = m if skin.is_empty() else _skin_of(m, skin)
			else:
				solid[i][k] = _hidden_material() if hide.has(m.resource_name) else m
			mi.set_surface_override_material(k, ModelLibrary.faded_material(solid[i][k]) if faded else solid[i][k])


static func _is_skin(m: Material, from: String) -> bool:
	return m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null \
		and (m as BaseMaterial3D).albedo_texture.resource_path.get_file() == from


static func _skin_of(base: Material, skin: String) -> Material:
	var k: String = "%d:%s" % [base.get_instance_id(), skin]
	if not _skinned.has(k):
		var m: Material = base.duplicate()
		if m is BaseMaterial3D:
			(m as BaseMaterial3D).albedo_texture = load(ModelLibrary.MODELS + skin) as Texture2D
		_skinned[k] = m
	return _skinned[k]


## Vật liệu ẩn: đẩy mọi đỉnh ra ngoài khung nhìn (tam giác bị bỏ trước khi tô — không tốn gì, cả bóng).
static func _hidden_material() -> ShaderMaterial:
	if _hidden == null:
		var sh: Shader = Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid vertex() { POSITION = vec4(0.0, 0.0, 2.0, 1.0); }\n"
		_hidden = ShaderMaterial.new()
		_hidden.shader = sh
	return _hidden
