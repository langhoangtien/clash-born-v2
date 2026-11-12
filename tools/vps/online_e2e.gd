extends SceneTree
## Thử đầu-cuối trận online với máy chủ thật (D-408): đo độ trễ mọi máy (NET-14), A tạo phòng 1v1 ở máy `--host-server`
## (mã bắt đầu bằng id máy — NET-15), B đang chọn tay máy khác vào bằng mã (OnlineMenu nối thẳng máy của mã), đánh
## `--play` giây, B rớt → bot đánh thay (NET-16/17), B vào lại (NET-21/22: live, IN_MATCH, tua, trả quyền), so mã băm A/B,
## B rớt hẳn → chờ trận kết thúc (A đứng im, bot B đánh) → máy chủ ghi trận (NET-12, kiểm bằng curl ngoài script).
## `--stay`: nhà chính A còn dưới `--stay-hp` (mặc định 0,35) → B vào lại lần nữa, đánh thẳng nhà chính A tới hết trận;
## cả hai máy khách phải thấy đội thắng ở cùng tick với nhau (NET-24).
##   godot --headless --path . -s tools/vps/online_e2e.gd -- --a=<phiên A> --b=<phiên B> [--host-server=1] [--b-server=2]
##       [--play=20] [--max-wait=1800] [--stay] [--stay-hp=0.35] [--servers=<json như app/net/room_servers.json — thử với máy chủ nội bộ>]
## Phiên thử: POST /api/admin/test_session {name} (mã quản trị); xong thì POST /api/auth/logout từng phiên.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

var _args: Dictionary = {}
var _servers: Array[Dictionary] = []
var _fp: String = ""
var _phase: String = "probe_step"
var _t: float = 0.0
var _probe: ServerProbe
var _a: OnlineSession
var _b: OnlineSession
var _menu: OnlineMenu
var _code: String = ""
var _hero_b: int = -1
var _lib: ContentLibrary
var _mark: float = 0.0
var _started: bool = false
var _join_sent: bool = false
var _final: bool = false   ## --stay: lần vào lại cuối, B ở lại tới hết trận
var _core_a: int = -1


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_servers = RoomServers.load_list(String(_args.get("servers", RoomServers.FILE)))
	_fp = NetVersion.fingerprint()
	_lib = ContentLibrary.load_dir()
	print("e2e: dấu vân tay %s" % _fp)
	_probe = ServerProbe.new(_servers, _fp, func(url: String) -> NetTransport: return WsTransport.dial(url))


func _process(delta: float) -> bool:
	_t += delta
	var now: float = Time.get_ticks_msec() / 1000.0
	if _menu != null:
		_menu.step()
	for s: OnlineSession in [_a, _b]:
		if s != null and s.lockstep != null and s.lockstep.world != null:
			s.lockstep.pump(now)
			s.lockstep.advance(delta)
	var limit: float = float(_args.get("max-wait", "1800")) if _phase in ["wait_end", "finish"] else 60.0
	if _t > limit:
		return _fail("hết giờ ở bước %s" % _phase)
	return call("_" + _phase, now)


func _go(phase: String) -> void:
	print("e2e: [%7.1f s] → %s" % [Time.get_ticks_msec() / 1000.0, phase])
	_phase = phase
	_t = 0.0


func _fail(why: String) -> bool:
	print("e2e: LỖI — " + why)
	return true


func _url(id: int) -> String:
	return String(RoomServers.by_id(_servers, id).get("url", ""))


func _probe_step(now: float) -> bool:
	if not _probe.poll(now):
		return false
	for r: Dictionary in _probe.results:
		print("e2e: đo %s" % RoomServers.label(r))
	_probe.close_all()
	_a = OnlineSession.new(WsTransport.dial(_url(int(_args.get("host-server", "1")))), _args["a"], _fp, "0.0.0")
	_go("a_lobby")
	return false


