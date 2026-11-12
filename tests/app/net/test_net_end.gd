extends TestCase
## NET-24 (D-409): trận kết thúc online — máy chủ chạy tới tick có đội thắng, gửi `end` rồi ngừng gửi gói tick; máy khách
## phải chạy hết mọi gói đã nhận bất kể đệm chống dao động, tới đúng tick thắng, cùng đội thắng với máy chủ (màn trận thấy
## `world.winner` → hiện kết quả). Lỗi gặp ở e2e thật (bản 0.1.689): đệm ≥ 2 gói → khách dừng trước tick thắng mãi mãi.
## Mạng giả LoopbackNet có dao động, đồng hồ ảo; nhà chính đội 1 đổ ở tick WIN_TICK trên mọi bản SIM (như một đòn kết liễu).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const FRAME: float = 1.0 / 60.0
const WIN_TICK: int = 300

var _lib: ContentLibrary


func _world(cfg: MatchConfig) -> World:
	if _lib == null:
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(w, _lib, cfg)
	return w


## Nhà chính đội 1 đổ ở tick `at` (gọi ngay trước khi chạy tick đó) — giống nhau trên mọi bản SIM.
static func _core_falls(w: World, at: int) -> void:
	if w.tick + 1 != at:
		return
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.CORE and e.team == 1:
			e.health = 0.0
			e.alive = false
			e.killer_id = -1


func _client(h: Dictionary, end: NetTransport, w: World, peer: int) -> LockstepClient:
	var c: LockstepClient = LockstepClient.new(end)
	c.attach(w, (h["room"] as LockstepRoom).input_delay, peer)
	c.on_before = func() -> void: _core_falls(c.world, WIN_TICK)
	return c


## 1v1 hai người, đường nối có dao động `jitter` ms: {net, room, clients, heroes, cfg, ended}.
func _setup(jitter: float) -> Dictionary:
	var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 31)
	var net: LoopbackNet = LoopbackNet.new(9)
	var room: LockstepRoom = LockstepRoom.new(_world(cfg))
	var h: Dictionary = {"net": net, "room": room, "clients": [], "heroes": [], "cfg": cfg, "ended": false, "silent": []}
	for k: int in 2:
		var w: World = _world(cfg)
		var hero: int = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO)[k].id
		var ends: Array = net.link(120.0, jitter, 0.0)
		room.add_peer(k, ends[1], hero)
		h["clients"].append(_client(h, ends[0], w, k))
		h["heroes"].append(hero)
	return h


## `seconds` giây ảo. Máy chủ như RoomServer._run_game: có đội thắng → gửi `end` cho mọi người còn kết nối, ngừng chạy tick.
func _run(h: Dictionary, seconds: float) -> void:
	var net: LoopbackNet = h["net"]
	var room: LockstepRoom = h["room"]
	var acc: float = 0.0
	for f: int in int(seconds / FRAME):
		net.now += FRAME
		acc += FRAME
		if not h["ended"]:
			room.pump()
			while acc >= SimClock.TICK_SECONDS and room.world.winner < 0:
				acc -= SimClock.TICK_SECONDS
				_core_falls(room.world, WIN_TICK)
				room.step_tick()
			if room.world.winner >= 0:
				h["ended"] = true
				for id: int in room.peers:
					room.peers[id].send({"t": "end", "winner": room.world.winner})
		for k: int in (h["clients"] as Array).size():
			if not (h["silent"] as Array).has(k):
				var c: LockstepClient = h["clients"][k]
				c.pump(net.now)
				c.advance(FRAME)


func _assert_finished(h: Dictionary, clients: Array) -> void:
	var room: LockstepRoom = h["room"]
	assert_eq(room.world.winner, 0, "máy chủ: đội 0 thắng")
	assert_eq(room.tick, WIN_TICK)
	for c: LockstepClient in clients:
		assert_eq(c.world.tick, WIN_TICK, "máy khách chạy tới đúng tick thắng")
		assert_eq(c.world.winner, room.world.winner, "cùng đội thắng với máy chủ")
		assert_eq(c.backlog(), 0, "không còn gói nào chưa chạy")
		assert_eq(c.hashes.get(WIN_TICK, ""), room._hashes.get(WIN_TICK, "?"), "mã băm tick thắng khớp máy chủ")
		assert_eq(OnlineMatch.status(c, true, 0.0), "", "màn trận: đã có kết quả, không còn chữ trạng thái mạng")


func test_NET_24_clients_reach_winning_tick_under_jitter() -> void:
	var h: Dictionary = _setup(60.0)
	_run(h, 14.0)
	for c: LockstepClient in h["clients"]:
		assert_true(c.buffer_target >= 2, "đệm chống dao động đang giữ ≥ 2 gói (%d) — điều kiện gây lỗi" % c.buffer_target)
	_assert_finished(h, h["clients"])


