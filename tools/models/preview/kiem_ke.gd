extends SceneTree
## D-360: chụp kiểm kê mô hình — mỗi mô hình một ảnh "phòng chụp" (cùng góc, cùng ánh sáng trận Look3D, cùng tỉ lệ
## trong nhóm) + số đo (tam giác, xương, hoạt ảnh, cỡ ảnh màu) ghi ra `stats.json`. Cần cửa sổ:
##   xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 640x800
##     -s tools/models/preview/kiem_ke.gd -- --out=art_inbox/kiem_ke/models [--yaw=-28] [--only=hero] [--variant=A|B]

const Trial: GDScript = preload("res://tools/models/preview/thu_vat_lieu.gd")
const STYLE_DIR: String = "res://assets/models/style/"
const BACKDROP: Color = Color("#8c9188")  ## nền xám trung tính để so bảng màu
const WAIT_FRAMES: int = 4

## nhóm → khung cao (m trên sân) mà camera ôm trọn: cùng nhóm cùng tỉ lệ.
const FRAME: Dictionary = {"hero": 2.0, "creep": 2.0, "creature": 2.0, "boss": 4.2, "structure": 6.0, "fx": 1.6}
## cảnh vật: khung nhỏ nhất ôm trọn vật (cao hoặc rộng)
const SCENERY_FRAMES: Array[float] = [1.4, 2.8, 6.4]

