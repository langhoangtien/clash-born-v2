extends TestCase
## M9.7 (D-402): rớt mạng ở máy chủ phòng — im lặng 5 giây / đóng kết nối = rớt (NET-16), máy chủ chèn lệnh đổi quyền điều
## khiển vào gói lệnh tick kế, mọi máy áp giống nhau (NET-17), trận không còn người giữ EMPTY_KEEP_S rồi hủy (NET-19), máy
## lệch mã băm bị báo + coi là rớt, tự gửi báo cáo lệch (NET-20). Mạng giả LoopbackNet, đồng hồ ảo.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const FRAME: float = 1.0 / 60.0

var _lib: ContentLibrary


func _world(cfg: MatchConfig) -> World:
	if _lib == null:
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(w, _lib, cfg)
	return w


## 1v1 hai người: {net, room, clients, heroes, ends (đầu máy chủ), drops ([[mã, đơn vị, lý do, tick]])}.
func _setup() -> Dictionary:
	var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 31)
	var net: LoopbackNet = LoopbackNet.new(5)
	var room: LockstepRoom = LockstepRoom.new(_world(cfg))
	var h: Dictionary = {"net": net, "room": room, "clients": [], "heroes": [], "ends": [], "drops": [], "silent": []}
	room.on_drop = func(peer: int, entity: int, reason: String) -> void: h["drops"].append([peer, entity, reason, room.tick])
	for k: int in 2:
		var w: World = _world(cfg)
		var hero: int = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO)[k].id
		var ends: Array = net.link(60.0, 0.0, 0.0)
		room.add_peer(k, ends[1], hero)
		var c: LockstepClient = LockstepClient.new(ends[0])
		c.attach(w, room.input_delay, k)
		h["clients"].append(c)
		h["heroes"].append(hero)
		h["ends"].append(ends[1])
	return h


## `seconds` giây ảo; máy khách trong h["silent"] không đọc / gửi gì (mất mạng).
func _run(h: Dictionary, seconds: float) -> void:
	var net: LoopbackNet = h["net"]
	var room: LockstepRoom = h["room"]
	var acc: float = 0.0
	for f: int in int(seconds / FRAME):
		net.now += FRAME
		acc += FRAME
		room.pump()
		while acc >= SimClock.TICK_SECONDS:
			acc -= SimClock.TICK_SECONDS
			room.step_tick()
		for k: int in 2:
			if not (h["silent"] as Array).has(k):
				var c: LockstepClient = h["clients"][k]
				c.pump(net.now)
				c.advance(FRAME)


func test_NET_16_silent_peer_dropped_after_5_seconds() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	h["silent"] = [1]
	_run(h, 4.8)
	assert_eq(h["drops"], [], "chưa đủ 5 giây")
	_run(h, 0.5)
	assert_eq(h["drops"].size(), 1)
	if h["drops"].size() == 1:
		assert_eq(h["drops"][0].slice(0, 3), [1, h["heroes"][1], "silent"])
		assert_true(int(h["drops"][0][3]) > LockstepRoom.DROP_AFTER_S * SimClock.TICKS_PER_SECOND, "đếm bằng tick máy chủ")
	assert_eq(room.peers.keys(), [0], "máy vẫn ping (mỗi giây) không bị coi là rớt")
	assert_true(room.gone.has(1), "ô giữ lại để vào lại (M9.8)")
	var before: int = (h["clients"][0] as LockstepClient).last_tick
	_run(h, 1.0)
	assert_true((h["clients"][0] as LockstepClient).last_tick > before, "trận chạy tiếp cho người còn lại")


func test_NET_16_closed_peer_dropped_at_once() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	_run(h, 1.0)
	room.drop_peer(0, "closed")
	room.drop_peer(0, "closed")
	assert_eq(h["drops"].size(), 1, "rớt một lần")
	assert_eq(String(h["drops"][0][2]), "closed")
	assert_false(room.peers.has(0))


## NET-17: lệnh đổi quyền máy chủ chèn vào gói lệnh tick kế — máy còn lại và bản SIM của máy chủ áp cùng tick, cùng mã băm.
## (Lệnh thật là SET_CONTROL — CB-2; ở đây dùng lệnh đi để thấy rõ hero của người rớt được điều khiển trên mọi máy.)
func test_NET_17_takeover_command_applied_same_tick_on_all_machines() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	var target: Vector2 = Vector2.ZERO
	room.takeover = func(entity: int, bot: bool) -> Command:
		var e: Entity = room.world.find_entity(entity)
		target = e.position.move_toward(room.world.find_entity(h["heroes"][0]).position, 400.0)
		return Command.move_to(entity, target) if bot else null
	h["silent"] = [1]
	_run(h, 9.0)
	var hero: int = h["heroes"][1]
	var c0: LockstepClient = h["clients"][0]
	var spawn: Vector2 = (h["clients"][1] as LockstepClient).world.find_entity(hero).position
	assert_true(room.world.find_entity(hero).position.distance_to(spawn) > 100.0, "máy chủ: hero người rớt đã đi")
	var common: Array = c0.hashes.keys().filter(func(t: int) -> bool: return room._hashes.has(t))
	assert_true(common.size() >= 2, "có mốc mã băm chung")
	for t: int in common:
		assert_eq(c0.hashes[t], room._hashes[t], "tick %d" % t)
	assert_eq(room.desyncs, {}, "không lệch")


