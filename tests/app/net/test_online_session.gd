extends TestCase
## M9.6 (D-344): Chơi online phía máy khách — OnlineSession qua WebSocket thật tới máy chủ phòng (127.0.0.1, tài khoản giả):
## bắt tay, tạo / vào phòng bằng mã, chọn tướng, bắt đầu; vào trận SimRunner chạy theo gói lệnh (NET-01), lệnh người chơi
## đi qua máy chủ (NET-02), hai máy cùng mã băm. Bảng OnlinePanel, chữ trạng thái mạng, khóa trận cho thống kê (NET-12).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


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


## Chạy thời gian thật: máy chủ + phiên (sảnh: poll; trong trận: SimRunner online). Trả true khi `until` đúng.
func _pump(s: RoomServer, sessions: Array, runners: Dictionary, seconds: float, until: Callable = Callable()) -> bool:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var last: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() < end:
		OS.delay_msec(2)
		var dt: float = (Time.get_ticks_msec() - last) / 1000.0
		last = Time.get_ticks_msec()
		s.tick(dt)
		for o: OnlineSession in sessions:
			if runners.has(o):
				(runners[o] as SimRunner).advance(dt)
			elif o.stage != "game":
				o.poll()
		if until.is_valid() and until.call():
			return true
	return false


## Dựng World như màn trận online (cấu hình máy chủ gửi) + SimRunner chế độ lockstep.
func _enter(o: OnlineSession) -> SimRunner:
	var w: World = World.new(o.config.seed, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(w, ContentLibrary.load_dir(), o.config)
	var r: SimRunner = SimRunner.new(w)
	o.lockstep.attach(w, o.lockstep.input_delay, o.lockstep.peer_id)
	r.lockstep = o.lockstep
	return r


func test_NET_11_online_session_room_to_lockstep_match() -> void:
	var made: Array = _server()
	var s: RoomServer = made[0]
	var url: String = "ws://127.0.0.1:%d" % made[1]
	var a: OnlineSession = OnlineSession.new(WsTransport.dial(url), "name:An", s.fingerprint)
	var b: OnlineSession = OnlineSession.new(WsTransport.dial(url), "name:Binh", s.fingerprint)
	var none: Dictionary = {}
	assert_true(_pump(s, [a, b], none, 5.0, func() -> bool: return a.stage == "lobby" and b.stage == "lobby"), "bắt tay")
	assert_eq(a.name, "An")
	assert_true(a.heroes.has(&"gorran"))
	a.send({"t": "create", "size": 1})
	assert_true(_pump(s, [a, b], none, 3.0, func() -> bool: return not a.room.is_empty()))
	assert_true(a.host(), "người tạo là chủ phòng")
	b.send({"t": "join", "code": String(a.room["code"])})
	a.send({"t": "pick", "hero": "gorran"})
	b.send({"t": "pick", "hero": "myra"})
	assert_true(_pump(s, [a, b], none, 3.0, func() -> bool: return String(b.me().get("hero", "")) == "myra" and b.room["members"].size() == 2))
	assert_false(b.host())
	var key: String = String(a.room["code"])
	a.send({"t": "start"})
	assert_true(_pump(s, [a, b], none, 10.0, func() -> bool: return a.stage == "game" and b.stage == "game"), "cả hai nhận lời chào")
	assert_eq(a.match_key(), "%s-%d" % [key, a.config.seed], "NET-12: mã phòng + seed")
	assert_eq(a.match_key(), b.match_key(), "hai máy cùng khóa trận")
	var runners: Dictionary = {a: _enter(a), b: _enter(b)}
	var ra: SimRunner = runners[a]
	var hero: Entity = ra.world.find_entity(a.entity_id)
	assert_eq(hero.hero_def.id, &"gorran", "đơn vị của mình theo lời chào")
	var to: Vector2 = hero.position + Vector2(400, -400)
	_pump(s, [a, b], runners, 1.0)
	ra.world.submit(Command.move_to(a.entity_id, to))  # lệnh người chơi → máy chủ → gói lệnh của cả hai máy
	_pump(s, [a, b], runners, 3.0)
	var rb: SimRunner = runners[b]
	assert_true(ra.world.tick >= 60 and rb.world.tick >= 60, "chạy theo nhịp máy chủ (%d / %d)" % [ra.world.tick, rb.world.tick])
	assert_true(rb.world.find_entity(a.entity_id).position.distance_to(hero.position) < 1.0 or ra.world.tick != rb.world.tick,
		"máy B thấy hero của A đi cùng chỗ")
	assert_true(hero.position.distance_to(to) < 300.0, "lệnh qua mạng có hiệu lực")
	ra.world.submit(Command.level_up(a.entity_id, AbilityDef.Slot.Q))
	_pump(s, [a, b], runners, 1.0)
	ra.world.submit(QuickCast.command(ra.world, hero, AbilityDef.Slot.Q))  # D-345: chiêu không có điểm nhắm (INF)
	_pump(s, [a, b], runners, 1.5)
	for r: SimRunner in [ra, rb]:
		var q: AbilityInstance = Abilities.of(r.world.find_entity(a.entity_id), AbilityDef.Slot.Q)
		assert_eq(q.rank, 1, "nâng chiêu qua mạng")
		assert_true(q.ready_tick > r.world.tick, "tung chiêu qua mạng: đang hồi chiêu ở cả hai máy (D-345)")
	var room: LockstepRoom = s._games[key]["room"]
	assert_eq(room.desyncs.size(), 0, "không lệch")
	assert_true(OnlineMatch.status(a.lockstep, true, 0.0).begins_with("Online "), OnlineMatch.status(a.lockstep, true, 0.0))
	a.close()
	b.close()
	s.stop()
	s.free()


func test_NET_11_status_text_and_record_tag() -> void:
	var lock: LockstepClient = LockstepClient.new(NetTransport.new())
	lock.rtt_ms = 87.4
	assert_eq(OnlineMatch.status(lock, true, 0.1), "Online 87 ms")
	assert_eq(OnlineMatch.status(lock, true, 0.8), "Online 87 ms — đang chờ mạng…")
	assert_true(OnlineMatch.status(lock, false, 0.0).contains("mất kết nối"))
	var o: OnlineSession = OnlineSession.new(NetTransport.new(), "", "")
	o.room = {"code": "QP33Z"}
	o.config = MatchConfig.duel(&"gorran", &"myra", BotState.Difficulty.NORMAL, 777)
	o.slot = 1
	var rec: Dictionary = OnlineMatch.tag({"players": []}, o)
	assert_eq([rec["match_key"], rec["you"]], ["QP33Z-777", 1])
	assert_eq(OnlineSession.error_text("HERO_TAKEN"), "Tướng đã có người chọn")


func test_NET_11_panel_room_screen() -> void:
	var p: OnlinePanel = OnlinePanel.new()
	var sent: Array = []
	p.request.connect(func(m: Dictionary) -> void: sent.append(m))
	var room: Dictionary = {"code": "QP33Z", "size": 2, "host": 1, "members": [
		{"id": 1, "name": "Anh", "team": 0, "hero": "gorran"}, {"id": 2, "name": "Binh", "team": 1, "hero": ""}]}
	p.show_room(room, 2, [&"gorran", &"myra"] as Array[StringName])
	assert_eq(OnlinePanel.team_line(room, 0), "Anh (Gorran) ★, bot")
	assert_eq(OnlinePanel.team_line(room, 1), "Binh (chưa chọn), bot")
	var buttons: Dictionary = {}
	for b: Node in p.find_children("*", "Button", true, false):
		buttons[(b as Button).text] = b
	assert_true((buttons["Gorran"] as Button).disabled, "tướng người khác đã chọn")
	assert_false(buttons.has("BẮT ĐẦU"), "không phải chủ phòng")
	(buttons["Myra"] as Button).pressed.emit()
	(buttons["Sang Đội Xanh"] as Button).pressed.emit()
	assert_eq(sent, [{"t": "pick", "hero": "myra"}, {"t": "team", "team": 0}])
	p.show_room(room, 1, [&"gorran", &"myra"] as Array[StringName])
	assert_true(p.find_children("*", "Button", true, false).any(func(b: Node) -> bool: return (b as Button).text == "BẮT ĐẦU"), "chủ phòng")
	p.free()


## NET-10 (D-344): dấu vân tay gồm cả số cân bằng — đổi một số (vd vàng Hạ gục đầu tiên) thì khác dấu.
func test_NET_10_fingerprint_covers_balance_numbers() -> void:
	var b: BalanceSettings = (load(BALANCE_PATH) as BalanceSettings).duplicate()
	var before: String = NetVersion.balance_text(b)
	assert_true(before.contains("first_blood_gold=150"), before.left(200))
	b.first_blood_gold += 1
	assert_ne(NetVersion.balance_text(b), before)