func _a_lobby(_now: float) -> bool:
	for m: Dictionary in _a.poll():
		if m.get("t") == "hello_ok":
			_a.send({"t": "create", "size": 1})
		elif m.get("t") == "error":
			return _fail("A: " + str(m))
	if String(_a.room.get("code", "")) == "":
		return false
	_code = String(_a.room["code"])
	print("e2e: A tạo phòng %s ở máy %s (chữ số đầu đúng: %s)" % [_code, _args.get("host-server", "1"),
		_code.begins_with(String(_args.get("host-server", "1")))])
	_menu = OnlineMenu.new()
	_menu.prefs_path = "user://e2e_online.cfg"
	_menu.attach(OnlinePanel.new())
	_menu.servers = _servers
	_menu.choice = int(_args.get("b-server", "2"))
	_menu.save_match("")
	AccountClient.token = _args["b"]
	_menu.match_ready.connect(func(s: OnlineSession) -> void: _b = s)
	_menu.connect_servers()
	_go("b_join")
	return false


func _b_join(_now: float) -> bool:
	_a.poll()
	if _menu.session == null or _menu.session.stage != "lobby":
		return false
	if _menu.session.room.is_empty():
		if _join_sent:
			return false
		_join_sent = true
		print("e2e: B ở máy %d (chọn tay), vào bằng mã %s" % [_menu.server_id, _code])
		_menu._on_request({"t": "join", "code": _code})
		return false
	if String(_menu.session.room.get("code", "")) != _code:
		return false
	print("e2e: B đã vào phòng, máy %d" % _menu.server_id)
	_a.send({"t": "pick", "hero": "gorran"})
	_menu.session.send({"t": "pick", "hero": "myra"})
	_go("start")
	return false


func _start(_now: float) -> bool:
	if _t > 1.5 and not _started:
		_started = true
		_a.send({"t": "start"})
	if _a.lockstep == null:
		_a.poll()
	elif _a.lockstep.world == null:
		_enter(_a)
	if _b != null and _b.lockstep.world == null:
		_enter(_b)
		_hero_b = _b.entity_id
	if _a.lockstep != null and _a.lockstep.world != null and _b != null and _b.lockstep.world != null:
		_go("play")
	return false


