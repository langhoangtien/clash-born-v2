class_name PerfUpload
extends Node
## D-287: gửi kết quả đo (Benchmark A/B hoặc log trận) lên clashborn.quest/api/report khi người chơi bấm "Gửi lên
## máy chủ". Không cần mã bí mật (máy chủ chỉ nhận, đọc lại mới cần mã); máy chủ trả mã báo cáo (B-0042 / L-0043)
## để người chơi nhắn lại. Gửi lỗi thì file trong máy vẫn còn như trước.

## Cắt ghi chú như máy chủ (tools/vps/reports.py NOTE_MAX).
const NOTE_MAX: int = 500
const PATH: String = "api/report"
const TIMEOUT_S: float = 60.0

var _http: HTTPRequest
var _done: Callable


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_S
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_completed)


func busy() -> bool:
	return _done.is_valid()


## Gửi; `done(ok, message)` khi máy chủ trả lời. Đang gửi dở thì bỏ qua lần bấm mới.
func send(kind: StringName, note: String, summary: String, data: Dictionary, done: Callable) -> void:
	if busy():
		return
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var err: Error = _http.request(Updater.SITES[0] + PATH, headers, HTTPClient.METHOD_POST, body(kind, note, summary, data))
	if err != OK:
		done.call(false, "Không gửi được · bấm Gửi để thử lại")
		return
	_done = done
	done.call(true, "Đang gửi…")


static func body(kind: StringName, note: String, summary: String, data: Dictionary) -> String:
	return JSON.stringify({"kind": String(kind), "note": note.strip_edges().left(NOTE_MAX), "summary": summary, "data": data})


## Câu báo theo trả lời máy chủ: {ok, message}.
static func reply(result: int, code: int, response: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "message": "Gửi lỗi (mạng?) · bấm Gửi để thử lại"}
	if code == 429:
		return {"ok": false, "message": "Gửi nhiều quá · chờ 1 phút rồi thử lại"}
	if code == 413:
		return {"ok": false, "message": "Log quá lớn để gửi · dùng Lưu JSON"}
	var json: JSON = JSON.new()
	var data: Variant = json.data if json.parse(response.get_string_from_utf8()) == OK else null
	if code != 200 or not data is Dictionary or not (data as Dictionary).has("id"):
		return {"ok": false, "message": "Máy chủ báo lỗi (%d) · bấm Gửi để thử lại" % code}
	return {"ok": true, "message": "Đã gửi · mã %s — nhắn mã này cho Claude" % data["id"]}


func _on_completed(result: int, code: int, _headers: PackedStringArray, response: PackedByteArray) -> void:
	var r: Dictionary = reply(result, code, response)
	var done: Callable = _done
	_done = Callable()
	done.call(r["ok"], r["message"])
