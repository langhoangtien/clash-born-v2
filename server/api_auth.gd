class_name ApiAuth
extends Node
## D-338 (NET-06): máy chủ phòng kiểm phiên đăng nhập qua API tài khoản (tools/vps/accounts.py: GET /api/auth/me, header
## X-Clashborn-Session). D-401: phiên sai / hết hạn / tài khoản bị khóa → done({}) (AUTH); API bận / hỏng (429, 5xx, không
## nối, quá hạn) → thử lại RETRIES lần cách RETRY_S giây, vẫn hỏng → done({"busy": true}) (BUSY). Máy Singapore gọi qua
## mạng ngoài: mọi người chơi của nó chung một IP trước giới hạn nginx của máy chính.

const TIMEOUT_S: float = 4.0
const RETRIES: int = 2
const RETRY_S: float = 1.0

var api: String = "http://127.0.0.1:8787"
## Một lượt hỏi: func(token, got: Callable(result: int, code: int, body: PackedByteArray)) — test thay được.
var fetch: Callable
## Chờ rồi làm tiếp: func(seconds: float, then: Callable) — test thay bằng gọi ngay.
var wait: Callable


func _init() -> void:
	fetch = _http_fetch
	wait = _timer_wait


func check(token: String, done: Callable) -> void:
	if token == "":
		done.call({})
		return
	_try(token, done, RETRIES)


func _try(token: String, done: Callable, left: int) -> void:
	fetch.call(token, func(result: int, code: int, body: PackedByteArray) -> void:
		var verdict: String = classify(result, code)
		if verdict == "busy" and left > 0:
			wait.call(RETRY_S, func() -> void: _try(token, done, left - 1))
		elif verdict == "busy":
			done.call({"busy": true})
		else:
			var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if verdict == "ok" else null
			done.call(data if data is Dictionary and data.has("id") else {}))


## NET-06 (D-401): "ok" (đọc tài khoản), "auth" (phiên sai — 401 / 403 / 4xx khác), "busy" (thử lại).
static func classify(result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "busy"
	if code == 200:
		return "ok"
	if code == 429 or code >= 500:
		return "busy"
	return "auth"


func _http_fetch(token: String, got: Callable) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_S
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		got.call(result, code, body))
	if http.request(api + "/api/auth/me", PackedStringArray(["X-Clashborn-Session: " + token])) != OK:
		http.queue_free()
		got.call(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())


func _timer_wait(seconds: float, then: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(then)


## Chỉ thử ở máy mình (--dev-auth / test): "name:<tên>" → tài khoản giả.
static func dev(token: String, done: Callable) -> void:
	if not token.begins_with("name:"):
		done.call({})
		return
	var name: String = token.trim_prefix("name:")
	done.call({"id": absi(name.hash()) % 1000000 + 1, "name": name})
