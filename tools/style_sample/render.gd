extends SceneTree
## Cảnh mẫu phong cách mới (bước 1 đồ họa): đọc out/sample.json (make_sample.py), dựng mặt đất / nước / asset
## (MultiMesh mỗi loại), tướng + quái KayKit để so cỡ, camera y như trong trận (MatchView3D), chụp ảnh.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/style_sample/render.gd -- <thư_mục_ảnh> [rộng cao]

const DIR: String = "res://tools/style_sample/"
const MODELS: String = "res://assets/models/style/"
const TEXTURES: String = "res://art_inbox/08_style/"
## Ảnh vân dán lên mặt khối theo tiền tố tên mô hình.
## Tán cây dùng ảnh lá Codex (chỉ sáng tối, giữ màu mô hình): [ảnh, mét, chỉ sáng tối, độ mạnh].
const FACES: Dictionary = {"rock": ["rock_face", 3.0, false, 1.0], "boulder": ["rock_face", 2.0, false, 1.0], "fence": ["wall_face", 4.0, false, 1.0],
	"great_wall": ["wall_face", 4.0, false, 1.0], "pine": ["foliage_pine", 2.0, true, 0.8], "tree": ["foliage_leaf", 2.0, true, 0.8]}
const SHOTS: Array[Vector2] = [Vector2(19.5, 21.5), Vector2(11.0, 10.0), Vector2(29.0, 30.0), Vector2(22.0, 3.0), Vector2(31.0, 35.0)]

var _root: Node3D
var _cam: Camera3D
var _frames: int = 0
var _out: String
var _shot: int = 0
var _triangles: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])) if args.size() > 2 else Vector2i(1650, 1080))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "out/sample.json"))
	_root = Node3D.new()
	root.add_child(_root)
	var mask: Texture2D = _tex("out/ground_mask.png")
	_ground(mask, float(data["size"]))
	_water(data["water"], mask, float(data["size"]))
	_items(data["items"])
	_actors(data)
	_cam = Camera3D.new()
	_cam.fov = MatchView3D.CAM_FOV
	_root.add_child(_cam)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Look3D.environment()
	_root.add_child(env)
	Look3D.add_lights(_root)
	print("tam giác cảnh tĩnh (cả cảnh): ", _triangles)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 20 == 1:
		var target: Vector3 = Vector3(SHOTS[_shot].x, 0, SHOTS[_shot].y)
		_cam.position = target + MatchView3D.CAM_OFFSET
		_cam.look_at(target, Vector3.UP)
	if _frames % 20 == 0:
		root.get_texture().get_image().save_png("%s/shot_%d.png" % [_out, _shot])
		_shot += 1
		return _shot >= SHOTS.size()
	return false


## Ảnh Codex (art_inbox/08_style), có mipmap.
func _art(name: String) -> ImageTexture:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(TEXTURES + name + ".png"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mean(t: ImageTexture) -> Vector3:
	var img: Image = t.get_image()
	img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var c: Color = img.get_pixel(0, 0)
	return Vector3(c.r, c.g, c.b)


func _tex(file: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(DIR + file)))


func _shader(file: String) -> ShaderMaterial:
	var s: Shader = Shader.new()
	s.code = FileAccess.get_file_as_string(DIR + file)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = s
	return m


func _ground(mask: Texture2D, area: float) -> void:
	var m: ShaderMaterial = _shader("ground.gdshader")
	m.set_shader_parameter("mask_tex", mask)
	m.set_shader_parameter("shadow_tex", _tex("out/shadow.png"))
	for k: Array in [["grass_tex", "grass"], ["forest_tex", "grass_dark"], ["dirt_tex", "dirt"], ["pave_tex", "pave"]]:
		m.set_shader_parameter(k[0], _art(k[1]))
	m.set_shader_parameter("area", area)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(area + 40, area + 40)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(area / 2, 0, area / 2)
	mi.material_override = m
	_root.add_child(mi)


func _water(points: Array, mask: Texture2D, area: float) -> void:
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Array in points:
		poly.append(Vector2(p[0], p[1]))
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in idx:
		st.add_vertex(Vector3(poly[i].x, 0.03, poly[i].y))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var m: ShaderMaterial = _shader("water.gdshader")
	m.set_shader_parameter("mask_tex", mask)
	m.set_shader_parameter("bed_tex", _art("riverbed"))
	m.set_shader_parameter("area", area)
	mi.material_override = m
	_root.add_child(mi)


func _items(items: Array) -> void:
	var groups: Dictionary = {}
	for it: Array in items:
		if not groups.has(it[0]):
			groups[it[0]] = []
		groups[it[0]].append(it)
	var plain: ShaderMaterial = _shader("kit.gdshader")
	var faced: Dictionary = {}
	for key: String in FACES:
		var t: ImageTexture = _art(FACES[key][0])
		var fm: ShaderMaterial = _shader("kit_tex.gdshader")
		fm.set_shader_parameter("face_tex", t)
		fm.set_shader_parameter("face_mean", _mean(t))
		fm.set_shader_parameter("meters", FACES[key][1])
		fm.set_shader_parameter("luma_only", FACES[key][2])
		fm.set_shader_parameter("strength", FACES[key][3])
		faced[key] = fm
	for model: String in groups:
		var src: Node3D = (load(MODELS + model + ".glb") as PackedScene).instantiate() as Node3D
		var mesh: Mesh = (src.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		src.free()
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = groups[model].size()
		for i: int in groups[model].size():
			var it: Array = groups[model][i]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, it[3]).scaled(Vector3.ONE * it[4]), Vector3(it[1], it[5] if it.size() > 5 else 0.0, it[2])))
		_triangles += mesh.get_faces().size() / 3 * mm.instance_count
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = plain
		for key: String in faced:
			if model.begins_with(key):
				node.material_override = faced[key]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(node)


func _actors(data: Dictionary) -> void:
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var spots: Array = [[&"brakk", data["hero"], Entity.Kind.HERO], [&"neutral_buffalo", [data["camp"][0] - 1.0, data["camp"][1]], Entity.Kind.NEUTRAL],
		[&"neutral_buffalo", [data["camp"][0] + 1.2, data["camp"][1] + 0.8], Entity.Kind.NEUTRAL]]
	for s: Array in spots:
		var e: Entity = Entity.new()
		e.kind = s[2]
		e.art_id = s[0]
		e.stats = StatBlock.new(w.balance)
		w.add_entity(e)
		var a: Actor3D = Actor3D.make(e)
		_root.add_child(a)
		a.sync(w, e, Vector3(s[1][0], 0, s[1][1]), false, 1000, false)
