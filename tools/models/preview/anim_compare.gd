extends SceneTree
## Quay so sánh các hoạt ảnh chạy cạnh nhau: xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan
##   --fixed-fps 30 --write-movie out.avi --quit-after 150 -s tools/models/preview/anim_compare.gd -- file.glb A,B,C [side|game|front]
func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var names: PackedStringArray = args[1].split(",")
	var view: String = args[2] if args.size() > 2 else "game"
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/units_3d.json"))["units"]["phong_tien"]
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#5a7a52")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.9
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	var gap: float = 1.25
	for i: int in names.size():
		var doc: GLTFDocument = GLTFDocument.new()
		var st: GLTFState = GLTFState.new()
		doc.append_from_file(args[0], st)
		var m: Node3D = doc.generate_scene(st)
		m.position.x = (i - (names.size() - 1) / 2.0) * gap
		if view == "side": m.rotation_degrees.y = 90
		world.add_child(m)
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.get_animation(names[i]).loop_mode = Animation.LOOP_LINEAR
		ap.play(names[i])
		if cfg.has("bow_string"): BowString3D.attach(m, cfg["bow_string"])
		var l: Label3D = Label3D.new()
		l.text = names[i].replace("_", " ")
		l.font_size = 64; l.pixel_size = 0.004; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
		l.position = m.position + Vector3(0, 2.05, 0)
		world.add_child(l)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	var w: float = names.size() * gap
	if view == "game":
		cam.position = Vector3(0, 5.6, 5.0) * (w / 6.2) + Vector3(0, 0.9, 0)
	else:
		cam.position = Vector3(0, 1.0, 7.6 * w / 6.2)
	cam.look_at(Vector3(0, 0.95, 0))
