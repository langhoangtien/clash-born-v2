class_name ApiAuth
extends Node
## D-338 (NET-06): máy chủ phòng kiểm phiên đăng nhập qua API tài khoản cục bộ (tools/vps/accounts.py:
## GET /api/auth/me, header X-Clashborn-Session). Phiên sai / hết hạn / tài khoản bị khóa → done({}).

const TIMEOUT_S: float = 10.0

var api: String = "http://127.0.0.1:8787"


func check(token: String, done: Callable) -> void:
	if token == "":
		done.call({})
		return
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_S
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS else null
		done.call(data if code == 200 and data is Dictionary and data.has("id") else {}))
	if http.request(api + "/api/auth/me", PackedStringArray(["X-Clashborn-Session: " + token])) != OK:
		http.queue_free()
		done.call({})


## Chỉ thử ở máy mình (--dev-auth / test): "name:<tên>" → tài khoản giả.
static func dev(token: String, done: Callable) -> void:
	if not token.begins_with("name:"):
		done.call({})
		return
	var name: String = token.trim_prefix("name:")
	done.call({"id": absi(name.hash()) % 1000000 + 1, "name": name})