## NET-24: tin `end` tới trước gói tick cuối (máy chủ khác thứ tự / tin đến cùng đợt) — vẫn chạy hết khi gói tới.
func test_NET_24_end_before_last_tick_bundle() -> void:
	var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 31)
	var c: LockstepClient = LockstepClient.new(NetTransport.new())
	c.attach(_world(cfg), 3, 0)
	c.on_before = func() -> void: _core_falls(c.world, 20)
	c.jitter_ms = 150.0  # đệm 6 gói
	for n: int in range(1, 20):
		c.handle({"t": "tick", "n": n, "c": []})
	for i: int in 60:
		c.advance(FRAME)
	assert_true(c.world.tick < 19, "trước `end`: giữ đệm như thường (tick %d)" % c.world.tick)
	assert_true(c.handle({"t": "end", "winner": 0}), "`end` là tin của lockstep")
	c.advance(FRAME)
	c.advance(FRAME)
	assert_eq(c.world.tick, 19, "sau `end`: chạy hết gói đã có")
	c.handle({"t": "tick", "n": 20, "c": []})
	c.advance(FRAME)
	assert_eq(c.world.tick, 20, "gói cuối tới sau `end` → chạy ngay")
	assert_eq(c.world.winner, 0)


## NET-24 + NET-22: người vào lại đang tua lúc trận kết thúc — tua xong vẫn tới đúng tick thắng, cùng mã băm.
func test_NET_24_rejoining_client_reaches_end() -> void:
	var h: Dictionary = _setup(60.0)
	var room: LockstepRoom = h["room"]
	room.takeover = Command.set_control
	h["silent"] = [1]
	_run(h, 7.0)
	assert_true(room.gone.has(1), "người 1 đã rớt (im lặng)")
	var ends: Array = (h["net"] as LoopbackNet).link(120.0, 60.0, 0.0)
	var c2: LockstepClient = _client(h, ends[0], _world(h["cfg"]), 7)
	c2.catch_up_ms = 0.0  # không tua: trận kết thúc khi máy này còn đang tua
	c2.resume_to = room.tick
	room.rejoin_peer(7, ends[1], h["heroes"][1])
	h["clients"][1] = c2
	h["silent"] = []
	_run(h, 8.0)
	assert_true(c2.resume_to >= 0, "trận đã kết thúc khi máy này còn đang tua")
	c2.catch_up_ms = 24.0
	_run(h, 4.0)
	_assert_finished(h, [h["clients"][0], c2])


## NET-19: trận hủy vì không còn người — không ai còn kết nối nên không có `end`; máy chủ không ghi trận (NET-12, test ở
## test_net_drop). Máy khách cũ (đã rớt) không nhận gì thêm: không có gói nào, không chạy tiếp.
func test_NET_24_cancelled_match_sends_no_end() -> void:
	var h: Dictionary = _setup(0.0)
	_run(h, 2.0)
	var room: LockstepRoom = h["room"]
	room.drop_peer(0, "closed")
	room.drop_peer(1, "closed")
	assert_true(room.peers.is_empty(), "không còn ai để gửi `end`")
	var c: LockstepClient = h["clients"][0]
	var before: int = c.world.tick
	_run(h, 2.0)
	assert_true(c.world.tick - before <= c.buffer_target + 3, "máy khách đã rớt chỉ chạy nốt gói đã nhận")
	assert_eq(c.world.winner, -1)


## Hàng gửi luôn đầy (WebSocket chậm) — ghi lại tin đã gửi.
class FullPipe:
	extends NetTransport
	var sent: Array[Dictionary] = []

	func send(msg: Dictionary) -> void:
		sent.append(msg)

	func buffered() -> int:
		return 1 << 30


## NET-24 + NET-22: trận kết thúc khi nhật ký cho người vào lại chưa gửi hết (hàng gửi đầy) → máy chủ gửi nốt toàn bộ
## (`flush_backfill`) trước `end`, nếu không máy đó thiếu gói, không bao giờ tới tick thắng.
func test_NET_24_history_flushed_before_end() -> void:
	var h: Dictionary = _setup(0.0)
	var room: LockstepRoom = h["room"]
	room.history_chunk = 3
	for i: int in 20:
		var c0: LockstepClient = h["clients"][0]
		var hero: int = h["heroes"][0]
		c0.world.submit(Command.move_to(hero, c0.world.find_entity(hero).position + Vector2(40, 0)))
		_run(h, 0.25)
	assert_true(room.log.size() > 6, "nhật ký nhiều phần (%d gói)" % room.log.size())
	var pipe: FullPipe = FullPipe.new()
	room.rejoin_peer(7, pipe, h["heroes"][1])
	var target: int = room.tick
	room.step_tick()
	assert_eq(pipe.sent.filter(func(m: Dictionary) -> bool: return m["t"] == "history").size(), 0, "hàng đầy: chưa gửi")
	room.flush_backfill()
	var parts: Array = pipe.sent.filter(func(m: Dictionary) -> bool: return m["t"] == "history")
	assert_true(parts.size() >= 2, "gửi nốt mọi phần (%d)" % parts.size())
	assert_eq(int(parts[0]["from"]), 1)
	assert_eq(int(parts[-1]["to"]), target, "tới tick lúc vào lại")
	room.flush_backfill()
	assert_eq(pipe.sent.filter(func(m: Dictionary) -> bool: return m["t"] == "history").size(), parts.size(), "không gửi lại")