func _enter(s: OnlineSession) -> void:
	var w: World = World.new(s.config.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(w, _lib, s.config)
	s.lockstep.attach(w, s.lockstep.input_delay, s.lockstep.peer_id)
	s.lockstep.clock = Time.get_ticks_msec() / 1000.0


func _act(s: OnlineSession) -> void:
	var e: Entity = s.lockstep.world.find_entity(s.entity_id)
	if e != null and e.alive and randi() % 15 == 0:
		s.lockstep.world.submit(Command.move_to(s.entity_id, e.position.move_toward(Vector2(10000, 10000), 300.0)))


func _play(_now: float) -> bool:
	_act(_a)
	_act(_b)
	if _t < float(_args.get("play", "20")):
		return false
	var la: LockstepClient = _a.lockstep
	print("e2e: chơi %.0f s — A: RTT %.0f ms, bấm→hiệu lực %.0f ms, đứng hình %d; B: RTT %.0f ms, đứng hình %d" % [_t,
		la.rtt_ms, la.input_latency_ms, la.stalls, _b.lockstep.rtt_ms, _b.lockstep.stalls])
	_b.close()
	_b = null
	_go("dropped")
	return false


func _dropped(_now: float) -> bool:
	var e: Entity = _a.lockstep.world.find_entity(_hero_b)
	if e.bot == null:
		return false
	print("e2e: bot đánh thay B sau %.1f s; thông báo: %s" % [_t, _a.lockstep.notices.map(OnlineMatch.notice_text)])
	_b = OnlineSession.new(WsTransport.dial(_url(int(_args.get("host-server", "1")))), _args["b"], _fp, "0.0.0")
	_go("rejoin")
	return false


func _rejoin(_now: float) -> bool:
	if _b.lockstep != null:
		if _b.lockstep.world == null:
			_enter(_b)
			print("e2e: B vào lại, tua tới tick %d" % _b.lockstep.resume_to)
			_go("catch")
		return false
	for m: Dictionary in _b.poll():
		if m.get("t") == "hello_ok":
			print("e2e: B bắt tay lại — live = '%s' (mong %s)" % [_b.live, _code])
			_b.send({"t": "create", "size": 1})
		elif m.get("t") == "error":
			print("e2e: B tạo phòng khác → %s (mong IN_MATCH)" % m.get("code"))
			_b.send({"t": "rejoin"})
	return false


func _catch(_now: float) -> bool:
	if _b.lockstep.resume_to >= 0 or _a.lockstep.world.find_entity(_hero_b).bot != null:
		return false
	if _mark == 0.0:
		_mark = _t
		print("e2e: tua kịp + trả quyền sau %.1f s; thông báo A: %s" % [_t, _a.lockstep.notices.map(OnlineMatch.notice_text)])
	if _t - _mark < 10.0:
		return false
	var same: int = 0
	var diff: int = 0
	for n: int in _a.lockstep.hashes:
		if _b.lockstep.hashes.has(n):
			if _a.lockstep.hashes[n] == _b.lockstep.hashes[n]:
				same += 1
			else:
				diff += 1
	print("e2e: mã băm A/B: %d mốc khớp, %d lệch; máy chủ báo lệch A %d, B %d" % [same, diff, _a.lockstep.desync_tick,
		_b.lockstep.desync_tick])
	if _final:
		_go("finish")
		_mark = -2.0
		return false
	_b.close()
	_b = null
	_go("wait_end")
	return false


func _wait_end(_now: float) -> bool:
	var w: World = _a.lockstep.world
	if int(_t) % 60 == 0 and _t - floorf(_t) < 0.02:
		print("e2e: chờ hết trận — tick %d" % w.tick)
	if _args.has("stay") and _core_hp(w) < float(_args.get("stay-hp", "0.35")):
		print("e2e: nhà chính A còn %.0f%% (tick %d) — B vào lại, ở tới hết trận" % [_core_hp(w) * 100.0, w.tick])
		_final = true
		_mark = 0.0
		_b = OnlineSession.new(WsTransport.dial(_url(int(_args.get("host-server", "1")))), _args["b"], _fp, "0.0.0")
		_go("rejoin")
		return false
	if w.winner < 0:
		return false
	print("e2e: trận kết thúc — đội %d thắng, %.0f s trận, mã trận %s-%d" % [w.winner, w.tick / 30.0, _code, _a.config.seed])
	_a.close()
	return true


## Phần máu còn lại của nhà chính đội A (0..1; đã đổ = 0).
func _core_hp(w: World) -> float:
	var hero: Entity = w.find_entity(_a.entity_id)
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.CORE and e.team == hero.team:
			_core_a = e.id
			return e.health / maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP))
	return 0.0


## --stay: B đánh thẳng nhà chính A; chờ cả hai máy khách thấy đội thắng.
func _finish(_now: float) -> bool:
	var wa: World = _a.lockstep.world
	var wb: World = _b.lockstep.world
	if _t - _mark >= 2.0 and wb.find_entity(_b.entity_id) != null:
		_mark = _t
		wb.submit(Command.attack(_b.entity_id, _core_a, true))
	if int(_t) % 30 == 0 and _t - floorf(_t) < 0.02:
		print("e2e: chờ hết trận — tick A %d, B %d, nhà chính A %.0f%%" % [wa.tick, wb.tick, _core_hp(wa) * 100.0])
	if wa.winner < 0 or wb.winner < 0:
		return false
	print("e2e: trận kết thúc — A thấy đội %d thắng ở tick %d, B thấy đội %d ở tick %d (%s); %.0f s trận; mã trận %s-%d" % [
		wa.winner, wa.tick, wb.winner, wb.tick, "KHỚP" if wa.winner == wb.winner and wa.tick == wb.tick else "LỆCH",
		wa.tick / 30.0, _code, _a.config.seed])
	_a.close()
	_b.close()
	return true
