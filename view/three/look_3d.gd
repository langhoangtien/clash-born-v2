class_name Look3D
extends RefCounted
## Ánh sáng, môi trường và bóng chân cho bản thử 3D (D-150). Chỉ dùng thứ rẻ trên GL Compatibility:
## một đèn mặt trời, ánh sáng nền, tông màu tuyến tính (giữ màu map như bản 2D), sương xa; bóng là đĩa mờ dưới chân thay cho bóng thật.

## Màu nắng / ánh sáng nền / sương xa (hằng số hiển thị).
const SUN_COLOR: Color = Color(1.0, 0.93, 0.82)
const AMBIENT_COLOR: Color = Color(0.62, 0.70, 0.86)
const HAZE_COLOR: Color = Color(0.55, 0.66, 0.78)
## Độ đậm tâm bóng chân và bán kính so với chiều cao nhân vật.
const BLOB_ALPHA: float = 0.62
const BLOB_RADIUS: float = 0.48

static var _blob_material: StandardMaterial3D
static var _blob_mesh: QuadMesh


## Mặt trời chếch sau lưng camera một chút để mặt nhân vật sáng, cộng môi trường.
static func add_lights(parent: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = SUN_COLOR
	sun.light_energy = 1.0
	parent.add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = environment()
	parent.add_child(env)


static func environment() -> Environment:
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = HAZE_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = AMBIENT_COLOR
	e.ambient_light_energy = 0.7
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.1
	e.adjustment_contrast = 1.05
	e.fog_enabled = true  # sương mỏng ở xa: có chiều sâu, che bớt phần đất xa độ phân giải thấp
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = HAZE_COLOR
	e.fog_density = 1.0
	e.fog_depth_begin = 17.0
	e.fog_depth_end = 34.0
	e.fog_depth_curve = 1.6
	e.fog_sky_affect = 0.0
	return e


## Đĩa bóng mờ nằm sát mặt đất dưới chân, cỡ theo chiều cao (dùng chung lưới và vật liệu).
static func blob(height: float) -> MeshInstance3D:
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2.ONE * 2.0
		_blob_mesh.orientation = PlaneMesh.FACE_Y
		_blob_material = _make_blob_material()
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = _blob_mesh
	m.material_override = _blob_material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3.ONE * height * BLOB_RADIUS
	m.position.y = 0.015
	return m


static func _make_blob_material() -> StandardMaterial3D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0, 0, 0, BLOB_ALPHA))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.45, Color(0, 0, 0, BLOB_ALPHA * 0.75))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_fog = true
	return mat


## Hai kênh nhiễu liền mép 256 px: R vân mịn, G vân lớn.
static func detail_texture() -> Texture2D:
	var fine: FastNoiseLite = FastNoiseLite.new()
	fine.frequency = 0.045
	fine.fractal_octaves = 3
	var broad: FastNoiseLite = FastNoiseLite.new()
	broad.seed = 7
	broad.frequency = 0.012
	var a: Image = fine.get_seamless_image(256, 256)
	var b: Image = broad.get_seamless_image(256, 256)
	var img: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y: int in 256:
		for x: int in 256:
			img.set_pixel(x, y, Color(a.get_pixel(x, y).r, b.get_pixel(x, y).r, 0.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
