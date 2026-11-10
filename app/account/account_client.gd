class_name AccountClient
extends Node
## D-333 (ROADMAP ACC.3): tài khoản người chơi phía game — gọi /api/auth/* (tools/vps/accounts.py), giữ phiên đăng nhập
## trong máy (user://account.cfg, chỉ token phiên — không bao giờ lưu mật khẩu). Đăng nhập Google: xin `sid`, mở trình
## duyệt tới trang Google, hỏi máy chủ mỗi POLL_S giây tới khi có phiên. Tĩnh `token` / `account` cho chỗ khác đọc
## (online, biên bản trận). Một yêu cầu một lúc.

signal changed                                   ## đăng nhập / đổi tên / đăng xuất
signal replied(action: String, ok: bool, code: String, message: String, data: Dictionary)

const FILE: String = "user://account.cfg"
const HEADER: String = "X-Clashborn-Session"
const TIMEOUT_S: float = 25.0
const POLL_S: float = 2.0
const GOOGLE_WAIT_S: float = 600.0

static var token: String = ""
static var account: Dictionary = {}

var _http: HTTPRequest
var _action: String = ""
var _google_sid: String = ""
var _google_left: float = 0.0
var _poll_in: float = 0.0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_S
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(FILE) == OK:
		token = cfg.get_value("session", "token", "")
	if token != "":
		send("me", {})


static func signed_in() -> bool:
	return token != "" and not account.is_empty()


func busy() -> bool:
	return _action != ""


## POST /api/auth/<action> (riêng "me": GET). Đang bận thì bỏ qua.
func send(action: String, body: Dictionary) -> void:
	if busy():
		return
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("%s: %s" % [HEADER, token])
	var get: bool = action == "me" or action == "history"  # D-334: lịch sử trận
	var method: HTTPClient.Method = HTTPClient.METHOD_GET if get else HTTPClient.METHOD_POST
	_action = action
	if _http.request(Updater.SITES[0] + "api/auth/" + action, headers, method, "" if get else JSON.stringify(body)) != OK:
		_finish(false, "NETWORK", "Không gửi được — kiểm tra mạng", {})


func google() -> void:
	_google_sid = ""
	send("google/start", {})


func cancel_google() -> void:
	_google_sid = ""


func logout() -> void:
	send("logout", {})


func _process(delta: float) -> void:
	if _google_sid == "" or busy():
		return
	_google_left -= delta
	_poll_in -= delta
	if _google_left <= 0.0:
		_google_sid = ""
		replied.emit("google/poll", false, "GOOGLE_EXPIRED", "Hết thời gian đăng nhập Google — thử lại", {})
	elif _poll_in <= 0.0:
		_poll_in = POLL_S
		send("google/poll", {"sid": _google_sid})


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
	if not data is Dictionary:
		_finish(false, "NETWORK", "Không kết nối được máy chủ — thử lại", {})
		return
	if code != 200:
		_finish(false, String(data.get("code", "ERROR")), String(data.get("error", "Lỗi %d" % code)), data)
		return
	_finish(true, "", "", data)


func _finish(ok: bool, code: String, message: String, data: Dictionary) -> void:
	var action: String = _action
	_action = ""
	if ok and data.has("token"):
		_save(String(data["token"]))
	if ok and (data.has("account") or action in ["me", "name", "password"]):
		account = data.get("account", data)
		changed.emit()
	if action == "logout" or (action == "delete" and ok) or code == "NO_SESSION":
		_save("")
		account = {}
		changed.emit()
	if action == "google/start" and ok:
		_google_sid = String(data["sid"])
		_google_left = GOOGLE_WAIT_S
		_poll_in = POLL_S
		OS.shell_open(String(data["url"]))
	if action == "google/poll" and (data.has("token") or not ok):
		_google_sid = ""
	if action == "google/poll" and ok and data.get("pending", false):
		return  # còn chờ: không báo
	replied.emit(action, ok, code, message, data)


func _save(t: String) -> void:
	token = t
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("session", "token", t)
	cfg.save(FILE)
