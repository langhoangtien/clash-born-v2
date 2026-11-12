class_name ServerProbe
extends RefCounted
## NET-14 (D-401): đo độ trễ tới mọi máy chủ phòng cùng lúc, TRƯỚC bắt tay (không cần tài khoản): mỗi máy tối đa
## PROBE_ROUNDS tin `probe` nối tiếp, độ trễ = trung vị các lượt đã trả lời. Máy trả dấu vân tay khác → "version"; kết nối
## đóng, hoặc hết PROBE_TIMEOUT_S chưa trả lượt nào → "fail". Giữ kết nối máy ổn để bắt tay luôn trên đó (`take`).

const PROBE_ROUNDS: int = 3
const PROBE_TIMEOUT_S: float = 4.0

## [{id, name, url, state ("probing" / "ok" / "version" / "fail"), rtt_ms}] theo thứ tự danh sách.
var results: Array[Dictionary] = []
## Có kết quả mới từ lần đọc trước (APP vẽ lại bảng).
var changed: bool = true
var _links: Dictionary[int, NetTransport] = {}
var _sent_at: Dictionary[int, float] = {}
var _rtts: Dictionary[int, Array] = {}
var _version: String
var _start: float = -1.0


## `dial`: func(url: String) -> NetTransport.
func _init(servers: Array[Dictionary], version: String, dial: Callable) -> void:
	_version = version
	for s: Dictionary in servers:
		var id: int = int(s["id"])
		results.append(s.merged({"state": "probing", "rtt_ms": 0.0}))
		_links[id] = dial.call(String(s["url"]))
		_rtts[id] = []


## Gọi mỗi khung (đồng hồ giây). true khi mọi máy đã có kết quả.
func poll(now: float) -> bool:
	if _start < 0.0:
		_start = now
	var done: bool = true
	for r: Dictionary in results:
		if r["state"] == "probing":
			_poll_one(r, now)
		done = done and r["state"] != "probing"
	return done


func _poll_one(r: Dictionary, now: float) -> void:
	var id: int = int(r["id"])
	var t: NetTransport = _links[id]
	for msg: Dictionary in t.receive():
		if String(msg.get("t", "")) != "probe_ok" or not _sent_at.has(id):
			continue
		if String(msg.get("v", "")) != _version:
			_finish(r, "version")
			return
		_rtts[id].append((now - _sent_at[id]) * 1000.0)
		_sent_at.erase(id)
	if _closed(t):
		_finish(r, "fail")
	elif _rtts[id].size() >= PROBE_ROUNDS or now - _start >= PROBE_TIMEOUT_S:
		_finish(r, "fail" if _rtts[id].is_empty() else "ok")
	elif t.is_open() and not _sent_at.has(id):
		_sent_at[id] = now
		t.send({"t": "probe"})


func _finish(r: Dictionary, state: String) -> void:
	var id: int = int(r["id"])
	r["state"] = state
	changed = true
	if state == "ok":
		var v: Array = _rtts[id].duplicate()
		v.sort()
		r["rtt_ms"] = float(v[v.size() / 2])
	else:
		_links[id].close()
		_links.erase(id)


static func _closed(t: NetTransport) -> bool:
	return bool(t.call("closed")) if t.has_method("closed") else not t.is_open()


## Kết nối đã đo của máy `id` (null nếu không còn); các kết nối khác vẫn mở tới khi close_all.
func take(id: int) -> NetTransport:
	var t: NetTransport = _links.get(id)
	_links.erase(id)
	return t


func close_all() -> void:
	for id: int in _links:
		_links[id].close()
	_links.clear()