var _out: String = ""
var _items: Array[Dictionary] = []
var _stats: Array[Dictionary] = []
var _stage: Node3D
var _cam: Camera3D
var _index: int = -1
var _frames: int = 0
var _decor_scale: Dictionary = {}
var _yaw: float = -28.0  ## quay 3/4 về bên phải camera
var _only: String = ""
var _variant: String = ""  ## D-361: vật liệu bản thử cho cảnh vật


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		match kv[0]:
			"out": _out = kv[1]
			"yaw": _yaw = float(kv[1])
			"only": _only = kv[1]
			"variant": _variant = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	Look3D.add_lights(world)
	var env: Environment = (world.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	env.background_color = BACKDROP
	env.fog_enabled = false
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mi.mesh = plane
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = BACKDROP.darkened(0.12)
	floor_mi.material_override = fm
	world.add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	world.add_child(_cam)
	_stage = Node3D.new()
	world.add_child(_stage)
	_collect()


func _collect() -> void:
	var cfg: Dictionary = ModelLibrary.config()
	for it: Array in Terrain3D.items():
		var k: String = it[0]
		if not _decor_scale.has(k):
			_decor_scale[k] = []
		_decor_scale[k].append(float(it[4]))
	for id: String in cfg["units"]:
		var u: Dictionary = cfg["units"][id]
		var h: float = u["height"]
		var group: String = "hero" if String(u["model"]).contains("/heroes/") else ("creep" if String(u["model"]).contains("/units/") else ("boss" if h > 2.0 else "creature"))
		_items.append({"id": id, "group": group, "kind": "unit", "cfg": u, "height": h, "borrowed": String(u.get("_tam", ""))})
	for id: String in cfg["structures"]:
		if id in ["tower_t2", "tower_t3"]:
			continue  # cùng mô hình tower, chỉ khác chiều cao
		for team: int in 2:
			_items.append({"id": "%s_%s" % [id, ["blue", "red"][team]], "group": "structure", "kind": "static", "cfg": cfg["structures"][id], "height": cfg["structures"][id]["height"], "team": team})
	for id: String in ["shop", "rubble", "fountain"]:
		_items.append({"id": id, "group": "structure", "kind": "static", "cfg": cfg["scenery"][id], "height": cfg["scenery"][id]["height"], "team": 0 if id == "fountain" else -1})
	for f: String in DirAccess.get_files_at(STYLE_DIR):
		if f.ends_with(".glb"):
			_items.append({"id": f.get_basename(), "group": "scenery", "kind": "kit"})
	for f: String in DirAccess.get_files_at(STYLE_DIR + "fx/"):
		if f.ends_with(".glb"):
			_items.append({"id": f.get_basename(), "group": "fx", "kind": "static", "cfg": {"model": "style/fx/" + f.get_basename()}, "height": 0.6, "team": -1})


func _process(_delta: float) -> bool:
	_frames += 1
	if _index >= 0 and _frames < WAIT_FRAMES:
		return false
	if _index >= 0:
		root.get_texture().get_image().save_png("%s/%s__%s.png" % [_out, _items[_index]["group"], _items[_index]["id"]])
	_index += 1
	_frames = 0
	while _index < _items.size() and not _only.is_empty() and _items[_index]["group"] != _only:
		_index += 1
	if _index >= _items.size():
		var f: FileAccess = FileAccess.open(_out + "/stats.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(_stats, " "))
		f.close()
		print("kiem_ke: %d mô hình" % _stats.size())
		return true
	_show(_items[_index])
	return false


func _show(item: Dictionary) -> void:
	for c: Node in _stage.get_children():
		c.free()
	var model: Node3D
	var h: float = float(item.get("height", 0.0))
	if item["kind"] == "unit":
		model = _unit(item["cfg"], h)
	elif item["kind"] == "static":
		model = _static(item["cfg"], h, int(item.get("team", -1)))
	else:
		model = _kit(item)
		h = float(item["height"])
	_stage.add_child(model)
	model.rotation.y = deg_to_rad(_yaw)
	var frame: float = FRAME.get(item["group"], 0.0)
	if item["group"] == "scenery":
		frame = SCENERY_FRAMES[-1]
		for i: int in range(SCENERY_FRAMES.size() - 1, -1, -1):
			if SCENERY_FRAMES[i] >= maxf(h, float(item["width"]) * 1.35) * 1.08:
				frame = SCENERY_FRAMES[i]
	var dist: float = frame * 0.5 / tan(deg_to_rad(_cam.fov * 0.5)) * 1.12
	_cam.position = Vector3(0, frame * 0.5 + dist * 0.26, dist)
	_cam.look_at(Vector3(0, frame * 0.46, 0))
	var s: Dictionary = _measure(model)
	s.merge({"id": item["id"], "group": item["group"], "height": snappedf(h, 0.01), "frame": frame, "borrowed": item.get("borrowed", ""), "placed": item.get("placed", 0), "model": String(item.get("cfg", {}).get("model", "style/" + String(item["id"])))})
	_stats.append(s)


func _unit(cfg: Dictionary, h: float) -> Node3D:
	var m: Node3D = ModelLibrary.scene(cfg["model"] + ".glb").instantiate() as Node3D
	m.scale = Vector3.ONE * (h / ModelLibrary.bounds(m).size.y)
	ModelLibrary.dress_own(m, cfg, 0)
	var aps: Array[Node] = m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty() and (aps[0] as AnimationPlayer).has_animation("idle"):
		(aps[0] as AnimationPlayer).play("idle")
		(aps[0] as AnimationPlayer).seek(0.3, true)
		(aps[0] as AnimationPlayer).pause()
	if cfg.has("bow_string"):
		BowString3D.attach(m, cfg["bow_string"])
	return m


func _static(cfg: Dictionary, h: float, team: int) -> Node3D:
	var holder: Node3D = Node3D.new()
	var n: Node3D = ModelLibrary.static_scene(cfg["model"], team).instantiate() as Node3D
	ModelLibrary.apply_team_texture(n, cfg["model"], team)
	ModelLibrary.use_vertex_colors_in(n)
	holder.add_child(n)
	var box: AABB = ModelLibrary.bounds(n)
	var k: float = h / maxf(0.01, box.size.y)
	n.scale = Vector3.ONE * k
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	return holder


## Cảnh vật bộ style: vật liệu của trận (Terrain3D.material_for), cỡ = cỡ gốc × cỡ trung vị đặt trên map.
func _kit(item: Dictionary) -> Node3D:
	var id: String = item["id"]
	var holder: Node3D = Node3D.new()
	var n: Node3D = ModelLibrary.static_scene("style/" + id).instantiate() as Node3D
	var scales: Array = _decor_scale.get(id, [1.0])
	scales.sort()
	var k: float = scales[scales.size() / 2] * float(ModelLibrary.scenery()["style"].get("decor_scale", {}).get(id, 1.0))  # D-362
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		ModelLibrary.use_vertex_colors(mi.mesh)
		var trial: Material = Trial.material_for(id, _variant)
		mi.material_override = trial if trial != null else Terrain3D.material_for(id)
	holder.add_child(n)
	var box: AABB = ModelLibrary.bounds(n)
	n.scale = Vector3.ONE * k
	n.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
	item["height"] = box.size.y * k
	item["width"] = maxf(box.size.x, box.size.z) * k
	item["placed"] = _decor_scale.get(id, []).size()
	return holder


func _measure(model: Node3D) -> Dictionary:
	var tris: int = 0
	var tex: Array[String] = []
	var vcol: bool = false
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(i)
			tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			vcol = vcol or arr[Mesh.ARRAY_COLOR] != null
			var mat: BaseMaterial3D = mi.get_active_material(i) as BaseMaterial3D
			if mat != null and mat.albedo_texture != null:
				var t: String = "%d×%d" % [mat.albedo_texture.get_width(), mat.albedo_texture.get_height()]
				if not tex.has(t):
					tex.append(t)
	var bones: int = 0
	for sk: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		bones += sk.get_bone_count()
	var anims: int = 0
	for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		anims += ap.get_animation_list().size()
	return {"tris": tris, "bones": bones, "anims": anims, "tex": tex, "vertex_color": vcol and tex.is_empty()}
