extends SceneTree
## D-373: tìm hướng đặt cung trong xương tay (24 hướng vuông góc) — mỗi hướng một bản mô hình ở cùng khung của một hoạt ảnh,
## cung gắn BoneAttachment3D, đánh số để chọn. Hướng: cung ở tư thế chuẩn (dài theo y, dây ở −x, mỏng theo z) rồi xoay
## `ROTS[i]` trong hệ xương.
## xvfb-run -a godot --path . --resolution 1920x1080 -s tools/models/preview/thu_cam_cung.gd --
##   --body=x.glb --bow=cung_chuẩn.glb --bone=mixamorig_LeftHand (Godot đổi ":" thành "_") --anim="standing aim overdraw" --time=1.6 --out=ảnh.png

var _out: String = ""
var _frames: int = 0


func _initialize() -> void:
	var o: Dictionary = {"time": "1.0", "size": "0.62", "reach": "0.04"}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		o[kv[0]] = kv[1]
	_out = o["out"]
	var world: Node3D = Node3D.new()
	root.add_child(world)
	Look3D.add_lights(world)
	var rots: Array[Vector3] = []
	for x: int in 4:
		for y: int in 4:
			for z: int in 4:
				var b: Basis = Basis.from_euler(Vector3(x, y, z) * PI * 0.5)
				var dup: bool = false
				for r: Vector3 in rots:
					if Basis.from_euler(r * PI * 0.5).is_equal_approx(b):
						dup = true
				if not dup:
					rots.append(Vector3(x, y, z))
	for i: int in rots.size():
		_one(world, o, rots[i], i)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	cam.position = Vector3(2.4, 1.2, 9.0)
	cam.look_at(Vector3(2.4, 0.9, 0))


func _one(world: Node3D, o: Dictionary, r: Vector3, i: int) -> void:
	var m: Node3D = _load(o["body"])
	m.position = Vector3((i % 6) * 0.95, -(i / 6) * 1.25 + 2.2, 0)
	m.rotation_degrees.y = float(o.get("yaw", "-60"))
	world.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play(o["anim"])
	ap.seek(float(o["time"]), true)
	ap.pause()
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var att: BoneAttachment3D = BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = o["bone"]
	var bow: Node3D = _load(o["bow"])
	var box: AABB = ModelLibrary.bounds(bow)
	var tall: float = float(o.get("tall", "1.0"))  # thân Tripo cao ~1 m
	var sc: float = (sk.get_parent() as Node3D).transform.basis.get_scale().x  # Mixamo: Armature × 0,01 (cm)
	var pivot: Node3D = Node3D.new()  # hệ xương tay, bỏ tỉ lệ của Armature
	pivot.basis = Basis.from_euler(r * PI * 0.5).scaled(Vector3.ONE / sc)
	pivot.position = Vector3(0, float(o["reach"]) * tall / sc, 0)
	att.add_child(pivot)
	var k: float = float(o["size"]) * tall / box.size.y
	bow.scale = Vector3.ONE * k
	bow.position = -box.get_center() * k
	pivot.add_child(bow)
	var l: Label3D = Label3D.new()
	l.text = "%d (%d,%d,%d)" % [i, r.x, r.y, r.z]
	l.font_size = 40
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = m.position + Vector3(0, 1.1, 0)
	world.add_child(l)


func _load(path: String) -> Node3D:
	var doc: GLTFDocument = GLTFDocument.new()
	var st: GLTFState = GLTFState.new()
	doc.append_from_file(path, st)
	return doc.generate_scene(st)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_texture().get_image().save_png(_out)
		return true
	return false
