class_name MatchUpload
extends Node
## ST.1 (D-331): trận có đội thắng → gửi biên bản (MatchRecord) lên clashborn.quest/api/match cho Clashborn Stats.
## Không cần mã bí mật (máy chủ kiểm dạng, nginx giới hạn số lần / IP). Không gửi: Benchmark A/B, trận có nút
## Test (trận thử — MATCH-06). Gửi lỗi thì thôi — không hỏi lại người chơi, không chặn màn kết quả.

const PATH: String = "api/match"
const TIMEOUT_S: float = 30.0


## Gửi (tự gỡ khi xong); trả false nếu biên bản không được gửi.
static func send(parent: Node, record: Dictionary) -> bool:
	if record.get("practice", false) or BenchSession.requested:
		return false
	var up: MatchUpload = MatchUpload.new()
	up.name = "MatchUpload"
	parent.add_child(up)
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT_S
	http.use_threads = true
	up.add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void: up.queue_free())
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if http.request(Updater.SITES[0] + PATH, headers, HTTPClient.METHOD_POST, JSON.stringify(record)) != OK:
		up.queue_free()
		return false
	return true
