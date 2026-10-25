class_name ModelLibrary
extends RefCounted
## Tra mô hình 3D theo art_id cho bản thử 3D (D-146), từ assets/models/units_3d.json. Nạp một lần:
## cảnh nhân vật, vũ khí, thư viện hoạt ảnh theo rig, vật liệu màu đội (dùng chung giữa các đơn vị).

const ROOT: String = "res://assets/models/kaykit/"
const CONFIG: String = "res://assets/models/units_3d.json"
## D-158: công trình, cảnh vật (KayKit Medieval Hexagon).
const MEDIEVAL: String = "res://assets/models/medieval/"

static var _config: Dictionary = {}
static var _scenes: Dictionary[String, PackedScene] = {}
static var _libs: Dictionary[String, AnimationLibrary] = {}
static var _materials: Dictionary[String, Material] = {}


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


## Cảnh mô hình tĩnh `path` (không đuôi) trong thư mục Medieval; `team` 0/1 thêm _blue/_red, khác: giữ nguyên.
static func medieval(path: String, team: int = -1) -> PackedScene:
	var file: String = path + ("_blue" if team == 0 else ("_red" if team == 1 else "")) + ".gltf"
	if not _scenes.has(MEDIEVAL + file):
		_scenes[MEDIEVAL + file] = load(MEDIEVAL + file) as PackedScene
	return _scenes[MEDIEVAL + file]


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
