extends TestCase
## NET-13..15 (D-401): nhiều máy chủ phòng — danh sách là dữ liệu, đo độ trễ trước bắt tay, Tự động / chọn tay (nhớ lựa
## chọn), mã phòng 6 chữ số mang id máy chủ, nhập mã của máy khác → nối thẳng máy đó. NET-06: API tài khoản bận → BUSY.


func _server(server_id: int, fingerprint: String = "", auth: Callable = Callable(ApiAuth, "dev")) -> Array:
	var s: RoomServer = RoomServer.new()
	s.auth = auth
	s.server_id = server_id
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	var port: int = 0
	for attempt: int in 20:
		port = 18000 + randi() % 4000
		if s.start(port) == OK:
			break
	if fingerprint != "":
		s.fingerprint = fingerprint
	return [s, port]


func _url(port: int) -> String:
	return "ws://127.0.0.1:%d" % port


## Thời gian thật: máy chủ + menu (+ máy khách thô) tới khi `until` đúng.
func _pump(rooms: Array, menu: OnlineMenu, seconds: float, until: Callable, raw: Array = []) -> bool:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	var last: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() < end:
		OS.delay_msec(2)
		var dt: float = (Time.get_ticks_msec() - last) / 1000.0
		last = Time.get_ticks_msec()
		for s: RoomServer in rooms:
			s.tick(dt)
		if menu != null:
			menu.step()
		for c: Array in raw:
			(c[1] as Array).append_array((c[0] as WsTransport).receive())
		if until.call():
			return true
	return false


func _menu(servers: Array[Dictionary], choice: int) -> OnlineMenu:
	var m: OnlineMenu = OnlineMenu.new()
	m.prefs_path = "user://test_online_%d.cfg" % randi()
	m.attach(OnlinePanel.new())
	m.servers = servers
	m.choice = choice
	return m


func _free(menu: OnlineMenu, rooms: Array) -> void:
	menu.close()
	menu.panel.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu.prefs_path))
	menu.free()
	for s: RoomServer in rooms:
		s.stop()
		s.queue_free()


func _signed_in(name: String) -> Array:
	var keep: Array = [AccountClient.token, AccountClient.account]
	AccountClient.token = "name:" + name
	AccountClient.account = {"id": 1, "name": name}
	return keep


func _restore(keep: Array) -> void:
	AccountClient.token = keep[0]
	AccountClient.account = keep[1]


func test_NET_13_server_list_is_data() -> void:
	var list: Array[Dictionary] = RoomServers.load_list()
	assert_eq(RoomServers.validate(list), "")
	assert_eq(RoomServers.by_id(list, 1).get("url"), "wss://sg.clashborn.quest/play", "1 = Singapore")
	assert_eq(RoomServers.by_id(list, 2).get("url"), "wss://clashborn.quest/play", "2 = máy chính")
	var dup: Array[Dictionary] = [{"id": 1, "name": "A", "url": "wss://a/play"}, {"id": 1, "name": "B", "url": "wss://b/play"}]
	assert_ne(RoomServers.validate(dup), "", "trùng id")
	var big: Array[Dictionary] = [{"id": 10, "name": "A", "url": "wss://a/play"}]
	assert_ne(RoomServers.validate(big), "", "id phải một chữ số (mã phòng NET-15)")


func test_NET_14_order_auto_by_latency_manual_only_choice() -> void:
	var r: Array[Dictionary] = [{"id": 1, "name": "SG", "state": "ok", "rtt_ms": 220.0},
		{"id": 2, "name": "Chính", "state": "ok", "rtt_ms": 40.0}, {"id": 3, "name": "US", "state": "version", "rtt_ms": 0.0},
		{"id": 4, "name": "EU", "state": "ok", "rtt_ms": 40.0}]
	assert_eq(RoomServers.order(r, 0), [2, 4, 1] as Array[int], "Tự động: thấp nhất trước, bằng nhau → id nhỏ")
	assert_eq(RoomServers.order(r, 1), [1] as Array[int], "chọn tay: chỉ máy đó dù chậm hơn")
	assert_eq(RoomServers.order(r, 3), [] as Array[int], "chọn tay máy khác bản → không tự nhảy máy khác")
	assert_true(RoomServers.failure_text(r, 3).contains("US"), "báo tên máy chọn tay")
	var bad: Array[Dictionary] = [{"id": 1, "name": "SG", "state": "fail", "rtt_ms": 0.0},
		{"id": 2, "name": "Chính", "state": "version", "rtt_ms": 0.0}]
	assert_eq(RoomServers.order(bad, 0), [] as Array[int])
	assert_eq(RoomServers.failure_text(bad, 0), OnlineSession.error_text("VERSION"), "có máy khác bản → báo cập nhật")
	bad[1]["state"] = "fail"
	assert_true(RoomServers.failure_text(bad, 0).contains("Không nối được"))


