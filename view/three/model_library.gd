class_name ModelLibrary
extends RefCounted
## Tra mô hình 3D theo art_id cho bản thử 3D (D-146), từ assets/models/units_3d.json. Nạp một lần:
## cảnh nhân vật, vũ khí, thư viện hoạt ảnh theo rig, vật liệu màu đội (dùng chung giữa các đơn vị).

const CONFIG: String = "res://assets/models/units_3d.json"
## D-158, D-165: mô hình tĩnh (công trình, cảnh vật) — đường dẫn trong cấu hình tính từ đây.
const MODELS: String = "res://assets/models/"
## D-161: độ đục khi vẽ mờ (VIS-02, VIS-06, ST-11).
const FADED_ALPHA: float = 0.45

static var _config: Dictionary = {}
static var _scenes: Dictionary[String, PackedScene] = {}
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
		_scenes[file] = load(MODELS + file) as PackedScene
	return _scenes[file]


## Hoạt ảnh của một đơn vị (D-173, rig `own`: nằm sẵn trong mô hình; D-321 gỡ rig KayKit dùng chung).
static func unit_animations(cfg: Dictionary) -> AnimationLibrary:
	var holder: Node = scene(cfg["model"] + ".glb").instantiate()
	var ap: AnimationPlayer = holder.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary = ap.get_animation_library(&"")
	holder.free()
	return lib


static func structure(e: Entity) -> Dictionary:
	var key: String = String(e.art_id) + ("_t%d" % e.tier if e.kind == Entity.Kind.TOWER else "")
	return config().get("structures", {}).get(key, {})


static func scenery() -> Dictionary:
	return config().get("scenery", {})


## Cảnh mô hình tĩnh `path` (không đuôi, tính từ assets/models/); `team` 0/1 thêm _blue/_red, khác: giữ nguyên.
## Mô hình tự làm (D-167): `path`.glb, một file cho cả hai đội (ảnh màu theo đội: team_texture); D-203: hoặc
## `path`_blue.glb / _red.glb.
static func static_scene(path: String, team: int = -1) -> PackedScene:
	var suffix: String = "_blue" if team == 0 else ("_red" if team == 1 else "")
	var file: String = path + ".glb"
	for f: String in [path + suffix + ".glb", path + suffix + ".gltf"]:  # D-203: bản theo đội .glb (Blender)
		if not ResourceLoader.exists(MODELS + file):
			file = f
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


## Mô hình tự mang xương (rig `own`): D-209 `team_tex` dùng ảnh màu theo phe
## (<model>_blue / _red.jpg cạnh file GLB, tạo bằng glb_slim.py --team).
static func dress_own(model: Node, cfg: Dictionary, team: int) -> void:
	if cfg.get("team_tex", false):
		apply_team_texture(model, cfg["model"], team)


static func use_vertex_colors_in(root: Node) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		use_vertex_colors((n as MeshInstance3D).mesh)


## D-229: đang được tăng tốc chạy (hệ số MULTIPLY tốc chạy ≥ `sprint_above`, vd Xung Phong) và mô hình có hoạt ảnh
## `sprint` thì chạy dáng nước rút (như Triệu Vân Liên Quân); không thì chạy thường.
## D-245: đang tàng hình (INVISIBLE) và có hoạt ảnh `stealth` thì đi dáng lén.
static func run_anim(cfg: Dictionary, rig_cfg: Dictionary, anim: AnimationPlayer, e: Entity) -> String:
	var stealth: String = cfg.get("stealth", "")
	if not stealth.is_empty() and anim.has_animation(stealth) and Rules.has_state(e, UnitState.Id.INVISIBLE):
		return stealth
	var sprint: String = cfg.get("sprint", rig_cfg.get("sprint", ""))
	var above: float = float(config().get("sprint_above", 1.15))
	if not sprint.is_empty() and anim.has_animation(sprint) and e.stats.multiplier(StatId.Id.MOVEMENT_SPEED) >= above:
		return sprint
	return rig_cfg["run"]


## D-230: tốc độ phát hoạt ảnh chiêu ô `slot`: có thời gian vung và `skill_impact` (phần độ dài tới điểm trúng) thì
## chạy để điểm trúng rơi đúng lúc chiêu nổ; không thì tốc độ mặc định.
static func skill_speed(cfg: Dictionary, slot: int, length: float, windup: float, fallback: float) -> float:
	var impact: float = float(cfg.get("skill_impact", {}).get(str(slot), -1.0))
	if windup <= 0.0 or impact <= 0.0:
		return fallback
	return clampf(length * impact / windup, 0.5, 3.0)


## D-238: tốc độ hoạt ảnh lướt `name` để phần còn lại vừa hết đúng lúc tới mục tiêu (cú bổ của R rơi khi chạm).
static func dash_speed(w: World, e: Entity, anim: AnimationPlayer, name: String) -> float:
	var target: Entity = w.find_entity(e.dash.target_id)
	if target == null or not anim.has_animation(name) or e.dash.speed <= 0.0:
		return 1.4
	var left: float = maxf(0.0, Rules.edge_distance(e, target)) / e.dash.speed + SimClock.TICK_SECONDS
	var pos: float = anim.current_animation_position if anim.current_animation == name else 0.0
	return clampf((anim.get_animation(name).length - pos) / left, 0.5, 4.0)


## D-243: độ nâng hình (m) khi lướt theo vòng cung `dash_hop` (units_3d.json) — hoạt ảnh nhảy tại chỗ của afk.ai;
## tiến độ = vị trí hoạt ảnh lướt (dash_speed cho nó vừa hết lúc tới nơi).
static func dash_hop(cfg: Dictionary, anim: AnimationPlayer) -> float:
	var hop: float = float(cfg.get("dash_hop", 0.0))
	if hop <= 0.0 or anim.current_animation_length <= 0.0:
		return 0.0
	return hop * sin(PI * clampf(anim.current_animation_position / anim.current_animation_length, 0.0, 1.0))


## D-249: hoạt ảnh và điểm trúng của đòn thứ `n`: có `attack_alt` thì đòn lẻ dùng nó (`impact_alt`).
static func attack_pick(cfg: Dictionary, n: int, fallback: float) -> Array:
	if cfg.has("attack_alt") and n % 2 == 1:
		return [cfg["attack_alt"], float(cfg.get("impact_alt", cfg.get("impact", fallback)))]
	return [cfg["attack"], float(cfg.get("impact", fallback))]


## CRP-12 (D-346): lính siêu cấp (1) / siêu lính (2) to hơn — hệ số trong units_3d.json `creep_tier_scale`.
static func tier_scale(tier: int) -> float:
	var k: Array = config().get("creep_tier_scale", [1.0, 1.15, 1.3])
	return float(k[clampi(tier, 0, k.size() - 1)])
