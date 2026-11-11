extends SceneTree
## Đo khoảng hở cung ↔ chân theo từng hoạt ảnh: godot --headless --path . -s tools/models/preview/bow_clearance.gd -- file.glb Anim1,Anim2
const TIPS: Array[Vector3] = [Vector3(-0.038, -0.0095, 0.2835), Vector3(0.1156, 0.0353, -0.2715)]
const LEGS: Array = [["thigh_l", "calf_l", "foot_l", "ball_l"], ["thigh_r", "calf_r", "foot_r", "ball_r"]]

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var doc: GLTFDocument = GLTFDocument.new()
	var st: GLTFState = GLTFState.new()
	doc.append_from_file(args[0], st)
	var scene: Node = doc.generate_scene(st)
	root.add_child(scene)
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var names: PackedStringArray = args[1].split(",") if args.size() > 1 else ap.get_animation_list()
	var hand: int = skel.find_bone("hand_l")
	for n: String in names:
		if not ap.has_animation(n):
			print(n, " ?"); continue
		var a: Animation = ap.get_animation(n)
		var worst: float = 1e9
		var sum: float = 0.0
		var low: float = 1e9
		var steps: int = 24
		for i: int in steps:
			ap.play(n); ap.seek(a.length * i / steps, true); ap.advance(0.0)
			skel.force_update_all_bone_transforms()
			var xf: Transform3D = skel.get_bone_global_pose(hand)
			var d: float = 1e9
			for k: int in 9:
				var p: Vector3 = xf * TIPS[0].lerp(TIPS[1], k / 8.0)
				low = minf(low, p.y)
				for leg: Array in LEGS:
					for j: int in 3:
						var s0: Vector3 = skel.get_bone_global_pose(skel.find_bone(leg[j])).origin
						var s1: Vector3 = skel.get_bone_global_pose(skel.find_bone(leg[j + 1])).origin
						d = minf(d, Geometry3D.get_closest_point_to_segment(p, s0, s1).distance_to(p))
			worst = minf(worst, d); sum += d
		print("%-22s len %.2f  hở nhỏ nhất %.3f  tb %.3f  đầu cung thấp nhất y=%.2f" % [n, a.length, worst, sum / steps, low])
	quit()
