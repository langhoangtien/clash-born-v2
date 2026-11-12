class_name OnlineSession
extends RefCounted
## M9.6 (D-344): một phiên online của máy khách — nối một máy chủ phòng (NET-13: room_servers.json), bắt tay (dấu vân tay
## SIM NET-10 + phiên tài khoản NET-06), chuyển tin sảnh cho menu; nhận lời chào `welcome` → dựng LockstepClient, giữ cấu
## hình trận + đơn vị của mình cho màn trận. Sống qua đổi màn (màn trận giữ tham chiếu tĩnh). Không đụng SIM.

var transport: NetTransport
## connecting → hello → lobby → game → closed
var stage: String = "connecting"
var name: String = ""                  ## tên trong game máy chủ báo
var live: String = ""                  ## NET-21: mã trận đang đánh của tài khoản ở máy này ("" = không có)
var peer_id: int = -1
var heroes: Array[StringName] = []     ## tướng máy chủ cho chọn
var room: Dictionary = {}              ## trạng thái phòng mới nhất ({} = chưa ở phòng)
var config: MatchConfig
var entity_id: int = -1                ## đơn vị mình điều khiển trong trận
var slot: int = -1
var lockstep: LockstepClient
var _token: String = ""
var _version: String = ""
var _app: String = ""


## `t` = kênh đã mở / đang mở (WsTransport.dial(url) hoặc LoopbackNet trong test).
## `app` = số bản game (NET-12: máy chủ ghi vào biên bản trận).
func _init(t: NetTransport, token: String, version: String, app: String = "") -> void:
	transport = t
	_token = token
	_version = version
	_app = app


## Gọi mỗi khung khi chưa vào trận. Trả các tin cho menu (hello_ok, lobby, error, welcome, closed).
func poll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stage == "connecting" and transport.is_open():
		transport.send({"t": "hello", "v": _version, "token": _token, "app": _app})
		stage = "hello"
	elif stage == "connecting" and transport.has_method("closed") and transport.call("closed"):
		stage = "closed"  # không nối được (mạng / máy chủ tắt)
		return [{"t": "closed"}] as Array[Dictionary]
	for msg: Dictionary in transport.receive():
		if lockstep != null:
			lockstep.handle(msg)  # gói lệnh đến cùng đợt với lời chào
			continue
		if _take(msg):
			out.append(msg)
	if stage != "closed" and stage != "connecting" and not transport.is_open():
		stage = "closed"
		out.append({"t": "closed"})
	return out


func _take(msg: Dictionary) -> bool:
	match String(msg.get("t", "")):
		"hello_ok":
			stage = "lobby"
			peer_id = int(msg.get("peer", -1))
			name = String(msg.get("name", ""))
			live = String(msg.get("live", ""))
			heroes.clear()
			for h: Variant in msg.get("heroes", []):
				heroes.append(StringName(String(h)))
		"lobby":
			room = msg.get("room", {})
		"welcome":
			config = NetCodec.config_from(msg.get("config", {}))
			entity_id = int(msg.get("entity", -1))
			slot = int(msg.get("slot", -1))
			lockstep = LockstepClient.new(transport)
			lockstep.input_delay = int(msg.get("delay", 3))
			lockstep.peer_id = int(msg.get("peer", peer_id))
			if msg.get("resume", false) == true:  # NET-22: vào lại — tua tới tick hiện tại của máy chủ
				lockstep.resume_to = int(msg.get("tick", 0))
			stage = "game"
		"error", "end":
			pass
		_:
			return false
	return true


func send(msg: Dictionary) -> void:
	transport.send(msg)


func close() -> void:
	transport.close()
	stage = "closed"


func host() -> bool:
	return int(room.get("host", -2)) == peer_id


## Thành viên phòng của mình ({} nếu chưa ở phòng).
func me() -> Dictionary:
	for m: Dictionary in room.get("members", []):
		if int(m.get("id", -1)) == peer_id:
			return m
	return {}


## Câu tiếng Việt cho mã lỗi của máy chủ phòng.
static func error_text(code: String) -> String:
	return {"VERSION": "Khác phiên bản với máy chủ — cập nhật game", "AUTH": "Phiên đăng nhập hết hạn — đăng nhập lại",
		"NO_NAME": "Cần đặt tên trong game trước (Tài khoản)", "NO_ROOM": "Không có phòng này", "FULL": "Phòng đã đủ người",
		"STARTED": "Phòng đã vào trận", "ALREADY": "Tài khoản này đã ở trong phòng", "TEAM_FULL": "Đội đó đã đủ người",
		"HERO_TAKEN": "Tướng đã có người chọn", "UNKNOWN_HERO": "Tướng không hợp lệ", "NOT_HOST": "Chỉ chủ phòng làm được",
		"NOT_READY": "Còn người chưa chọn tướng", "BAD_SIZE": "Không đổi được số người (đang có người ở đội)",
		"IN_ROOM": "Đang ở trong phòng", "BUSY": "Máy chủ đang bận — thử lại sau",
		"IN_MATCH": "Bạn còn trận đang đánh — bấm Vào lại trận"}.get(code, "Lỗi " + code)
