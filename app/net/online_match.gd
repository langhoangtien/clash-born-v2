class_name OnlineMatch
extends Label
## M9.6 (D-344): phần online của màn trận — nối World với LockstepClient của phiên (lệnh người chơi đi qua máy chủ, tick
## chạy theo gói lệnh NET-01), dòng trạng thái mạng trên HUD (RTT, chờ mạng, mất kết nối, lệch), rời trận thì đóng kết
## nối (biên bản trận online do máy chủ phòng ghi — NET-12). M9.7 (D-402): thông báo của máy chủ (người rớt — NET-16), máy chủ báo lệch thì
## tự gửi báo cáo lệch một lần (NET-20). Màn trận chỉ gọi `attach` / `leave`.

const STALL_SHOW_S: float = 0.5   ## đứng chờ gói lâu chừng này mới báo "chờ mạng"
const NOTICE_S: float = 5.0       ## thông báo (người rớt…) hiện chừng này giây

var session: OnlineSession
var _last_tick: int = -1
var _waiting: float = 0.0
var _notice: String = ""
var _notice_left: float = 0.0
var _report: String = ""          ## NET-20: "" = chưa gửi; "…" = đang gửi; còn lại = kết quả
var _upload: PerfUpload


## Gắn vào màn trận (sau khi dựng World + SimRunner).
static func attach(hud: Node, world: World, runner: SimRunner, s: OnlineSession) -> OnlineMatch:
	s.lockstep.attach(world, s.lockstep.input_delay, s.lockstep.peer_id)
	runner.lockstep = s.lockstep
	var m: OnlineMatch = OnlineMatch.new()
	m.name = "OnlineStatus"
	m.session = s
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_font_size_override("font_size", 20)
	m.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	m.add_theme_constant_override("outline_size", 4)
	hud.add_child(m)
	m._upload = PerfUpload.new()
	m.add_child(m._upload)
	m.position = Vector2(24, 300)
	return m


func _process(delta: float) -> void:
	var lock: LockstepClient = session.lockstep
	if lock.world == null:
		return
	_waiting = 0.0 if lock.world.tick != _last_tick else _waiting + delta
	_last_tick = lock.world.tick
	while not lock.notices.is_empty():
		_notice = notice_text(lock.notices.pop_front())
		_notice_left = NOTICE_S
	_notice_left -= delta
	if lock.desync_tick >= 0 and _report == "":
		_send_report(lock)
	text = status(lock, session.transport.is_open(), _waiting) + (" " + _report if lock.desync_tick >= 0 else "")
	if _notice_left > 0.0:
		text += "\n" + _notice
	add_theme_color_override("font_color", Color(1, 0.55, 0.45) if text.contains("—") else Color(0.75, 0.9, 1.0, 0.8))


## Chữ trạng thái (cũng dùng trong test).
static func status(lock: LockstepClient, open: bool, waiting_s: float) -> String:
	if lock.world != null and lock.world.winner >= 0:
		return ""
	if lock.resume_to >= 0 and lock.world != null:  # NET-22: đang tua sau khi vào lại
		return "Đang vào lại trận… %d%%" % clampi(lock.world.tick * 100 / maxi(1, lock.resume_to), 0, 99)
	if lock.desync_tick >= 0:  # NET-20: trước "mất kết nối" — máy chủ đóng kết nối máy lệch ngay sau đó
		return "Online — lệch trận ở tick %d" % lock.desync_tick
	if not open:
		return "Online — mất kết nối máy chủ (Esc / Cài đặt → Thoát để về menu)"
	if waiting_s >= STALL_SHOW_S:
		return "Online %d ms — đang chờ mạng…" % roundi(lock.rtt_ms)
	if lock.input_latency_ms > 0.0:  # D-345: bấm → có hiệu lực (gồm RTT + đệm), để người chơi / mình biết trễ ở đâu
		return "Online %d ms · bấm %d ms" % [roundi(lock.rtt_ms), roundi(lock.input_latency_ms)]
	return "Online %d ms" % roundi(lock.rtt_ms)


## NET-16: chữ cho một tin `notice` của máy chủ.
static func notice_text(n: Dictionary) -> String:
	match String(n.get("kind", "")):
		"dropped":
			return "%s mất kết nối — bot đánh thay" % n.get("name", "?")
		"back":
			return "%s đã vào lại" % n.get("name", "?")
	return String(n.get("name", ""))


## NET-20: gửi báo cáo lệch một lần (lỗi mạng thì thôi — vẫn còn dòng nhật ký ở máy chủ).
func _send_report(lock: LockstepClient) -> void:
	_report = "— đang gửi báo lỗi…"
	var r: Dictionary = DesyncReport.build(lock, String(session.room.get("code", "")))
	_upload.send(&"sync", "", r["summary"], r["data"], func(ok: bool, message: String) -> void:
		_report = "— đã báo lỗi (%s)" % message if ok else "— gửi báo lỗi không được")


## Rời trận / màn trận đóng: ngắt kết nối = rớt (NET-16) → bot đánh thay (NET-17).
static func leave(s: OnlineSession) -> void:
	if s != null:
		s.close()