## NET-14: đo qua mạng giả — trung vị các lượt, máy khác dấu vân tay, máy đóng, máy im lặng tới hạn.
func test_NET_14_probe_measures_median_and_marks_failures() -> void:
	var net: LoopbackNet = LoopbackNet.new(3)
	var far: Array = net.link(200.0, 0.0, 0.0)
	var odd: Array = net.link(40.0, 0.0, 0.0)
	var mute: Array = net.link(40.0, 0.0, 0.0)
	var gone: Array = net.link(40.0, 0.0, 0.0)
	(gone[0] as NetTransport).close()
	var ends: Dictionary = {"wss://far/play": far[0], "wss://odd/play": odd[0], "wss://mute/play": mute[0], "wss://gone/play": gone[0]}
	var list: Array[Dictionary] = [{"id": 1, "name": "Far", "url": "wss://far/play"}, {"id": 2, "name": "Odd", "url": "wss://odd/play"},
		{"id": 3, "name": "Mute", "url": "wss://mute/play"}, {"id": 4, "name": "Gone", "url": "wss://gone/play"}]
	var p: ServerProbe = ServerProbe.new(list, "v3", func(url: String) -> NetTransport: return ends[url])
	var asked: Array[int] = [0, 0]
	var done: bool = false
	while not done and net.now < 10.0:
		done = p.poll(net.now)
		for pair: Array in [[far[1], "v3", 0], [odd[1], "v-old", 1]]:
			for m: Dictionary in (pair[0] as NetTransport).receive():
				if m.get("t") == "probe":
					asked[pair[2]] += 1
					(pair[0] as NetTransport).send({"t": "probe_ok", "v": pair[1], "server": 0})
		mute[1].receive()
		net.now += 0.005
	assert_true(done)
	var by: Dictionary = {}
	for r: Dictionary in p.results:
		by[r["name"]] = r
	assert_eq(by["Far"]["state"], "ok")
	assert_near(float(by["Far"]["rtt_ms"]), 200.0, 15.0, "độ trễ ≈ RTT")
	assert_eq(asked[0], ServerProbe.PROBE_ROUNDS, "đủ số lượt rồi dừng")
	assert_eq(by["Odd"]["state"], "version")
	assert_eq(by["Mute"]["state"], "fail", "im lặng tới hạn")
	assert_true(net.now >= ServerProbe.PROBE_TIMEOUT_S - 0.01 and net.now < ServerProbe.PROBE_TIMEOUT_S + 0.2, "chờ đúng hạn")
	assert_eq(by["Gone"]["state"], "fail", "kết nối đóng")


## NET-14: máy chủ phòng trả lời `probe` trước bắt tay, không gọi API tài khoản.
func test_NET_14_room_server_answers_probe_without_auth() -> void:
	var calls: Array[int] = [0]
	var made: Array = _server(7, "", func(token: String, done: Callable) -> void:
		calls[0] += 1
		ApiAuth.dev(token, done))
	var ws: WsTransport = WsTransport.dial(_url(made[1]))
	var got: Array = []
	var ok: bool = _pump([made[0]], null, 3.0, func() -> bool:
		if ws.is_open() and got.is_empty():
			ws.send({"t": "probe"})
			got.append({})
		return got.size() > 1, [[ws, got]])
	assert_true(ok, "có trả lời")
	if ok:
		assert_eq(got[1].get("t"), "probe_ok")
		assert_eq(got[1].get("v"), (made[0] as RoomServer).fingerprint)
		assert_eq(int(got[1].get("server", 0)), 7)
	assert_eq(calls[0], 0, "không gọi API tài khoản")
	ws.close()
	(made[0] as RoomServer).stop()
	(made[0] as RoomServer).queue_free()


