class_name Terrain3D
extends RefCounted
## D-178: mặt đất, nước và vật liệu cảnh vật của bộ đồ họa mới. Đọc data/maps/clashborn_decor.json (decor.py:
## vị trí cảnh vật, mặt nạ nền đất, bóng vẽ sẵn — chỉ VIEW dùng) và cấu hình `scenery.style` trong
## units_3d.json. Đơn vị 3D: mét (1 px thế giới = MatchView3D.S).

const DECOR_PATH: String = "res://data/maps/clashborn_decor.json"
## Thư mục mô hình bộ asset mới trong ModelLibrary.ROOT.
const MODEL_DIR: String = "style/"
const GROUND_SHADER: Shader = preload("res://view/three/ground.gdshader")
const WATER_SHADER: Shader = preload("res://view/three/water.gdshader")
const KIT_SHADER: Shader = preload("res://view/three/kit.gdshader")
const KIT_TEX_SHADER: Shader = preload("res://view/three/kit_tex.gdshader")
## Mặt nước cao hơn mặt đất (m) cho khỏi chập hình.
const WATER_Y: float = 0.03

static var _decor: Dictionary = {}
static var _mask: Image
static var _depth: Image
static var _textures: Dictionary[String, Texture2D] = {}
static var _materials: Dictionary[String, Material] = {}


static func decor() -> Dictionary:
	if _decor.is_empty():
		_decor = JSON.parse_string(FileAccess.get_file_as_string(DECOR_PATH))
	return _decor


## [mô hình, x, z (px thế giới), góc, cỡ, (y m)].
static func items() -> Array:
	return decor()["items"]


static func mask_image() -> Image:
	if _mask == null:
		_mask = _png(decor()["mask"])
	return _mask


## D-180: độ sâu nước (L).
static func depth_image() -> Image:
	if _depth == null:
		_depth = _png(decor()["water"])
	return _depth


## Vùng mặt nạ (px thế giới).
static func mask_rect() -> Rect2:
	var o: Array = decor()["mask_origin"]
	return Rect2(Vector2(float(o[0]), float(o[1])), Vector2(mask_image().get_size()) * float(decor()["mask_px"]))


## Vật liệu mặt đất: ảnh nền theo mặt nạ (kênh A là bóng vẽ sẵn); sương đặt mỗi khung qua `eyes` (D-180).
static func ground_material() -> ShaderMaterial:
	var cfg: Dictionary = _style()["ground"]
	var m: ShaderMaterial = _masked(GROUND_SHADER)
	m.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask_image()))
	for key: String in ["grass", "forest", "dirt", "pave"]:
		m.set_shader_parameter(key + "_tex", texture(cfg[key]))
	for key: String in ["grass_m", "dirt_m", "pave_m"]:
		m.set_shader_parameter(key, float(cfg[key]))
	m.set_shader_parameter("pave_tint", Color(cfg["pave_tint"]))  # D-186: đá lát tô màu đá chung
	m.set_shader_parameter("pave_luma", float(cfg["pave_luma"]))
	return m


## Mặt nước: một lưới tam giác phủ mọi vùng nước của map.
static func water(layout: MapLayout) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for shape: MapShape in layout.water_shapes:
		for i: int in Geometry2D.triangulate_polygon(shape.outer):
			st.add_vertex(Vector3(shape.outer[i].x * MatchView3D.S, WATER_Y, shape.outer[i].y * MatchView3D.S))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var m: ShaderMaterial = _masked(WATER_SHADER)
	m.set_shader_parameter("depth_tex", ImageTexture.create_from_image(depth_image()))
	m.set_shader_parameter("bed_tex", texture(_style()["water"]["bed"]))
	m.set_shader_parameter("bed_m", float(_style()["water"]["bed_m"]))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Vật liệu cho mô hình `model`: có vân ảnh nếu tên bắt đầu bằng một khóa trong `faces`, không thì màu đỉnh.
static func material_for(model: String) -> Material:
	var faces: Dictionary = _style()["faces"]
	for key: String in faces:
		if model.begins_with(key):
			if not _materials.has(key):
				_materials[key] = _faced(faces[key])
			return _materials[key]
	if not _materials.has(""):
		var plain: ShaderMaterial = ShaderMaterial.new()
		plain.shader = KIT_SHADER
		_materials[""] = plain
	return _materials[""]


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(String(_style()["textures"]) + name + ".png") as Texture2D
	return _textures[name]


static func _faced(f: Array) -> ShaderMaterial:
	var t: Texture2D = texture(f[0])
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = KIT_TEX_SHADER
	m.set_shader_parameter("face_tex", t)
	m.set_shader_parameter("face_mean", _mean(t))
	m.set_shader_parameter("meters", float(f[1]))
	m.set_shader_parameter("luma_only", bool(f[2]))
	m.set_shader_parameter("strength", float(f[3]))
	return m


## Vật liệu đọc ảnh phủ map (mặt đất, nước): vùng phủ theo mét.
static func _masked(shader: Shader) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	var r: Rect2 = mask_rect()
	m.set_shader_parameter("mask_origin", r.position * MatchView3D.S)
	m.set_shader_parameter("mask_size", r.size * MatchView3D.S)
	return m


static func _mean(t: Texture2D) -> Vector3:
	var img: Image = t.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var c: Color = img.get_pixel(0, 0)
	return Vector3(c.r, c.g, c.b)


static func _style() -> Dictionary:
	return ModelLibrary.scenery()["style"]


static func _png(b64: String) -> Image:
	var img: Image = Image.new()
	img.load_png_from_buffer(Marshalls.base64_to_raw(b64))
	return img
