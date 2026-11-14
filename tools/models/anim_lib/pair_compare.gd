extends SceneTree
## D-398: quay từng cặp hoạt ảnh cạnh nhau — trái `AFK <tên>` (afk.ai trả cho chính tướng), phải `LIB <tên>` (lấy từ
## kho). Lưới nhiều cặp; mỗi cặp phát cùng lúc, lặp lại.
##   xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --fixed-fps 30 --write-movie out.avi
##     --quit-after 150 -s tools/models/anim_lib/pair_compare.gd -- file.glb "A,B,C" [cột] [front|side]
const PAIR_GAP: float = 0.85  # khoảng cách hai bản trong một cặp (đơn vị mô hình)
const CELL: Vector2 = Vector2(2.4, 2.3)  # ô của một cặp: ngang, dọc


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var names: PackedStringArray = args[1].split(",")
	var cols: int = int(args[2]) if args.size() > 2 else 5
	var side: bool = args.size() > 3 and args[3] == "side"
	var world: Node3D = Node3D.new()
	root.add_child(world)
	_light(world)
	var rows: int = int(ceil(names.size() / float(cols)))
	for i: int in names.size():
		var c: int = i % cols
		var r: int = i / cols
		var base: Vector3 = Vector3((c - (cols - 1) / 2.0) * CELL.x, -r * CELL.y, 0)
		for k: int in 2:
			var anim: String = ("AFK " if k == 0 else "LIB ") + names[i]
			var m: Node3D = _model(args[0], anim)
			m.position = base + Vector3((k - 0.5) * PAIR_GAP, 0, 0)
			if side:
				m.rotation_degrees.y = 90
			world.add_child(m)
		_label(world, names[i].replace("_", " "), base + Vector3(0, 1.25, 0), 56)
		_label(world, "afk      kho", base + Vector3(0, -0.12, 0), 40)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	var w: float = cols * CELL.x
	var mid: Vector3 = Vector3(0, -(rows - 1) * CELL.y / 2.0 + 0.55, 0)
	cam.position = mid + Vector3(0, 0.35, w * 1.22)
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
