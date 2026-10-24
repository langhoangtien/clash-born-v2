class_name ModelLibrary
extends RefCounted
## Tra mô hình 3D theo art_id cho bản thử 3D (D-146), từ assets/models/units_3d.json. Nạp một lần:
## cảnh nhân vật, vũ khí, thư viện hoạt ảnh theo rig, vật liệu màu đội (dùng chung giữa các đơn vị).

const ROOT: String = "res://assets/models/kaykit/"
const CONFIG: String = "res://assets/models/units_3d.json"

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
	_materials[key] = m
	return m
