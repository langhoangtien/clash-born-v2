class_name OnlineMenu
extends Node
## M9.6 (D-344) + NET-13..15 (D-401): APP — nối bảng Chơi online (OnlinePanel) với mạng. Mở bảng → cần đăng nhập + tên
## trong game → đo độ trễ mọi máy chủ phòng (ServerProbe) → vào máy theo lựa chọn (Tự động / chọn tay, nhớ ở PREFS) →
## OnlineSession chuyển tin sảnh lên bảng. Nhập mã phòng của máy khác → nối thẳng máy đó. Máy chủ chào vào trận → giao phiên
## cho màn trận rồi đổi màn. `servers` / `dial` / `clock` / `prefs_path` thay được trong test.

signal match_ready(session: OnlineSession)

const PREFS: String = "user://online.cfg"

var panel: OnlinePanel
var session: OnlineSession
var probe: ServerProbe
var servers: Array[Dictionary] = RoomServers.load_list()
## func(url: String) -> NetTransport — mặc định WebSocket tới máy chủ thật.
var dial: Callable = func(url: String) -> NetTransport: return WsTransport.dial(url)
var version: Callable = NetVersion.fingerprint
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var prefs_path: String = PREFS
## NET-14: máy chọn tay (id) hoặc 0 = Tự động.
var choice: int = 0
## Máy đang nối (-1 = chưa).
var server_id: int = -1
## Kết quả đo gần nhất (bảng hiện độ trễ từng máy).
var results: Array[Dictionary] = []
var _order: Array[int] = []       ## Tự động: máy còn lại để thử khi máy đang nối báo BUSY
var _join_code: String = ""       ## NET-15: vào phòng này ngay khi bắt tay xong
var _error_shown: bool = false    ## đã báo lỗi bắt tay → tin "mất kết nối" sau đó không đè lên
var _fingerprint: String = ""


func attach(p: OnlinePanel) -> void:
	panel = p
	panel.request.connect(_on_request)
	panel.closed.connect(close)
	choice = load_choice()


## Mở bảng (nút Online ở menu).
func open() -> void:
	panel.visible = true
	if not AccountClient.signed_in():
		panel.show_status("Cần đăng nhập để chơi online (nút Đăng nhập ở trên)", true)
		return
	if String(AccountClient.account.get("name", "")) == "":
		panel.show_status(OnlineSession.error_text("NO_NAME"), true)
		return
	if session != null and session.stage == "lobby":
		_show_lobby()
		return
	if probe != null:
		return
	panel.show_status("Đang đo độ trễ máy chủ…")
	await get_tree().process_frame  # hiện chữ trước khi tính dấu vân tay SIM (~0,5–1 s trên điện thoại)
	connect_servers()


## NET-14: ngắt máy đang nối, đo lại mọi máy, rồi nối theo lựa chọn.
func connect_servers() -> void:
	_drop_session()
	if _fingerprint == "":
		_fingerprint = version.call()
	probe = ServerProbe.new(servers, _fingerprint, dial)
	results = probe.results


func close() -> void:
	_drop_session()
	if probe != null:
		probe.close_all()
		probe = null
	panel.visible = false


func _process(_delta: float) -> void:
	step()


## Một vòng (mỗi khung; test gọi tay).
func step() -> void:
	if probe != null:
		var done: bool = probe.poll(clock.call())
		if probe.changed:
			probe.changed = false
			_status("Đang đo độ trễ máy chủ…", false)
		if done:
			_probe_done()
		return
	if session == null or session.stage == "game":
		return
	for msg: Dictionary in session.poll():
		_on_message(msg)


func _probe_done() -> void:
	_order = RoomServers.order(results, choice)
	var t: NetTransport = null
	if not _order.is_empty() and probe != null:
		t = probe.take(_order[0])
	if probe != null:
		probe.close_all()
		probe = null
	if _order.is_empty():
		_status(RoomServers.failure_text(results, choice), true)
		return
	_connect(_order.pop_front(), t)


## Nối máy `id` (dùng kết nối đã đo nếu có) rồi bắt tay.
func _connect(id: int, t: NetTransport = null) -> void:
	server_id = id
	_error_shown = false
	if t == null:
		t = dial.call(String(RoomServers.by_id(servers, id).get("url", "")))
	session = OnlineSession.new(t, AccountClient.token, _fingerprint)
	_status("Đang vào máy chủ %s…" % _name(id), false)


func _drop_session() -> void:
	if session != null:
		session.send({"t": "leave"})
		session.close()
		session = null
	server_id = -1


func _on_message(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"hello_ok":
			if _join_code != "":
				session.send({"t": "join", "code": _join_code})
				_join_code = ""
			_show_lobby()
		"lobby":
			_show_lobby()
		"error":
			_on_error(String(msg.get("code", "")), String(msg.get("for", "")))
		"welcome":
			var s: OnlineSession = session
			session = null  # màn trận giữ phiên từ đây
			match_ready.emit(s)
		"closed":
			var was_lobby: bool = panel.screen != "status"
			session = null
			_join_code = ""
			if not _error_shown:
				_status(("Mất kết nối máy chủ %s" if was_lobby else "Không nối được máy chủ %s") % _name(server_id), true)


func _on_error(code: String, about: String) -> void:
	if about != "hello":
		panel.say(OnlineSession.error_text(code), true)
		return
	if code == "BUSY" and choice == 0 and not _order.is_empty():  # NET-14: Tự động — máy bận coi như hỏng, sang máy kế
		session.close()
		session = null
		_connect(_order.pop_front())
		return
	var text: String = OnlineSession.error_text(code)
	if code == "BUSY":
		text = "Máy chủ %s đang bận — thử lại sau%s" % [_name(server_id), " hoặc chọn máy khác" if choice > 0 else ""]
	_error_shown = true
	_join_code = ""
	_status(text, true)


func _on_request(msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"server":  # NET-14: đổi lựa chọn → nhớ, đo lại, nối lại
			choice = int(msg.get("id", 0))
			save_choice(choice)
			connect_servers()
		"join":
			_join(String(msg.get("code", "")).strip_edges())
		_:
			if session != null:
				session.send(msg)


## NET-15: mã phòng → máy của mã (chữ số đầu); máy khác máy đang nối → nối thẳng máy đó rồi vào phòng.
func _join(code: String) -> void:
	var target: Dictionary = RoomServers.for_code(servers, code)
	if target.is_empty():
		panel.say(OnlineSession.error_text("NO_ROOM"), true)
		return
	if int(target["id"]) == server_id and session != null:
		session.send({"t": "join", "code": code})
		return
	_drop_session()
	_order.clear()
	_join_code = code
	_connect(int(target["id"]))


func _show_lobby() -> void:
	_panel_servers()
	if session.room.is_empty():
		panel.show_home(session.name)
	else:
		panel.show_room(session.room, session.peer_id, session.heroes)


func _status(text: String, error: bool) -> void:
	_panel_servers()
	panel.show_status(text, error)


func _panel_servers() -> void:
	panel.servers = results
	panel.choice = choice
	panel.current = server_id


func _name(id: int) -> String:
	return String(RoomServers.by_id(servers, id).get("name", "#%d" % id))


## NET-14: lựa chọn đã nhớ (0 = Tự động; máy không còn trong danh sách → Tự động).
func load_choice() -> int:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(prefs_path) != OK:
		return 0
	var c: int = int(cfg.get_value("online", "server", 0))
	return c if c == 0 or not RoomServers.by_id(servers, c).is_empty() else 0


func save_choice(c: int) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(prefs_path)
	cfg.set_value("online", "server", c)
	cfg.save(prefs_path)
