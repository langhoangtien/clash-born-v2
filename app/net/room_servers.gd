class_name RoomServers
extends RefCounted
## NET-13..15 (D-401): danh sách máy chủ phòng là dữ liệu (room_servers.json: id 1–9, tên hiện, địa chỉ wss); chọn máy theo
## kết quả đo (ServerProbe) và lựa chọn của người chơi (0 = Tự động); tìm máy theo chữ số đầu của mã phòng. Thuần, không mạng.

const FILE: String = "res://app/net/room_servers.json"
const DIGITS: String = "0123456789"


static func load_list(path: String = FILE) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Array:
		for d: Variant in data:
			if d is Dictionary:
				out.append({"id": int(d.get("id", 0)), "name": String(d.get("name", "")), "url": String(d.get("url", ""))})
	return out


## NET-13: "" = hợp lệ.
static func validate(list: Array[Dictionary]) -> String:
	if list.is_empty():
		return "danh sách trống"
	var seen: Dictionary = {}
	for s: Dictionary in list:
		var id: int = int(s.get("id", 0))
		if id < 1 or id > 9:
			return "id %d ngoài 1–9 (mã phòng chỉ dành một chữ số — NET-15)" % id
		if seen.has(id):
			return "trùng id %d" % id
		seen[id] = true
		if String(s.get("name", "")) == "":
			return "máy %d thiếu tên" % id
		var url: String = String(s.get("url", ""))
		if not (url.begins_with("wss://") or url.begins_with("ws://")):
			return "máy %d địa chỉ sai: %s" % [id, url]
	return ""


static func by_id(list: Array[Dictionary], id: int) -> Dictionary:
	for s: Dictionary in list:
		if int(s.get("id", 0)) == id:
			return s
	return {}


## NET-15: máy của mã phòng ({} = không đủ 6 chữ số, hoặc chữ số đầu không thuộc máy nào).
static func for_code(list: Array[Dictionary], code: String) -> Dictionary:
	if code.length() != RoomLobby.CODE_LEN:
		return {}
	for c: String in code:
		if not DIGITS.contains(c):
			return {}
	return by_id(list, int(code[0]))


## NET-14: thứ tự máy để thử. 0 = Tự động: máy ổn theo độ trễ tăng dần (bằng nhau → id nhỏ). Chọn tay: chỉ máy đó, nếu ổn.
static func order(results: Array[Dictionary], choice: int) -> Array[int]:
	var ok: Array[Dictionary] = []
	for r: Dictionary in results:
		if r.get("state") == "ok" and (choice == 0 or int(r["id"]) == choice):
			ok.append(r)
	ok.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rtt_ms"]) < float(b["rtt_ms"]) or (float(a["rtt_ms"]) == float(b["rtt_ms"]) and int(a["id"]) < int(b["id"])))
	var out: Array[int] = []
	for r: Dictionary in ok:
		out.append(int(r["id"]))
	return out


## NET-14: câu báo khi không còn máy nào để thử.
static func failure_text(results: Array[Dictionary], choice: int) -> String:
	if choice > 0:
		var r: Dictionary = by_id(results, choice)
		var name: String = String(r.get("name", "#%d" % choice))
		if r.get("state") == "version":
			return "Máy chủ %s khác phiên bản — cập nhật game hoặc chọn máy khác" % name
		return "Máy chủ %s không nối được — chọn máy khác hoặc Tự động" % name
	if results.any(func(x: Dictionary) -> bool: return x.get("state") == "version"):
		return OnlineSession.error_text("VERSION")
	return "Không nối được máy chủ phòng nào — kiểm tra mạng rồi thử lại"


## Chữ một máy trên bảng Online.
static func label(r: Dictionary) -> String:
	match String(r.get("state", "")):
		"ok":
			return "%s · %d ms" % [r["name"], roundi(float(r["rtt_ms"]))]
		"version":
			return "%s · khác bản" % r["name"]
		"fail":
			return "%s · không nối" % r["name"]
	return "%s · đang đo…" % r.get("name", "?")
