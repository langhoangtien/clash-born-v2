class_name ModelLibrary
extends RefCounted
## Tra mô hình 3D theo art_id cho bản thử 3D (D-146), từ assets/models/units_3d.json. Nạp một lần:
## cảnh nhân vật, vũ khí, thư viện hoạt ảnh theo rig, vật liệu màu đội (dùng chung giữa các đơn vị).

const ROOT: String = "res://assets/models/kaykit/"
const CONFIG: String = "res://assets/models/units_3d.json"
## D-158, D-165: mô hình tĩnh (công trình, cảnh vật) — đường dẫn trong cấu hình tính từ đây.
const MODELS: String = "res://assets/models/"
## D-161: độ đục khi vẽ mờ (VIS-02, VIS-06, ST-11).
const FADED_ALPHA: float = 0.45

static var _config: Dictionary = {}
static var _scenes: Dictionary[String, PackedScene] = {}
static var _libs: Dictionary[String, AnimationLibrary] = {}
static var _materials: Dictionary[String, Material] = {}
## D-161: bản trong suốt của từng vật liệu (theo id vật liệu gốc).
static var _faded: Dictionary[int, Material] = {}


static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return _config


## Cấu hình của art_id (rỗng nếu vẽ bằng ảnh đứng).
static func unit(art_id: StringName) -> Dictionary:
	return config()["units"].get(String(art_id), {})


static func rig(name: String) -> Dictionary:
	return config()["rigs"][name]


static func scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		_scenes[file] = load(ROOT + file) as PackedScene
	return _scenes[file]


## Mọi hoạt ảnh của rig gộp vào một thư viện (đường dẫn rãnh "Rig_x/Skeleton3D:xương" khớp mọi nhân vật).
static func animations(rig_name: String) -> AnimationLibrary:
	if _libs.has(rig_name):
		return _libs[rig_name]
	var lib: AnimationLibrary = AnimationLibrary.new()
	for s: String in rig(rig_name)["sets"]:
		var holder: Node = scene("%s_%s.glb" % [rig_name, s]).instantiate()
		var ap: AnimationPlayer = holder.find_children("*", "AnimationPlayer", true, false)[0]
		for n: StringName in ap.get_animation_list():
			if not lib.has_animation(n):
				lib.add_animation(n, ap.get_animation(n))
		holder.free()
	_libs[rig_name] = lib
	return lib


## Vật liệu dùng bảng màu `tex` theo đội (0 xanh, 1 đỏ, khác: gốc), sao từ vật liệu gốc `base`.
static func team_material(base: Material, tex: String, team: int) -> Material:
	var key: String = "%s_%d" % [tex, team]
	if _materials.has(key):
		return _materials[key]
	var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	if m == null:
		return base
	var suffix: String = "_blue" if team == 0 else ("_red" if team == 1 else "")
	m.albedo_texture = load(ROOT + tex + "_texture" + suffix + ".png") as Texture2D
	m.rim_enabled = true  # D-150: viền sáng nhẹ cho nhân vật nổi khỏi nền
	m.rim = 0.25
	m.rim_tint = 0.4
	m.roughness = 0.8
	_materials[key] = m
	return m


## D-158: cấu hình mô hình công trình của `e` (trụ theo bậc), rỗng nếu vẽ bằng ảnh đứng.
static func structure(e: Entity) -> Dictionary:
	var key: String = String(e.art_id) + ("_t%d" % e.tier if e.kind == Entity.Kind.TOWER else "")
	return config().get("structures", {}).get(key, {})


static func scenery() -> Dictionary:
	return config().get("scenery", {})


## Cảnh mô hình tĩnh `path` (không đuôi, tính từ assets/models/); `team` 0/1 thêm _blue/_red, khác: giữ nguyên.
## Mô hình tự làm (D-167): `path`.glb, một file cho cả hai đội (ảnh màu theo đội: team_texture).
static func static_scene(path: String, team: int = -1) -> PackedScene:
	var file: String = path + ".glb"
	if not ResourceLoader.exists(MODELS + file):
		file = path + ("_blue" if team == 0 else ("_red" if team == 1 else "")) + ".gltf"
	if not _scenes.has(MODELS + file):
		_scenes[MODELS + file] = load(MODELS + file) as PackedScene
	return _scenes[MODELS + file]


## Khối bao các lưới trong `root` (tọa độ của root).
static func bounds(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var b: AABB = _relative(root, mi) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## D-161: bản mờ của `base` (ALPHA, độ đục FADED_ALPHA; vẽ độ sâu trước để thân không tự xuyên thấu).
## Trình vẽ Compatibility không dùng GeometryInstance3D.transparency nên phải đổi vật liệu.
static func faded_material(base: Material) -> Material:
	var key: int = base.get_instance_id()
	if not _faded.has(key):
		var m: BaseMaterial3D = base.duplicate() as BaseMaterial3D
		if m == null:
			return base
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.albedo_color.a = FADED_ALPHA
		_faded[key] = m
	return _faded[key]


## D-167: mô hình tự làm có ảnh màu theo đội cạnh file (`path`_blue / _red, .jpg hoặc .png) → đổi ảnh của mọi bề mặt.
static func apply_team_texture(root: Node, path: String, team: int) -> void:
	if team < 0 or team > 1:
		return
	var tex_path: String = MODELS + path + ("_blue" if team == 0 else "_red") + ".jpg"
	if not ResourceLoader.exists(tex_path):
		tex_path = tex_path.trim_suffix(".jpg") + ".png"
	if not ResourceLoader.exists(tex_path):
		return
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		for i: int in mi.mesh.get_surface_count():
			var key: String = tex_path + str(mi.mesh.surface_get_material(i).get_instance_id())
			if not _materials.has(key):
				var m: StandardMaterial3D = mi.mesh.surface_get_material(i).duplicate() as StandardMaterial3D
				m.albedo_texture = load(tex_path) as Texture2D
				_materials[key] = m
			mi.set_surface_override_material(i, _materials[key])


## D-167: lưới có màu theo đỉnh (COLOR_0) mà vật liệu không có ảnh màu → dùng màu đỉnh làm màu
## (trình nhập glTF của Godot không tự bật). Sửa thẳng vật liệu của lưới, một lần.
static func use_vertex_colors(mesh: Mesh) -> void:
	for i: int in mesh.get_surface_count():
		var m: BaseMaterial3D = mesh.surface_get_material(i) as BaseMaterial3D
		if m == null or m.albedo_texture != null or m.vertex_color_use_as_albedo:
			continue
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true


static func use_vertex_colors_in(root: Node) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		use_vertex_colors((n as MeshInstance3D).mesh)
