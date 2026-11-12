extends SceneTree
## D-360: ảnh kiểm kê trong trận thật (cảnh 3D + HUD, camera thật). Hai chế độ:
##   mặc định: trận 3v3 bot tự đánh, chụp ở các giây trận `--at=25,75,150` (tốc độ `--speed`);
##   `--lineup`: dừng SIM, xếp cả 10 tướng thành hàng giữa map rồi chụp một ảnh.
## xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 1920x1080
##   -s tools/models/preview/kiem_ke_tran.gd -- --out=art_inbox/kiem_ke/tran [--lineup] [--variant=A|B] [--tag=_a] [--first=brakk]
## D-367: `--swap=<glb>` thay mô hình Phong Tiễn bằng bản thử (chỉ trong lần chạy, không ghi file; `--strings=<json>` +
## `--key=<tên>`: dây cung của bản thử); `--swap-all`: mọi tướng dùng mô hình đó (đo cảnh 6 tướng mức cao nhất);
## `--sample=old|new` (D-368, chỉ với --lineup): đặt một cụm 2 cây + 2 bụi quanh hàng tướng — `old` cây / bụi hiện có, `new`
## mẫu tree_clump / bush_clump — để so trước / sau cùng chỗ (không đổi dữ liệu map). `--hold=<khung>` chờ trước khi chụp (để quay video); `--measure=<khung>`: sau khi xếp hàng, đo thời gian khung trung bình + số tam giác vẽ, in ra rồi thoát.
## D-361: `--variant` thay vật liệu cảnh vật bằng bản thử (thu_vat_lieu.gd); `--tag` nối vào tên ảnh; hàng tướng có thêm 4 lính.

const Concept: GDScript = preload("res://tools/models/preview/dat_concept.gd")
const Trial: GDScript = preload("res://tools/models/preview/thu_vat_lieu.gd")
const SCENE: String = "res://app/match_scene.tscn"
const TEAMS: Array[StringName] = [&"phong_tien", &"brakk", &"myra", &"noctis", &"vexa", &"gorran"]
const OTHERS: Array[StringName] = [&"duy_anh", &"huyet_cu_nhan", &"thach_giap", &"tho_san"]
const GAP: float = 170.0  ## px thế giới giữa hai tướng trong hàng
const LANE_SHIFT: Vector2 = Vector2(-300, 0)  ## từ giữa map sang giữa lane giữa
const LANE_DIR: Vector2 = Vector2(0.78, -0.62)  ## hướng lane giữa (hàng tướng nằm dọc lane cho khỏi bị đá / cỏ che)

var _scene: Node
var _out: String = ""
var _lineup: bool = false
var _variant: String = ""
var _tag: String = ""
var _swap: String = ""
var _swap_all: bool = false
var _strings: String = ""
var _key: String = ""
var _measure: int = 0
var _sample_kind: String = ""
var _cutouts: String = ""
var _cut_scale: float = 1.0
var _hold: int = 12  ## khung chờ trước khi chụp hàng tướng (quay video: --hold=120)
var _times: PackedFloat64Array = []
var _prims: int = 0
var _last_us: int = 0
var _first: StringName = &""  ## tướng người chơi (ô 0); đổi chỗ với tướng đang ở ô đó
var _speed: int = 4
var _at: Array[int] = []
var _started: bool = false
var _settle: int = 0


func _initialize() -> void:
	var at: String = "25,75,150"
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		match kv[0]:
			"out": _out = kv[1]
			"lineup": _lineup = true
			"variant": _variant = kv[1]
			"tag": _tag = kv[1]
			"first": _first = StringName(kv[1])
			"swap": _swap = kv[1]
			"swap-all": _swap_all = true
			"strings": _strings = kv[1]
			"key": _key = kv[1]
			"measure": _measure = int(kv[1])
			"hold": _hold = int(kv[1])
			"sample": _sample_kind = kv[1]
			"cutouts": _cutouts = kv[1]
			"cut-scale": _cut_scale = float(kv[1])
			"speed": _speed = int(kv[1])
			"at": at = kv[1]
	for s: String in at.split(","):
		_at.append(SimClock.seconds_to_ticks(float(s)))
	DirAccess.make_dir_recursive_absolute(_out)
	var script: GDScript = load(SCENE.get_basename() + ".gd") as GDScript
	if _swap != "":
		_inject()
	if _measure > 0:
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var teams: Array[StringName] = TEAMS.duplicate()
	if _first != &"" and teams.has(_first):
		teams[teams.find(_first)] = teams[0]
		teams[0] = _first
	script.set("config", MatchConfig.make(3, teams, [0], BotState.Difficulty.NORMAL, 3))
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	var w: World = _scene.get("world")
	if w == null:
		return false
	var loading: Variant = _scene.get("loading")
	if loading != null and not loading.call("finished"):
		return false
	if not _started:
		_started = true
		_restyle()
		if _lineup:
			_line_up(w)
		else:
			MatchSetup.add_bot(w, _scene.get("hero"))
			(_scene.get("runner") as SimRunner).speed = _speed
		return false
	if _lineup:
		_settle += 1
		if _settle < _hold:
			return false
		if _measure > 0:
			return _sample()
		_shot("hang_tuong")
		return true
	if w.tick >= _at[0]:
		_shot("tran_%03ds" % roundi(SimClock.ticks_to_seconds(_at[0])))
		_at.remove_at(0)
	return _at.is_empty() or w.winner >= 0


func _shot(name: String) -> void:
	root.get_texture().get_image().save_jpg("%s/%s%s.jpg" % [_out, name, _tag], 0.92)
	print("chụp ", name)


