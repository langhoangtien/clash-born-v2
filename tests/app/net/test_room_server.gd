extends TestCase
## M9.5 (D-338): máy chủ phòng qua WebSocket thật (127.0.0.1) — bắt tay (NET-10 dấu vân tay, NET-06 tài khoản), sảnh
## (NET-07..09: tạo / vào bằng mã, chọn tướng, chủ bắt đầu), vào trận lockstep: 2 máy khách + máy chủ cùng mã băm.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


class Client:
	var ws: WsTransport
	var msgs: Array[Dictionary] = []
	var lock: LockstepClient
	var hero: int = -1


func _server() -> Array:
	var s: RoomServer = RoomServer.new()
	s.auth = Callable(ApiAuth, "dev")
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	var port: int = 0
	for attempt: int in 20:
		port = 18000 + randi() % 4000
		if s.start(port) == OK:
			break
	return [s, port]


func _client(port: int) -> Client:
	var c: Client = Client.new()
	c.ws = WsTransport.dial("ws://127.0.0.1:%d" % port)
	return c


## Chạy thời gian thật tới khi `until` đúng hoặc hết `seconds`; máy khách có LockstepClient thì chạy trận (lệnh ngẫu nhiên).
func _pump(s: RoomServer, clients: Array, seconds: float, until: Callable = Callable()) -> bool:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var last: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() < end:
		OS.delay_msec(2)
		var now: int = Time.get_ticks_msec()
		var dt: float = (now - last) / 1000.0
		last = now
		s.tick(dt)
		for c: Client in clients:
			_client_tick(c, now / 1000.0, dt)
		if until.is_valid() and until.call():
			return true
	return false


func _client_tick(c: Client, now: float, dt: float) -> void:
	var incoming: Array[Dictionary] = c.lock.pump(now) if c.lock != null else c.ws.receive()
	for m: Dictionary in incoming:
		if c.lock != null and c.lock.handle(m):
			continue
		c.msgs.append(m)
		if String(m.get("t")) == "welcome":
			var cfg: MatchConfig = NetCodec.config_from(m["config"])
			var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
			w.map = load(MAP_PATH) as MapLayout
			w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
			MatchSetup.build(w, ContentLibrary.load_dir(), cfg)
			c.lock = LockstepClient.new(c.ws)
			c.lock.attach(w, int(m["delay"]), int(m["peer"]))
			c.lock.clock = now
			c.hero = int(m["entity"])
	if c.lock != null:
		c.lock.advance(dt)
		if randi() % 20 == 0:
			var e: Entity = c.lock.world.find_entity(c.hero)
			if e != null and e.alive:
				c.lock.world.submit(Command.move_to(c.hero, e.position + Vector2(randf_range(-500, 500), randf_range(-500, 500))))


func _last(c: Client, t: String) -> Dictionary:
	for i: int in range(c.msgs.size() - 1, -1, -1):
		if String(c.msgs[i].get("t")) == t:
			return c.msgs[i]
	return {}


func _hello(c: Client, name: String, fp: String) -> void:
	c.ws.send({"t": "hello", "v": fp, "token": "name:" + name})


func test_M9_5_two_clients_lobby_then_lockstep_over_websocket() -> void:
	var made: Array = _server()
	var s: RoomServer = made[0]
	var a: Client = _client(made[1])
	var b: Client = _client(made[1])
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return a.ws.is_open() and b.ws.is_open()), "kết nối WebSocket")
	_hello(a, "An", s.fingerprint)
	_hello(b, "Bình", s.fingerprint)
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return not _last(a, "hello_ok").is_empty() and not _last(b, "hello_ok").is_empty()))
	a.ws.send({"t": "create", "size": 1})
	assert_true(_pump(s, [a, b], 3.0, func() -> bool: return not _last(a, "lobby").is_empty()))
	var code: String = _last(a, "lobby")["room"]["code"]
	b.ws.send({"t": "join", "code": code.to_lower()})
	a.ws.send({"t": "pick", "hero": "gorran"})
	b.ws.send({"t": "pick", "hero": "gorran"})
	assert_true(_pump(s, [a, b], 3.0, func() -> bool: return _last(b, "error").get("code") == "HERO_TAKEN"), "MATCH-02 trong phòng")
	b.ws.send({"t": "pick", "hero": "myra"})
	b.ws.send({"t": "start"})
	assert_true(_pump(s, [a, b], 3.0, func() -> bool: return _last(b, "error").get("code") == "NOT_HOST"), "chỉ chủ phòng bắt đầu")
	a.ws.send({"t": "start"})
	assert_true(_pump(s, [a, b], 10.0, func() -> bool: return a.lock != null and b.lock != null), "cả hai vào trận")
	assert_eq(_last(a, "welcome")["config"]["slots"].map(func(x: Array) -> String: return x[2]), ["gorran", "myra"])
	_pump(s, [a, b], 3.0)
	var room: LockstepRoom = s._games[code]["room"]
	assert_true(room.tick >= 80, "máy chủ giữ nhịp (%d tick)" % room.tick)
	var compared: int = 0
	for c: Client in [a, b]:
		for n: int in c.lock.hashes:
			if room._hashes.has(n):
				assert_eq(c.lock.hashes[n], room._hashes[n], "mốc %d" % n)
				compared += 1
	assert_true(compared >= 4, "đã so mã băm qua mạng thật (%d)" % compared)
	assert_eq(room.desyncs.size(), 0)
	s.stop()
	s.free()


func test_NET_10_wrong_version_and_bad_login_rejected() -> void:
	var made: Array = _server()
	var s: RoomServer = made[0]
	var a: Client = _client(made[1])
	var b: Client = _client(made[1])
	_pump(s, [a, b], 5.0, func() -> bool: return a.ws.is_open() and b.ws.is_open())
	_hello(a, "An", "1-khac-phien-ban")
	b.ws.send({"t": "hello", "v": s.fingerprint, "token": "sai"})
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return not _last(a, "error").is_empty() and not _last(b, "error").is_empty()))
	assert_eq(_last(a, "error")["code"], "VERSION")
	assert_eq(_last(b, "error")["code"], "AUTH")
	assert_true(_pump(s, [a, b], 3.0, func() -> bool: return a.ws.closed() and b.ws.closed()), "máy chủ đóng kết nối")
	s.stop()
	s.free()
