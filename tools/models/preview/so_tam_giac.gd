extends SceneTree
## D-367: quay các bản thử mô hình tướng cạnh nhau (thử số tam giác, A2): cùng chiều cao trên sân, ánh sáng trận (Look3D),
## một hoạt ảnh, góc trận hoặc góc cận; dây cung D-349 theo `--strings` (JSON: tên file không đuôi → cấu hình bow_string).
## xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 1280x720 --fixed-fps 30
##   --write-movie out.avi --quit-after 90 -s tools/models/preview/so_tam_giac.gd --
##   --models=a.glb,b.glb --labels=A,B --anim=run --view=game|near [--strings=x.json] [--height=1.3] [--yaw=-20]

var _labels: PackedStringArray = []


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var o: Dictionary = {"anim": "idle", "view": "game", "height": "1.3", "strings": "", "yaw": "-20"}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		o[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var models: PackedStringArray = String(o["models"]).split(",")
	_labels = String(o.get("labels", o["models"])).split(",")
	var strings: Dictionary = {}
	if String(o["strings"]) != "":
		strings = JSON.parse_string(FileAccess.get_file_as_string(String(o["strings"])))
	var world: Node3D = Node3D.new()
	root.add_child(world)
	Look3D.add_lights(world)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mi.mesh = plane
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color("#6f8a55")
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	var gap: float = 1.6
	for i: int in models.size():
		_place(world, models[i], i, models.size(), gap, float(o["height"]), String(o["anim"]), strings, float(o["yaw"]))
	var cam: Camera3D = Camera3D.new()
	world.add_child(cam)
	var w: float = models.size() * gap
	if o["view"] == "game":  # góc camera trận (MatchView3D: lệch (0, 11.5, 11), fov 40) thu theo bề ngang hàng
		cam.fov = 40.0
		cam.position = Vector3(0, 11.5, 11.0) * (w / 14.0) + Vector3(0, 0.6, 0)
		cam.look_at(Vector3(0, 0.6, 0))
	else:
		cam.fov = 30.0
		cam.position = Vector3(0, 1.0, (w * 0.5 + 0.6) / tan(deg_to_rad(25.5)))  # nửa góc ngang ở khung 16:9, fov dọc 30
		cam.look_at(Vector3(0, 0.75, 0))


func _place(world: Node3D, path: String, i: int, n: int, gap: float, h: float, anim: String, strings: Dictionary, yaw: float) -> void:
	var doc: GLTFDocument = GLTFDocument.new()
	var st: GLTFState = GLTFState.new()
	doc.append_from_file(path, st)
	var m: Node3D = doc.generate_scene(st)
	world.add_child(m)
	m.scale = Vector3.ONE * (h / ModelLibrary.bounds(m).size.y)
	m.position.x = (i - (n - 1) / 2.0) * gap
	m.rotation_degrees.y = yaw
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	ap.play(anim)
	var key: String = path.get_file().get_basename()
	if strings.has(key):
		BowString3D.attach(m, strings[key])
	var l: Label3D = Label3D.new()
	l.text = _labels[i]
	l.font_size = 56
	l.pixel_size = 0.0028
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = m.position + Vector3(0, h + 0.3, 0)
	world.add_child(l)