func _line_up(w: World) -> void:
	(_scene.get("runner") as SimRunner).paused = true
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var me: Entity = _scene.get("hero")
	var heroes: Array[Entity] = []
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.HERO:
			heroes.append(e)
	var center: Vector2 = w.navigation(me.radius).nearest_clear(w.map.world_size() * 0.5 + Vector2(120, 150))
	for id: StringName in OTHERS:
		heroes.append(UnitFactory.hero(w, lib.heroes[id], 0, center))
	var n: int = heroes.size()
	heroes.erase(me)
	heroes.insert(n / 2, me)  # camera theo tướng người chơi → đặt giữa hàng
	for i: int in n:
		heroes[i].position = center + LANE_SHIFT + LANE_DIR * ((i - n / 2) * GAP)
		heroes[i].facing = Vector2.DOWN
	if _sample_kind != "":
		_plant(center + LANE_SHIFT)
	if _cutouts != "":
		var across: Vector2 = Vector2(LANE_DIR.y, -LANE_DIR.x)
		var row: Vector2 = center + LANE_SHIFT - across * 230.0
		var ids: PackedStringArray = PackedStringArray(["huyet_cu_nhan", "thach_giap", "myra", "noctis", "vexa", "gorran", "phong_tien", "tho_san", "brakk", "duy_anh"])
		Concept.place(_scene.get("view_3d") as Node3D, _cutouts, ids, row, LANE_DIR, GAP, _cut_scale)
		Concept.tower(_scene.get("view_3d") as Node3D, row - LANE_DIR * (GAP * 6.0) - across * 60.0)
	for i: int in 4:  # lính để so độ nổi với cảnh vật
		var def: UnitDef = load("res://content/units/creep_%s.tres" % ("ranged" if i == 3 else "melee")) as UnitDef
		var c: Entity = UnitFactory.unit(w, def, Entity.Kind.LANE_CREEP, i % 2, center + LANE_SHIFT + Vector2(160 + i * 70, 190 + i * 30))
		c.facing = Vector2.DOWN


## D-361: thay vật liệu cảnh vật theo phương án thử (cả map).
func _restyle() -> void:
	if _variant.is_empty():
		return
	for n: Node in _scene.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi: MultiMeshInstance3D = n as MultiMeshInstance3D
		var m: Material = Trial.material_for(Trial.model_of(mmi.multimesh.mesh), _variant)
		if m != null:
			mmi.material_override = m


## D-367: đặt bản thử vào bộ nhớ đệm của ModelLibrary trước khi dựng đơn vị (không đổi file nào).
func _inject() -> void:
	var doc: GLTFDocument = GLTFDocument.new()
	var st: GLTFState = GLTFState.new()
	doc.append_from_file(_swap, st)
	var packed: PackedScene = PackedScene.new()
	packed.pack(doc.generate_scene(st))
	var units: Dictionary = ModelLibrary.config()["units"]
	var ids: Array = [&"phong_tien"]
	if _swap_all:
		ids = TEAMS + OTHERS
	var cfg: Dictionary = {}
	if _strings != "":
		cfg = (JSON.parse_string(FileAccess.get_file_as_string(_strings)) as Dictionary).get(_key, {})
	for id: StringName in ids:
		var u: Dictionary = units[String(id)]
		ModelLibrary._scenes[String(u["model"]) + ".glb"] = packed
		u["height"] = units["phong_tien"]["height"] if _swap_all else u["height"]
		u.erase("effect_looks")
		if not cfg.is_empty():
			u["bow_string"] = cfg


## D-367: đo `_measure` khung (thời gian thật giữa hai khung, tam giác vẽ) rồi in một dòng.
func _sample() -> bool:
	var now: int = Time.get_ticks_usec()
	if _last_us > 0:
		_times.append((now - _last_us) / 1000.0)
	_last_us = now
	_prims = maxi(_prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	if _times.size() < _measure:
		return false
	var sorted: PackedFloat64Array = _times.duplicate()
	sorted.sort()
	var sum: float = 0.0
	for t: float in _times:
		sum += t
	print("do_khung%s: %.2f ms/khung (trung vị %.2f), %.1f fps, %d tam giác / khung" % [_tag, sum / _times.size(), sorted[sorted.size() / 2], 1000.0 * _times.size() / sum, _prims])
	return true


## D-368: cụm cây / bụi thử quanh hàng tướng (px thế giới tính từ giữa hàng, dọc LANE_DIR / vuông góc), cùng chỗ cho cả hai bộ.
func _plant(at: Vector2) -> void:
	var across: Vector2 = Vector2(LANE_DIR.y, -LANE_DIR.x)
	var spots: Array = [["tree", -120.0, -420.0], ["bush", 60.0, 250.0], ["tree", 360.0, 380.0], ["bush", -430.0, -260.0]]
	var models: Dictionary = {"old": {"tree": "tree_round", "bush": "bush_a"}, "new": {"tree": "tree_clump", "bush": "bush_clump"}}
	var parent: Node3D = (_scene.get("view_3d") as Node3D)
	for s: Array in spots:
		var name: String = models[_sample_kind][s[0]]
		var n: Node3D = ModelLibrary.static_scene("style/" + name).instantiate() as Node3D
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			ModelLibrary.use_vertex_colors(mi.mesh)
			mi.material_override = Terrain3D.material_for(name)
		var p: Vector2 = at + LANE_DIR * float(s[1]) + across * float(s[2])
		n.position = Vector3(p.x, 0, p.y) * MatchView3D.S
		parent.add_child(n)
