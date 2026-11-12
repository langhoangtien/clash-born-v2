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
			if m.get("resume", false) == true:  # NET-22
				c.lock.resume_to = int(m["tick"])
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
	var room: LockstepRoom = s._games[code].room
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


## NET-16 (D-402): qua WebSocket thật — B đóng kết nối giữa trận → máy chủ coi B rớt ngay, báo A tên B, trận A chạy tiếp.
func test_NET_16_closed_connection_in_match_notifies_others() -> void:
	var made: Array = _server()
	var s: RoomServer = made[0]
	var a: Client = _client(made[1])
	var b: Client = _client(made[1])
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return a.ws.is_open() and b.ws.is_open()))
	_hello(a, "An", s.fingerprint)
	_hello(b, "Bình", s.fingerprint)
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return not _last(a, "hello_ok").is_empty() and not _last(b, "hello_ok").is_empty()))
	a.ws.send({"t": "create", "size": 1})
	assert_true(_pump(s, [a, b], 3.0, func() -> bool: return not _last(a, "lobby").is_empty()))
	var code: String = _last(a, "lobby")["room"]["code"]
	b.ws.send({"t": "join", "code": code})
	a.ws.send({"t": "pick", "hero": "gorran"})
	b.ws.send({"t": "pick", "hero": "myra"})
	_pump(s, [a, b], 1.0)
	a.ws.send({"t": "start"})
	assert_true(_pump(s, [a, b], 10.0, func() -> bool: return a.lock != null and b.lock != null), "vào trận")
	_pump(s, [a, b], 1.0)
	b.ws.close()
	var room: LockstepRoom = s._games[code].room
	assert_true(_pump(s, [a], 3.0, func() -> bool: return not a.lock.notices.is_empty()), "A nhận thông báo")
	if not a.lock.notices.is_empty():
		assert_eq(OnlineMatch.notice_text(a.lock.notices[0]), "Bình mất kết nối — bot đánh thay")
	assert_eq(room.gone.size(), 1, "ô của B giữ lại")
	var before: int = a.lock.last_tick
	_pump(s, [a], 1.0)
	assert_true(a.lock.last_tick > before, "trận A chạy tiếp")
	a.ws.close()
	s.stop()
	s.queue_free()



## Hai máy khách vào trận 1v1 (A chủ phòng cầm Gorran, B cầm Myra). Trả mã phòng.
func _start_1v1(s: RoomServer, a: Client, b: Client) -> String:
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return a.ws.is_open() and b.ws.is_open()))
	_hello(a, "An", s.fingerprint)
	_hello(b, "Bình", s.fingerprint)
	assert_true(_pump(s, [a, b], 5.0, func() -> bool: return not _last(a, "hello_ok").is_empty() and not _last(b, "hello_ok").is_empty()))
	a.ws.send({"t": "create", "size": 1})
	assert_true(_pump(s, [a, b], 3.0, func() -> bool: return not _last(a, "lobby").is_empty()))
	var code: String = _last(a, "lobby")["room"]["code"]
	b.ws.send({"t": "join", "code": code})
	a.ws.send({"t": "pick", "hero": "gorran"})
	b.ws.send({"t": "pick", "hero": "myra"})
	_pump(s, [a, b], 1.0)
	a.ws.send({"t": "start"})
	assert_true(_pump(s, [a, b], 10.0, func() -> bool: return a.lock != null and b.lock != null), "vào trận")
	return code


## M9.8 (D-406) qua WebSocket thật: B rớt → bot; B nối lại: hello_ok báo trận đang đánh (NET-21), không tạo phòng khác
## (IN_MATCH), vào lại → tua nhật ký, kịp → trả quyền (NET-18), A thấy "đã vào lại", ba bản SIM cùng mã băm; vào lại lần
## nữa khi kết nối cũ còn → kết nối cũ bị thay (NET-23).
func test_NET_22_rejoin_over_websocket() -> void:
	var made: Array = _server()
	var s: RoomServer = made[0]
	var a: Client = _client(made[1])
	var b: Client = _client(made[1])
	var code: String = _start_1v1(s, a, b)
	var hero_b: int = b.hero
	_pump(s, [a, b], 2.0)
	b.ws.close()
	assert_true(_pump(s, [a], 3.0, func() -> bool: return a.lock.world.find_entity(hero_b).bot != null), "bot đánh thay B")
	_pump(s, [a], 3.0)
	var b2: Client = _client(made[1])
	assert_true(_pump(s, [a, b2], 5.0, func() -> bool: return b2.ws.is_open()))
	_hello(b2, "Bình", s.fingerprint)
	assert_true(_pump(s, [a, b2], 5.0, func() -> bool: return not _last(b2, "hello_ok").is_empty()))
	assert_eq(_last(b2, "hello_ok").get("live"), code, "NET-21: báo trận đang đánh")
	assert_eq(_last(a, "hello_ok").get("live"), "", "lúc A bắt tay chưa có trận")
	b2.ws.send({"t": "create", "size": 1})
	assert_true(_pump(s, [a, b2], 3.0, func() -> bool: return _last(b2, "error").get("code") == "IN_MATCH"), "R2: không tạo phòng khác")
	b2.ws.send({"t": "rejoin"})
	assert_true(_pump(s, [a, b2], 30.0, func() -> bool: return b2.lock != null and b2.lock.resume_to < 0), "tua kịp")
	assert_true(_pump(s, [a, b2], 5.0, func() -> bool: return a.lock.world.find_entity(hero_b).bot == null), "NET-18: trả quyền")
	assert_true(a.lock.notices.any(func(n: Dictionary) -> bool: return OnlineMatch.notice_text(n) == "Bình đã vào lại"))
	_pump(s, [a, b2], 2.0)
	var room: LockstepRoom = s._games[code].room
	var checked: int = 0
	for n: int in room._hashes:
		for c: LockstepClient in [a.lock, b2.lock]:
			if c.hashes.has(n):
				assert_eq(c.hashes[n], room._hashes[n], "tick %d" % n)
				checked += 1
	assert_true(checked > 4, "có mốc chung (%d)" % checked)
	assert_eq(room.desyncs, {})
	var b3: Client = _client(made[1])
	assert_true(_pump(s, [a, b2, b3], 5.0, func() -> bool: return b3.ws.is_open()))
	_hello(b3, "Bình", s.fingerprint)
	assert_true(_pump(s, [a, b2, b3], 5.0, func() -> bool: return not _last(b3, "hello_ok").is_empty()))
	b3.ws.send({"t": "rejoin"})
	assert_true(_pump(s, [a, b2, b3], 5.0, func() -> bool: return b2.ws.closed() and b3.lock != null), "NET-23: kết nối cũ bị thay")
	assert_eq(room.peers.size(), 2)
	for c: Client in [a, b2, b3]:
		c.ws.close()
	s.stop()
	s.queue_free()
