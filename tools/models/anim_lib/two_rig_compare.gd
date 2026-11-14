extends SceneTree
## D-399: hai file cùng tên hoạt ảnh cạnh nhau — trái file A (afk gắn xương), phải file B (tự gắn). Lưới nhiều cặp.
##   xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --fixed-fps 30 --write-movie out.avi
##     --quit-after 180 -s tools/models/anim_lib/two_rig_compare.gd -- a.glb b.glb "A,B" [cột] [zoom] [nhãn trái] [nhãn phải]
## zoom > 1: máy quay gần hơn, nhìn chéo 3/4 để thấy vai / khuỷu / hông / gối.
const PAIR_GAP: float = 0.8
const CELL: Vector2 = Vector2(2.2, 2.3)


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var names: PackedStringArray = args[2].split(",")
	var cols: int = int(args[3]) if args.size() > 3 else 4
	var zoom: float = float(args[4]) if args.size() > 4 else 1.0
	var tags: PackedStringArray = [args[5] if args.size() > 5 else "afk", args[6] if args.size() > 6 else "tự gắn"]
	var world: Node3D = Node3D.new()
	root.add_child(world)
	_light(world)
	var rows: int = int(ceil(names.size() / float(cols)))
	for i: int in names.size():
		var base: Vector3 = Vector3((i % cols - (cols - 1) / 2.0) * CELL.x, -(i / cols) * CELL.y, 0)
		for k: int in 2:
			var m: Node3D = _model(args[k], names[i])
			m.position = base + Vector3((k - 0.5) * PAIR_GAP, 0, 0)
			if zoom > 1.0:
				m.rotation_degrees.y = 25
			world.add_child(m)
		_label(world, names[i].replace("_", " "), base + Vector3(0, 1.2, 0), 56)
		_label(world, tags[0] + "      " + tags[1], base + Vector3(0, -0.12, 0), 40)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	var mid: Vector3 = Vector3(0, -(rows - 1) * CELL.y / 2.0 + 0.5, 0)
	cam.position = mid + Vector3(0, 0.35, cols * CELL.x * 1.22 / zoom)
	cam.look_at(mid)


func _model(path: String, anim: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var st: GLTFState = GLTFState.new()
	doc.append_from_file(path, st)
	var m: Node3D = doc.generate_scene(st)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	ap.play(anim)
	return m


func _light(world: Node3D) -> void:
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


func _label(world: Node3D, text: String, at: Vector3, size: int) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	world.add_child(l)