## NET-15: máy chủ chỉ phát mã 6 chữ số bắt đầu bằng id của nó; máy khách tìm máy theo chữ số đầu.
func test_NET_15_room_code_carries_server_id() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in 50:
		var code: String = RoomLobby.new_code(rng, 4)
		assert_eq(code.length(), 6)
		assert_true(code.begins_with("4") and code.is_valid_int(), code)
	var list: Array[Dictionary] = [{"id": 1, "name": "SG", "url": "wss://a/play"}, {"id": 2, "name": "Chính", "url": "wss://b/play"}]
	assert_eq(RoomServers.for_code(list, "123456").get("id"), 1)
	assert_eq(RoomServers.for_code(list, "200000").get("id"), 2)
	for bad: String in ["923456", "12345", "1234567", "12a456", "-12345", ""]:
		assert_true(RoomServers.for_code(list, bad).is_empty(), "mã sai: '%s'" % bad)


## NET-14: Tự động qua máy chủ thật — đo, bỏ máy khác bản / không nối được, vào máy ổn, sảnh hiện máy đang dùng.
func test_NET_14_auto_connects_to_compatible_server() -> void:
	var keep: Array = _signed_in("An")
	var good: Array = _server(2)
	var old: Array = _server(1, "2-cu")
	var list: Array[Dictionary] = [{"id": 1, "name": "Cũ", "url": _url(old[1])}, {"id": 2, "name": "Tốt", "url": _url(good[1])},
		{"id": 3, "name": "Tắt", "url": "ws://127.0.0.1:9"}]
	var m: OnlineMenu = _menu(list, 0)
	m.connect_servers()
	var ok: bool = _pump([good[0], old[0]], m, 8.0, func() -> bool: return m.session != null and m.session.stage == "lobby")
	assert_true(ok, "vào sảnh")
	assert_eq(m.server_id, 2)
	var states: Array = m.results.map(func(r: Dictionary) -> String: return r["state"])
	assert_eq(states, ["version", "ok", "fail"])
	assert_eq(m.panel.screen, "home")
	_free(m, [good[0], old[0]])
	_restore(keep)


## NET-14 + NET-06: Tự động — máy đầu trả BUSY khi bắt tay → thử máy kế; chọn tay → báo bận, không nhảy máy.
func test_NET_14_busy_falls_back_only_in_auto() -> void:
	var keep: Array = _signed_in("An")
	var busy: Array = _server(1, "", func(_t: String, done: Callable) -> void: done.call({"busy": true}))
	var good: Array = _server(2)
	var list: Array[Dictionary] = [{"id": 1, "name": "Bận", "url": _url(busy[1])}, {"id": 2, "name": "Tốt", "url": _url(good[1])}]
	var measured: Array[Dictionary] = [{"id": 1, "name": "Bận", "url": _url(busy[1]), "state": "ok", "rtt_ms": 10.0},
		{"id": 2, "name": "Tốt", "url": _url(good[1]), "state": "ok", "rtt_ms": 50.0}]
	var rooms: Array = [busy[0], good[0]]
	var m: OnlineMenu = _menu(list, 0)
	m.results = measured.duplicate(true)
	m._fingerprint = NetVersion.fingerprint()
	m._probe_done()
	assert_eq(m.server_id, 1, "máy thấp nhất trước")
	assert_true(_pump(rooms, m, 6.0, func() -> bool: return m.session != null and m.session.stage == "lobby"), "sang máy kế")
	assert_eq(m.server_id, 2)
	m.close()
	m.choice = 1
	m.results = measured.duplicate(true)
	m._probe_done()
	_pump(rooms, m, 3.0, func() -> bool: return m.panel.screen == "status" and m.session == null)
	assert_eq(m.server_id, 1, "chọn tay: ở lại máy đã chọn")
	assert_true(m.panel._message.text.contains("Bận") and m.panel._message.text.contains("bận"), m.panel._message.text)
	_free(m, rooms)
	_restore(keep)


