extends SceneTree
## D-261: đo màn trận THẬT (cảnh 3D, HUD) theo thời gian trận — tướng người chơi do bot điều khiển, mỗi
## `--every` giây trận in bảng FrameProfile (ms từng phần) và bộ đếm, để thấy phần nào tăng dần theo trận.
## Cần cửa sổ (không --headless):
## xvfb-run -a godot --path . -s tools/view_profile.gd -- [--minutes=12] [--every=30] [--speed=1] [--hero=duy_anh]

const SCENE: String = "res://app/match_scene.tscn"

var _scene: Node
var _minutes: float = 12.0
var _every: int = 900
var _speed: int = 1
var _next_report: int = 0
var _started: bool = false


func _initialize() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_minutes = float(args.get("minutes", "12"))
	_every = SimClock.seconds_to_ticks(float(args.get("every", "30")))
	_speed = int(args.get("speed", "1"))
	var script: GDScript = load(SCENE.get_basename() + ".gd") as GDScript
	script.set("hero_id", StringName(args.get("hero", "duy_anh")))
	script.set("bot_hero_id", StringName(args.get("foe", "noctis")))
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	var w: World = _scene.get("world")
	if w == null:
		return false
	if not _started:
		_started = true
		MatchSetup.add_bot(w, _scene.get("hero"))  # người chơi cũng là bot: đi đường, đánh nhau, camera theo
		(_scene.get("runner") as SimRunner).speed = _speed
		print("== view_profile: %s vs %s, %.0f phút, ×%d ==" % [_scene.get("hero_id"), _scene.get("bot_hero_id"), _minutes, _speed])
	if w.tick >= _next_report and FrameProfile.shared.frames > 0:
		_next_report = w.tick + _every
		_report(w)
	return w.tick >= SimClock.seconds_to_ticks(_minutes * 60.0) or w.winner >= 0


func _report(w: World) -> void:
	var p: FrameProfile = FrameProfile.shared
	var parts: PackedStringArray = []
	for r: Array in ProfilePainter.rows(p):
		parts.append("%s %.2f/%.1f" % [String(r[0]).strip_edges(), r[1], r[2]])
	print("[%s] %s | %s" % [MatchHud.clock_text(w.tick), ProfilePainter.header(p), " · ".join(parts)])
	print("        " + " | ".join(ProfilePainter.count_lines(p)))