## NET-17 / NET-03: máy khách không được tự gửi lệnh cho đơn vị không phải của mình (gồm lệnh đổi quyền).
func test_NET_17_dropped_peer_commands_ignored() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	_run(h, 1.0)
	room.drop_peer(1, "closed")
	var dropped: int = room.dropped
	(h["clients"][1] as LockstepClient).transport.send({"t": "cmd", "want": room.tick + 3, "s": 1,
		"c": NetCodec.command_to(Command.move_to(h["heroes"][1], Vector2(100, 100)))})
	_run(h, 0.5)
	assert_eq(room.dropped, dropped, "tin của người đã rớt không còn được đọc")
	assert_false(room.peers.has(1))


## NET-20: máy lệch mã băm → nhận `desync`, máy chủ coi là rớt (lý do desync); máy kia vẫn chơi.
func test_NET_20_desync_is_reported_and_dropped() -> void:
	var h: Dictionary = _setup()
	var bad: LockstepClient = h["clients"][1]
	bad.world.find_entity(h["heroes"][1]).gold += 1  # máy này lệch từ đầu
	_run(h, 2.5)
	assert_eq(h["drops"].size(), 1)
	if h["drops"].size() == 1:
		assert_eq(h["drops"][0].slice(0, 3), [1, h["heroes"][1], "desync"])
	assert_eq(bad.desync_tick, LockstepClient.HASH_EVERY, "máy lệch biết tick lệch")
	assert_eq((h["clients"][0] as LockstepClient).desync_tick, -1)
	var r: Dictionary = DesyncReport.build(bad, "123456")
	assert_eq(r["data"]["meta"]["room"], "123456")
	assert_eq(int(r["data"]["meta"]["desync_tick"]), LockstepClient.HASH_EVERY)
	assert_true((r["data"]["hashes"] as Dictionary).has(str(LockstepClient.HASH_EVERY)), "chuỗi mã băm đã gửi")
	assert_eq((r["data"]["units"] as Dictionary).size(), bad.world.entities.size(), "mã băm từng đơn vị")
	assert_true(String(r["summary"]).contains("123456"))


## NET-16: tin `notice` của máy chủ (người rớt) đến máy khách → hàng thông báo trên HUD.
func test_NET_16_notice_shown_to_others() -> void:
	var h: Dictionary = _setup()
	var c0: LockstepClient = h["clients"][0]
	(h["ends"][0] as NetTransport).send({"t": "notice", "kind": "dropped", "name": "Bình"})
	_run(h, 0.5)
	assert_eq(c0.notices.size(), 1)
	assert_eq(OnlineMatch.notice_text(c0.notices[0]), "Bình mất kết nối — bot đánh thay")


## NET-19: trận không còn người → giữ EMPTY_KEEP_S rồi hủy; còn người thì không đếm.
func test_NET_19_empty_match_kept_then_cancelled() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	var s: RoomServer = RoomServer.new()
	s.empty_keep_s = 1.0
	s._games["111111"] = {"room": room, "acc": 0.0}
	s.tick(0.5)
	assert_true(s._games.has("111111"), "còn người")
	room.drop_peer(0, "closed")
	room.drop_peer(1, "closed")
	s.tick(0.6)
	assert_true(s._games.has("111111"), "chưa hết hạn giữ")
	s.tick(0.6)
	assert_false(s._games.has("111111"), "hết hạn → hủy")
	s.free()


## NET-17 (lệnh thật SET_CONTROL, CMD-07): người rớt → bot đánh thay trên máy còn lại và bản SIM máy chủ, cùng mã băm.
func test_NET_17_set_control_bot_takes_over_on_all_machines() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	room.takeover = Command.set_control
	h["silent"] = [1]
	_run(h, 20.0)
	var hero: int = h["heroes"][1]
	var c0: LockstepClient = h["clients"][0]
	assert_true(room.world.find_entity(hero).bot != null, "máy chủ: bot đánh thay")
	assert_true(c0.world.find_entity(hero).bot != null, "máy còn lại: bot đánh thay")
	var spawn: Vector2 = (h["clients"][1] as LockstepClient).world.find_entity(hero).position
	assert_true(room.world.find_entity(hero).position.distance_to(spawn) > 200.0, "bot cho hero đi")
	var common: Array = c0.hashes.keys().filter(func(t: int) -> bool: return room._hashes.has(t))
	assert_true(common.size() >= 10)
	for t: int in common:
		assert_eq(c0.hashes[t], room._hashes[t], "tick %d" % t)
	assert_eq(room.desyncs, {})