## NET-15: nhập mã của máy khác (kể cả khi đang chọn tay) → rời máy hiện tại, nối máy của mã, vào phòng; lựa chọn giữ nguyên.
func test_NET_15_join_code_of_other_server_reconnects_there() -> void:
	var keep: Array = _signed_in("Bình")
	var a: Array = _server(1)
	var b: Array = _server(2)
	var rooms: Array = [a[0], b[0]]
	var host: WsTransport = WsTransport.dial(_url(b[1]))
	var host_msgs: Array = []
	var raw: Array = [[host, host_msgs]]
	var sent: Array[bool] = [false]
	assert_true(_pump(rooms, null, 3.0, func() -> bool:
		if host.is_open() and not sent[0]:
			host.send({"t": "hello", "v": NetVersion.fingerprint(), "token": "name:An"})
			host.send({"t": "create", "size": 1})
			sent[0] = true
		return host_msgs.any(func(x: Dictionary) -> bool: return x.get("t") == "lobby"), raw), "chủ phòng tạo phòng ở máy 2")
	var code: String = ""
	for x: Dictionary in host_msgs:
		if x.get("t") == "lobby":
			code = String(x["room"]["code"])
	assert_true(code.begins_with("2"), code)
	var list: Array[Dictionary] = [{"id": 1, "name": "A", "url": _url(a[1])}, {"id": 2, "name": "B", "url": _url(b[1])}]
	var m: OnlineMenu = _menu(list, 1)
	m.connect_servers()
	assert_true(_pump(rooms, m, 8.0, func() -> bool: return m.session != null and m.session.stage == "lobby", raw))
	assert_eq(m.server_id, 1, "chọn tay máy 1")
	m._on_request({"t": "join", "code": "9" + code.substr(1)})
	assert_eq(m.server_id, 1, "chữ số đầu không thuộc máy nào → không nối đi đâu")
	assert_eq(m.panel._message.text, OnlineSession.error_text("NO_ROOM"))
	m._on_request({"t": "join", "code": code})
	assert_true(_pump(rooms, m, 6.0, func() -> bool:
		return m.session != null and String(m.session.room.get("code", "")) == code, raw), "vào phòng ở máy 2")
	assert_eq(m.server_id, 2)
	assert_eq(m.choice, 1, "lựa chọn đã nhớ không đổi")
	assert_eq((m.session.room.get("members", []) as Array).size(), 2)
	host.close()
	_free(m, rooms)
	_restore(keep)


## NET-14: lựa chọn máy chủ được nhớ giữa các lần mở game; máy không còn trong danh sách → Tự động.
func test_NET_14_choice_is_remembered() -> void:
	var list: Array[Dictionary] = [{"id": 1, "name": "A", "url": "ws://127.0.0.1:9"}, {"id": 2, "name": "B", "url": "ws://127.0.0.1:9"}]
	var m: OnlineMenu = _menu(list, 0)
	m._on_request({"t": "server", "id": 2})
	assert_eq(m.choice, 2)
	m.close()
	var again: OnlineMenu = OnlineMenu.new()
	again.prefs_path = m.prefs_path
	again.servers = list
	assert_eq(again.load_choice(), 2)
	again.servers = [list[0]] as Array[Dictionary]
	assert_eq(again.load_choice(), 0, "máy đã bỏ khỏi danh sách → Tự động")
	again.free()
	_free(m, [])


## NET-06 (D-401): API tài khoản 401 → AUTH ngay; 429 / 5xx / không nối → thử lại 2 lần, vẫn hỏng → BUSY; bận rồi ổn → vào.
func test_NET_06_auth_api_busy_is_not_expired_session() -> void:
	assert_eq(ApiAuth.classify(HTTPRequest.RESULT_SUCCESS, 200), "ok")
	assert_eq(ApiAuth.classify(HTTPRequest.RESULT_SUCCESS, 401), "auth")
	assert_eq(ApiAuth.classify(HTTPRequest.RESULT_SUCCESS, 429), "busy")
	assert_eq(ApiAuth.classify(HTTPRequest.RESULT_SUCCESS, 502), "busy")
	assert_eq(ApiAuth.classify(HTTPRequest.RESULT_TIMEOUT, 0), "busy")
	var cases: Array = [[[401], {}, 1], [[429, 503, 500], {"busy": true}, 3], [[429, 200], {"id": 5.0, "name": "An"}, 2]]
	for c: Array in cases:
		var codes: Array = (c[0] as Array).duplicate()
		var calls: Array[int] = [0]
		var a: ApiAuth = ApiAuth.new()
		a.fetch = func(_t: String, got: Callable) -> void:
			calls[0] += 1
			got.call(HTTPRequest.RESULT_SUCCESS, int(codes.pop_front()), '{"id": 5, "name": "An"}'.to_utf8_buffer())
		a.wait = func(_s: float, then: Callable) -> void: then.call()
		var out: Array = []
		a.check("tok", func(acc: Dictionary) -> void: out.append(acc))
		assert_eq(out, [c[1]], str(c[0]))
		assert_eq(calls[0], c[2], "số lượt hỏi " + str(c[0]))
		a.free()


