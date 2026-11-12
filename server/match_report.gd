class_name MatchReport
extends Node
## NET-12 (ST.5, D-405): máy chủ phòng ghi trận online — biên bản từ bản SIM của máy chủ (MatchRecord) + khóa mã phòng-seed
## + ô → tài khoản + ô đã rời, gửi POST /api/room_match bằng mã riêng (rooms_token; không bao giờ in ra). Lỗi mạng / 5xx →
## thử lại sau RETRY_S; hết lượt hoặc 4xx → in nguyên biên bản vào nhật ký (`room_match failed:`) để gửi tay.

const RETRY_S: Array[float] = [1.0, 5.0, 30.0]
const TIMEOUT_S: float = 10.0
const VERSION: String = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,6}$"

var api: String = "http://127.0.0.1:8787"
var token: String = ""
## Một lượt gửi: func(body: String, got: Callable(result: int, code: int)) — test thay được.
var fetch: Callable
## Chờ rồi làm tiếp: func(seconds: float, then: Callable).
var wait: Callable


func _init() -> void:
	fetch = _http_fetch
	wait = func(seconds: float, then: Callable) -> void: get_tree().create_timer(seconds).timeout.connect(then)


## `accounts`: ô → tài khoản (mọi ô người lúc bắt đầu); `slots`: mã người chơi → ô; `app`: số bản của người tạo phòng.
static func payload(room: LockstepRoom, cfg: MatchConfig, code: String, accounts: Dictionary, slots: Dictionary, app: String) -> Dictionary:
	var re: RegEx = RegEx.create_from_string(VERSION)
	var owners: Array = []
	var ids: Array = accounts.keys()
	ids.sort()
	for slot: int in ids:
		owners.append([slot, int(accounts[slot])])
	var left: Array = []
	for peer: int in room.gone:
		if slots.has(peer):
			left.append(int(slots[peer]))
	left.sort()
	var record: Dictionary = MatchRecord.of(room.world, cfg, app if re.search(app) != null else "0.0.0")
	for pair: Array in owners:  # NET-12: ô người đã rời (bot đánh thay — NET-17) vẫn là ô người của tài khoản đó
		record["players"][pair[0]]["bot"] = false
	return {"record": record, "match_key": "%s-%d" % [code, cfg.seed], "accounts": owners, "left": left}


func send(p: Dictionary, done: Callable = Callable()) -> void:
	_try(JSON.stringify(p), 0, done)


func _try(body: String, attempt: int, done: Callable) -> void:
	fetch.call(body, func(result: int, code: int) -> void:
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200
		var transient: bool = not ok and (result != HTTPRequest.RESULT_SUCCESS or code == 429 or code >= 500)
		if transient and attempt < RETRY_S.size():
			wait.call(RETRY_S[attempt], func() -> void: _try(body, attempt + 1, done))
			return
		if not ok:
			print("room_match failed (kết quả %d, mã HTTP %d): %s" % [result, code, body])
		if done.is_valid():
			done.call(ok))


func _http_fetch(body: String, got: Callable) -> void:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_S
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		http.queue_free()
		got.call(result, code))
	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer " + token]
	if http.request(api + "/api/room_match", headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		got.call(HTTPRequest.RESULT_CANT_CONNECT, 0)
