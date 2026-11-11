class_name OnlineMatch
extends Label
## M9.6 (D-344): phần online của màn trận — nối World với LockstepClient của phiên (lệnh người chơi đi qua máy chủ, tick
## chạy theo gói lệnh NET-01), dòng trạng thái mạng trên HUD (RTT, chờ mạng, mất kết nối, lệch), thêm khóa trận vào biên
## bản (NET-12), rời trận thì đóng kết nối. Màn trận chỉ gọi `attach` / `tag` / `leave`.

const STALL_SHOW_S: float = 0.5   ## đứng chờ gói lâu chừng này mới báo "chờ mạng"

var session: OnlineSession
var _last_tick: int = -1
var _waiting: float = 0.0


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
	m.position = Vector2(24, 300)
	return m


func _process(delta: float) -> void:
	var lock: LockstepClient = session.lockstep
	if lock.world == null:
		return
	_waiting = 0.0 if lock.world.tick != _last_tick else _waiting + delta
	_last_tick = lock.world.tick
	text = status(lock, session.transport.is_open(), _waiting)
	add_theme_color_override("font_color", Color(1, 0.55, 0.45) if text.contains("—") else Color(0.75, 0.9, 1.0, 0.8))


## Chữ trạng thái (cũng dùng trong test).
static func status(lock: LockstepClient, open: bool, waiting_s: float) -> String:
	if lock.world != null and lock.world.winner >= 0:
		return ""
	if not open:
		return "Online — mất kết nối máy chủ (Esc / Cài đặt → Thoát để về menu)"
	if lock.desync_tick >= 0:
		return "Online %d ms — lệch trận ở tick %d (báo lỗi giúp)" % [roundi(lock.rtt_ms), lock.desync_tick]
	if waiting_s >= STALL_SHOW_S:
		return "Online %d ms — đang chờ mạng…" % roundi(lock.rtt_ms)
	if lock.input_latency_ms > 0.0:  # D-345: bấm → có hiệu lực (gồm RTT + đệm), để người chơi / mình biết trễ ở đâu
		return "Online %d ms · bấm %d ms" % [roundi(lock.rtt_ms), roundi(lock.input_latency_ms)]
	return "Online %d ms" % roundi(lock.rtt_ms)


## NET-12 (D-344): biên bản trận online — khóa trận (mã phòng + seed) để máy chủ gộp các máy gửi, ô của mình.
static func tag(record: Dictionary, s: OnlineSession) -> Dictionary:
	record["match_key"] = s.match_key()
	record["you"] = s.slot
	return record


## Rời trận / màn trận đóng: ngắt kết nối (M9.7: bot đánh thay người rời).
static func leave(s: OnlineSession) -> void:
	if s != null:
		s.close()