## NET-06: máy chủ phòng báo BUSY (không phải AUTH) khi kiểm phiên bận.
func test_NET_06_room_server_reports_busy() -> void:
	var made: Array = _server(1, "", func(_t: String, done: Callable) -> void: done.call({"busy": true}))
	var ws: WsTransport = WsTransport.dial(_url(made[1]))
	var got: Array = []
	var sent: Array[bool] = [false]
	_pump([made[0]], null, 3.0, func() -> bool:
		if ws.is_open() and not sent[0]:
			ws.send({"t": "hello", "v": (made[0] as RoomServer).fingerprint, "token": "name:An"})
			sent[0] = true
		return not got.is_empty(), [[ws, got]])
	assert_eq(got.size(), 1)
	if not got.is_empty():
		assert_eq([got[0].get("t"), got[0].get("code"), got[0].get("for")], ["error", "BUSY", "hello"])
	assert_eq(OnlineSession.error_text("BUSY"), "Máy chủ đang bận — thử lại sau")
	ws.close()
	(made[0] as RoomServer).stop()
	(made[0] as RoomServer).queue_free()


## NET-10 (D-401): giao thức 3 — bản game cũ (giao thức 2) bị máy chủ mới từ chối.
func test_NET_10_protocol_is_3() -> void:
	assert_eq(NetVersion.PROTOCOL, 3)
	assert_true(NetVersion.fingerprint().begins_with("3-"))


## NET-21 (D-407): game nhớ mã trận online gần nhất — mở bảng thì hỏi máy của trận đó trước (kể cả khi đang chọn tay máy
## khác): còn trận → ở lại, có nút Vào lại; trận đã hết → quên mã, về máy theo lựa chọn.
func test_NET_21_remembered_match_server_is_asked_first() -> void:
	var keep: Array = _signed_in("Bình")
	var a: Array = _server(1)
	var b: Array = _server(2)
	var rooms: Array = [a[0], b[0]]
	var account: Array = [0]
	ApiAuth.dev("name:Bình", func(acc: Dictionary) -> void: account[0] = int(acc["id"]))
	var cfg: MatchConfig = MatchConfig.make(1, [&"gorran", &"myra"] as Array[StringName], [0, 1], BotState.Difficulty.NORMAL, 5)
	var g: RoomGame = RoomGame.create("234567", cfg, ContentLibrary.load_dir())
	g.accounts = {1: account[0]}
	(b[0] as RoomServer)._games["234567"] = g
	var list: Array[Dictionary] = [{"id": 1, "name": "A", "url": _url(a[1])}, {"id": 2, "name": "B", "url": _url(b[1])}]
	var m: OnlineMenu = _menu(list, 1)
	m.save_match("234567")
	m.connect_servers()
	assert_true(_pump(rooms, m, 10.0, func() -> bool: return m.session != null and m.session.stage == "lobby"))
	assert_eq([m.server_id, m.session.live], [2, "234567"], "ở máy của trận, báo trận đang đánh")
	assert_eq(m.choice, 1, "lựa chọn không đổi")
	assert_true(m.panel.find_children("*", "Button", true, false).any(func(x: Button) -> bool: return x.text.begins_with("Vào lại")))
	(b[0] as RoomServer)._games.erase("234567")
	m.connect_servers()
	assert_true(_pump(rooms, m, 10.0, func() -> bool: return m.session != null and m.session.stage == "lobby" and m.server_id == 1))
	assert_eq(m.load_match(), "", "trận đã hết → quên mã")
	_free(m, rooms)
	_restore(keep)
