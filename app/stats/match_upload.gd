class_name MatchUpload
extends Node
## ST.1 (D-331): trận có đội thắng → gửi biên bản (MatchRecord) lên clashborn.quest/api/match cho Clashborn Stats.
## Không cần mã bí mật (máy chủ kiểm dạng, nginx giới hạn số lần / IP). Không gửi: Benchmark A/B, trận có nút
## Test (trận thử — MATCH-06). D-339: báo kết quả cho màn kết quả (`done(ok, câu)`); lỗi → giữ biên bản ở FAILED_FILE để
## chẩn đoán (vd lỗi 400 trận 3v3 người chơi báo). Không hỏi lại người chơi, không chặn màn kết quả.

const PATH: String = "api/match"
const TIMEOUT_S: float = 30.0
const FAILED_FILE: String = "user://last_failed_match.json"


## Gửi (tự gỡ khi xong); trả false nếu là trận không tính (trận thử, Benchmark). `done(ok: bool, câu: String)` khi máy chủ trả lời.
static func send(parent: Node, record: Dictionary, done: Callable = Callable()) -> bool:
	if record.get("practice", false) or BenchSession.requested:
		return false
	var up: MatchUpload = MatchUpload.new()
	up.name = "MatchUpload"
	parent.add_child(up)
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_S
	http.use_threads = true
	up.add_child(http)
	http.request_completed.connect(func(r: int, c: int, _h: PackedStringArray, b: PackedByteArray) -> void:
		up.queue_free()
		var reply: String = _reply(r, c, b)
		if c != 200:
			_keep(record, reply)
		if done.is_valid():
			done.call(c == 200, reply))
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if AccountClient.token != "":  # D-334: đã đăng nhập → trận gắn tài khoản (lịch sử trận)
		headers.append("%s: %s" % [AccountClient.HEADER, AccountClient.token])
	if http.request(Updater.SITES[0] + PATH, headers, HTTPClient.METHOD_POST, JSON.stringify(record)) != OK:
		up.queue_free()
		_keep(record, "request failed")
		if done.is_valid():
			done.call(false, "Thống kê: không gửi được (mạng)")
	return true


## Câu cho người chơi: đã lưu / lý do máy chủ trả.
static func _reply(result: int, code: int, body: PackedByteArray) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "Thống kê: không gửi được (mạng)"
	if code == 200:
		return "Thống kê: đã lưu trận"
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	return "Thống kê: không lưu được (%d) — %s" % [code, data.get("error", "?") if data is Dictionary else "?"]


static func _keep(record: Dictionary, reply: String) -> void:
	var f: FileAccess = FileAccess.open(FAILED_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"reply": reply, "record": record}))
