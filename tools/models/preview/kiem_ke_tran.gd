extends SceneTree
## D-360: ảnh kiểm kê trong trận thật (cảnh 3D + HUD, camera thật). Hai chế độ:
##   mặc định: trận 3v3 bot tự đánh, chụp ở các giây trận `--at=25,75,150` (tốc độ `--speed`);
##   `--lineup`: dừng SIM, xếp cả 10 tướng thành hàng giữa map rồi chụp một ảnh.
## xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 1920x1080
##   -s tools/models/preview/kiem_ke_tran.gd -- --out=art_inbox/kiem_ke/tran [--lineup] [--variant=A|B] [--tag=_a] [--first=brakk]
## D-361: `--variant` thay vật liệu cảnh vật bằng bản thử (thu_vat_lieu.gd); `--tag` nối vào tên ảnh; hàng tướng có thêm 4 lính.

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
			"speed": _speed = int(kv[1])
			"at": at = kv[1]
	for s: String in at.split(","):
		_at.append(SimClock.seconds_to_ticks(float(s)))
	DirAccess.make_dir_recursive_absolute(_out)
	var script: GDScript = load(SCENE.get_basename() + ".gd") as GDScript
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
		if _settle < 12:
			return false
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
