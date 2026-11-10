extends SceneTree
## M9.5 (D-338): thử máy chủ phòng thật — hai máy khách bot trong một tiến trình: A tạo phòng 1v1, B vào bằng mã, chọn
## tướng, A bắt đầu, cả hai ra lệnh ngẫu nhiên `--seconds` giây; in RTT, trễ bấm → hiệu lực, đứng hình, lệch.
##   godot --headless --path . -s tools/net_client.gd -- --url=wss://clashborn.quest/play --token=<phiên A> --token2=<phiên B>
## Phiên thử: POST /api/admin/test_session {name} (mã quản trị). Thử ở máy mình: server/main.gd --dev-auth, token name:A.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

var _args: Dictionary = {}
var _bots: Array[Dictionary] = []   ## {ws, lock, hero, msgs, name}
var _t0: int = 0
var _phase: String = "connect"
var _code: String = ""
var _lib: ContentLibrary


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_lib = ContentLibrary.load_dir()
	var url: String = _args.get("url", "ws://127.0.0.1:8790")
	for t: String in [_args.get("token", "name:A"), _args.get("token2", "name:B")]:
		_bots.append({"ws": WsTransport.dial(url), "lock": null, "hero": -1, "msgs": [], "token": t})
	print("net_client: dấu vân tay SIM %s, nối %s" % [NetVersion.fingerprint(), url])
	_t0 = Time.get_ticks_msec()


func _process(delta: float) -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	for b: Dictionary in _bots:
		_bot_tick(b, now, delta)
	var elapsed: float = (Time.get_ticks_msec() - _t0) / 1000.0
	match _phase:
		"connect":
			if _bots.all(func(b: Dictionary) -> bool: return (b["ws"] as WsTransport).is_open()):
				for b: Dictionary in _bots:
					b["ws"].send({"t": "hello", "v": NetVersion.fingerprint(), "token": b["token"]})
				_phase = "hello"
		"hello":
			if _bots.all(func(b: Dictionary) -> bool: return _seen(b, "hello_ok")):
				_bots[0]["ws"].send({"t": "create", "size": 1})
				_phase = "create"
		"create":
			var lobby: Dictionary = _last(_bots[0], "lobby")
			if not lobby.is_empty():
				_code = lobby["room"]["code"]
				print("net_client: phòng %s" % _code)
				_bots[1]["ws"].send({"t": "join", "code": _code})
				_bots[0]["ws"].send({"t": "pick", "hero": "gorran"})
				_bots[1]["ws"].send({"t": "pick", "hero": "myra"})
				_phase = "picked"
		"picked":
			if _last(_bots[0], "lobby").get("room", {}).get("members", []).size() == 2 and _ready(_last(_bots[0], "lobby")):
				_bots[0]["ws"].send({"t": "start"})
				_phase = "play"
				_t0 = Time.get_ticks_msec()
				elapsed = 0.0
		"play":
			if elapsed > float(_args.get("seconds", "30")):
				_report()
				return true
	for b: Dictionary in _bots:
		var err: Dictionary = _last(b, "error")
		if not err.is_empty():
			print("net_client: LỖI %s (%s)" % [err.get("code"), err.get("for")])
			return true
	return elapsed > 120.0


func _bot_tick(b: Dictionary, now: float, dt: float) -> void:
	var lock: LockstepClient = b["lock"]
	var incoming: Array[Dictionary] = lock.pump(now) if lock != null else (b["ws"] as WsTransport).receive()
	for m: Dictionary in incoming:
		if lock != null and lock.handle(m):
			continue
		b["msgs"].append(m)
		if String(m.get("t")) == "welcome":
			var cfg: MatchConfig = NetCodec.config_from(m["config"])
			var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
			w.map = load(MAP_PATH) as MapLayout
			w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
			MatchSetup.build(w, _lib, cfg)
			lock = LockstepClient.new(b["ws"])
			lock.attach(w, int(m["delay"]), int(m["peer"]))
			lock.clock = now
			b["lock"] = lock
			b["hero"] = int(m["entity"])
	if lock != null:
		lock.advance(dt)
		if randi() % 15 == 0:
			var e: Entity = lock.world.find_entity(int(b["hero"]))
			if e != null and e.alive:
				lock.world.submit(Command.move_to(e.id, e.position + Vector2(randf_range(-500, 500), randf_range(-500, 500))))


func _report() -> void:
	for k: int in _bots.size():
		var lock: LockstepClient = _bots[k]["lock"]
		if lock == null:
			print("net_client: máy %d chưa vào trận" % k)
			continue
		print("net_client: máy %d — tick %d, RTT %.0f ±%.0f ms, trễ bấm→hiệu lực %.0f ms, đệm %d, đứng hình %d, chờ đệm %d, %s" % [
			k, lock.world.tick, lock.rtt_ms, lock.jitter_ms, lock.input_latency_ms, lock.buffer_target, lock.stalls, lock.holds,
			"LỆCH ở tick %d" % lock.desync_tick if lock.desync_tick >= 0 else "khớp máy chủ (%d mốc đã gửi)" % lock.hashes.size()])


func _seen(b: Dictionary, t: String) -> bool:
	return not _last(b, t).is_empty()


func _last(b: Dictionary, t: String) -> Dictionary:
	for i: int in range(b["msgs"].size() - 1, -1, -1):
		if String(b["msgs"][i].get("t")) == t:
			return b["msgs"][i]
	return {}


func _ready(lobby: Dictionary) -> bool:
	return lobby.get("room", {}).get("members", []).all(func(m: Dictionary) -> bool: return String(m.get("hero", "")) != "")