## NET-17 / NET-03: máy khách tự gửi SET_CONTROL (kể cả cho hero của mình) → máy chủ bỏ.
func test_NET_17_client_cannot_send_set_control() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	var c0: LockstepClient = h["clients"][0]
	_run(h, 0.5)
	c0.world.submit(Command.set_control(h["heroes"][0], true))
	_run(h, 1.0)
	assert_eq(room.dropped, 1, "bị bỏ")
	assert_true(room.world.find_entity(h["heroes"][0]).bot == null)
	assert_true(c0.world.find_entity(h["heroes"][0]).bot == null)


## NET-12 (ST.5, D-405): biên bản máy chủ phòng — SIM của máy chủ, khóa mã phòng-seed, ô → tài khoản (cả người đã rớt),
## ô đã rời, số bản của người tạo phòng.
func test_NET_12_room_report_payload() -> void:
	var h: Dictionary = _setup()
	var room: LockstepRoom = h["room"]
	_run(h, 1.0)
	room.drop_peer(1, "closed")
	room.world.winner = 0
	var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 31)
	var p: Dictionary = MatchReport.payload(room, cfg, "148203", {0: 11, 1: 12}, {0: 0, 1: 1}, "0.1.700")
	assert_eq(p["match_key"], "148203-31")
	assert_eq(p["accounts"], [[0, 11], [1, 12]], "mọi ô người, kể cả đã rớt")
	assert_eq(p["left"], [1])
	assert_eq(p["record"]["version"], "0.1.700")
	assert_eq(p["record"]["winner"], 0)
	assert_eq((p["record"]["players"] as Array).map(func(x: Dictionary) -> String: return x["hero"]), ["gorran", "myra"])
	assert_eq(MatchReport.payload(room, cfg, "148203", {}, {}, "bản lạ")["record"]["version"], "0.0.0", "số bản lạ → 0.0.0")


## NET-12: gửi lỗi mạng / 5xx → thử lại (tối đa 3 lần nữa); 4xx (biên bản sai / sai mã) → không thử lại.
func test_NET_12_room_report_retries_only_on_transient_errors() -> void:
	for c: Array in [[[502, 0, 200], 3, true], [[502, 502, 502, 502], 4, false], [[400], 1, false], [[200], 1, true]]:
		var codes: Array = (c[0] as Array).duplicate()
		var calls: Array[int] = [0]
		var r: MatchReport = MatchReport.new()
		r.fetch = func(_body: String, got: Callable) -> void:
			calls[0] += 1
			var code: int = int(codes.pop_front())
			got.call(HTTPRequest.RESULT_SUCCESS if code > 0 else HTTPRequest.RESULT_CANT_CONNECT, code)
		r.wait = func(_s: float, then: Callable) -> void: then.call()
		var out: Array = []
		r.send({"match_key": "148203-1"}, func(ok: bool) -> void: out.append(ok))
		assert_eq([calls[0], out], [c[1], [c[2]]], str(c[0]))
		r.free()


## NET-12 / NET-19: máy chủ phòng gửi biên bản khi trận có đội thắng; trận hủy (không còn người) thì không.
func test_NET_12_room_server_reports_win_not_cancel() -> void:
	var sent: Array = []
	for winner: int in [1, -1]:
		var h: Dictionary = _setup()
		var room: LockstepRoom = h["room"]
		var s: RoomServer = RoomServer.new()
		s.empty_keep_s = 0.2
		s.report = func(p: Dictionary) -> void: sent.append(p)
		var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 31)
		s._games["123456"] = {"room": room, "acc": 0.0, "cfg": cfg, "accounts": {0: 11, 1: 12}, "slots": {0: 0, 1: 1}, "app": "0.1.700"}
		room.drop_peer(0, "closed")  # không có kết nối thật trong test này
		room.drop_peer(1, "closed")
		if winner >= 0:
			room.world.winner = winner
		s.tick(0.1)
		s.tick(0.3)
		assert_false(s._games.has("123456"))
		s.free()
	assert_eq(sent.size(), 1, "chỉ trận có đội thắng")
	if not sent.is_empty():
		assert_eq(sent[0]["match_key"], "123456-31")
