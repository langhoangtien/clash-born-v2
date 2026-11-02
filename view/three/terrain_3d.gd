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
const ABYSS_SHADER: Shader = preload("res://view/three/abyss.gdshader")
## D-197: độ sâu vực ngoài rìa map (m).
const ABYSS_DEPTH: float = 18.0
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
	for key: String in ["grass", "forest", "dirt", "stones"]:
		m.set_shader_parameter(key + "_tex", texture(cfg[key]))
	for key: String in ["grass_m", "dirt_m", "stones_m"]:
		m.set_shader_parameter(key, float(cfg[key]))
	m.set_shader_parameter("dirt_color", Color(cfg["dirt_color"]))  # D-187: đất nện tô màu đất chung
	m.set_shader_parameter("dirt_luma", float(cfg["dirt_luma"]))
	return m


## D-197: mặt đất chỉ phủ khung map trừ rìa (tam giác decor `ground`), y = 0.
static func ground_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tris(st, decor()["ground"], 0.0)
	return st.commit()


## D-197: vực ngoài rìa map — đáy (tam giác decor `abyss`) sâu ABYSS_DEPTH, vách dọc vòng mép mặt đất (`cliff`).
static func abyss() -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tris(st, decor()["abyss"], -ABYSS_DEPTH)
	for ring: Array in decor()["cliff"]:
		for i: int in ring.size():
			var a: Vector3 = Vector3(float(ring[i][0]), 0, float(ring[i][1])) * MatchView3D.S
			var j: Array = ring[(i + 1) % ring.size()]
			var b: Vector3 = Vector3(float(j[0]), 0, float(j[1])) * MatchView3D.S
			st.set_normal(Vector3(b.z - a.z, 0, a.x - b.x).normalized())
			var down: Vector3 = Vector3(0, -ABYSS_DEPTH, 0)
			for v: Vector3 in [a, b, b + down, a, b + down, a + down]:
				st.add_vertex(v)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var cfg: Dictionary = _style()["abyss"]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = ABYSS_SHADER
	m.set_shader_parameter("cliff_tex", texture(cfg["cliff"]))
	m.set_shader_parameter("mist", Color(cfg["mist"]))
	m.set_shader_parameter("depth", ABYSS_DEPTH)
	mi.material_override = m
	m.set_shader_parameter("floor_tex", texture(cfg["floor"]))  # D-202: chốt kiểu A
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _add_tris(st: SurfaceTool, tris: Array, y: float) -> void:
	st.set_normal(Vector3.UP)
	for t: Array in tris:
		for k: int in [0, 4, 2]:  # đảo chiều cho mặt hướng lên (Godot: mặt trước theo chiều kim đồng hồ)
			st.add_vertex(Vector3(float(t[k]) * MatchView3D.S, y, float(t[k + 1]) * MatchView3D.S))


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
