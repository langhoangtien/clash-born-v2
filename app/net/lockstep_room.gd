class_name LockstepRoom
extends RefCounted
## D-337 (NET-01..04): lõi một phòng ở máy chủ — không phụ thuộc kiểu kết nối (máy chủ thật M9.5 bọc WebSocket quanh nó;
## test dùng LoopbackNet). Máy chủ giữ nhịp: `step_tick` mỗi 1/30 giây theo đồng hồ của máy chủ, không chờ ai; lệnh
## nhận được xếp vào tick thực thi = max(tick mong muốn, tick hiện tại + 1); mỗi tick phát gói lệnh rồi chạy bản SIM của
## máy chủ (so mã băm, sau này cho vào lại trận). Chỉ nhận lệnh cho đơn vị người gửi điều khiển (NET-03).
## M9.7 (D-402): người rớt (đóng kết nối / im lặng DROP_AFTER_S giây / lệch mã băm — NET-16, NET-20) → bỏ khỏi `peers`, giữ ô
## trong `gone`, chèn lệnh đổi quyền điều khiển (`takeover`) vào gói lệnh tick kế (NET-17), báo `on_drop`.

const MAX_COMMANDS_PER_S: int = 30
const HASH_KEEP: int = 40          ## số mốc mã băm giữ lại để so (40 × 30 tick = 40 giây)
const DROP_AFTER_S: int = 5        ## NET-16: im lặng chừng này giây = rớt (máy khách ping mỗi giây)
## NET-17: lệnh chỉ máy chủ phát — máy khách gửi lên thì bỏ (NET-03).
const SERVER_ONLY: Array[Command.Type] = [Command.Type.SET_CONTROL]
const BACKFILL_BUFFER: int = 32 * 1024  ## NET-22: chỉ gửi thêm phần nhật ký khi hàng gửi của kết nối dưới chừng này byte

var world: World
var tick: int = 0
var input_delay: int = 3
var peers: Dictionary[int, NetTransport] = {}
## Mã người chơi → đơn vị điều khiển.
var seats: Dictionary[int, int] = {}
var dropped: int = 0               ## lệnh bị bỏ (sai quyền / sai dạng / quá nhiều)
## Mã người chơi → tick lệch đầu tiên (NET-04).
var desyncs: Dictionary[int, int] = {}
## Người đã rớt: mã → tick rớt (ô giữ lại để vào lại — M9.8).
var gone: Dictionary[int, int] = {}
## NET-16: func(peer: int, entity: int, reason: String) — "closed" / "silent" / "desync".
var on_drop: Callable = Callable()
## NET-17: func(entity: int, bot: bool) -> Command — lệnh đổi quyền điều khiển máy chủ chèn vào gói lệnh (null = không chèn).
var takeover: Callable = Callable()
## NET-22 (M9.8): nhật ký gói lệnh khác rỗng [[tick, gói]] để người vào lại tua; số gói khác rỗng mỗi phần gửi lại.
var log: Array = []
var history_chunk: int = 100
## NET-18: người vào lại chưa đuổi kịp (lệnh của họ bị bỏ, bot vẫn đánh); `on_return`: func(peer) khi đã kịp.
var returning: Dictionary[int, bool] = {}
var on_return: Callable = Callable()
var _backfill: Dictionary[int, Array] = {}  ## mã → [chỉ số log kế, tick đầu phần kế, tick cuối T]
var _heard: Dictionary[int, int] = {}  ## mã → tick máy chủ nhận tin gần nhất (NET-16)
var _pending: Dictionary[int, Array] = {}
var _hashes: Dictionary[int, String] = {}
var _rate: Dictionary[int, Array] = {}  ## mã → [giây đang đếm, số lệnh]


func _init(w: World, delay: int = 3) -> void:
	world = w
	input_delay = delay


func add_peer(id: int, t: NetTransport, entity_id: int) -> void:
	peers[id] = t
	seats[id] = entity_id
	_heard[id] = tick
	gone.erase(id)


## NET-16: người rớt — thôi gửi / đọc, giữ ô, chèn lệnh đổi quyền vào tick kế (NET-17). Gọi lại lần nữa thì bỏ qua.
func drop_peer(id: int, reason: String) -> void:
	if not peers.has(id):
		return
	peers.erase(id)
	returning.erase(id)
	_backfill.erase(id)
	gone[id] = tick
	var c: Command = takeover.call(seats[id], true) if takeover.is_valid() and seats.has(id) else null
	if c != null:
		_queue(tick + 1, {"c": NetCodec.command_to(c), "p": -1, "s": -1})
	if on_drop.is_valid():
		on_drop.call(id, seats.get(id, -1), reason)


## NET-22: người vào lại (kết nối mới) — gửi lại gói tick 1..tick hiện tại theo từng phần, gói trực tiếp từ tick kế.
func rejoin_peer(id: int, t: NetTransport, entity_id: int) -> void:
	add_peer(id, t, entity_id)
	returning[id] = true
	_backfill[id] = [0, 1, tick]  # gửi từ tick kế — sau lời chào `welcome` (gửi trước thì máy khách chưa có lockstep, bỏ mất)


## Đọc tin của mọi người chơi (gọi mỗi vòng của máy chủ).
func pump() -> void:
	for id: int in peers.keys():
		for msg: Dictionary in peers[id].receive():
			if not peers.has(id):
				break  # vừa rớt (lệch) giữa đợt tin
			_heard[id] = tick
			_handle(id, msg)


func _handle(id: int, msg: Dictionary) -> void:
	match String(msg.get("t", "")):
		"cmd":
			_command(id, msg)
		"hash":
			var n: int = int(msg.get("n", -1))
			if _hashes.has(n) and String(msg.get("h", "")) != _hashes[n] and not desyncs.has(id):
				desyncs[id] = n
				peers[id].send({"t": "desync", "n": n})
				drop_peer(id, "desync")  # NET-20
		"ping":
			peers[id].send({"t": "pong", "at": msg.get("at", 0.0)})
		"caught_up":  # NET-18: đã tua kịp → trả hero cho người ở tick kế
			if returning.erase(id):
				var c: Command = takeover.call(seats[id], false) if takeover.is_valid() else null
				if c != null:
					_queue(tick + 1, {"c": NetCodec.command_to(c), "p": -1, "s": -1})
				if on_return.is_valid():
					on_return.call(id)


## NET-02 / NET-03: kiểm quyền + dạng + nhịp, rồi xếp vào tick thực thi.
func _command(id: int, msg: Dictionary) -> void:
	var c: Command = NetCodec.command_from(msg.get("c"))
	if c == null or c.entity_id != seats.get(id, -1) or c.type in SERVER_ONLY or returning.has(id) or not _allow(id):
		dropped += 1
		return
	var want: Variant = msg.get("want")
	var at: int = maxi(int(want) if want is int or want is float else 0, tick + 1)
	_queue(at, {"c": NetCodec.command_to(c), "p": id, "s": int(msg.get("s", -1)) if msg.get("s") is float or msg.get("s") is int else -1})


func _queue(at: int, entry: Dictionary) -> void:
	if not _pending.has(at):
		_pending[at] = []
	_pending[at].append(entry)


func _allow(id: int) -> bool:
	var second: int = tick / SimClock.TICKS_PER_SECOND
	var r: Array = _rate.get(id, [second, 0])
	if int(r[0]) != second:
		r = [second, 0]
	r[1] = int(r[1]) + 1
	_rate[id] = r
	return int(r[1]) <= MAX_COMMANDS_PER_S


## NET-01: một tick của máy chủ — phát gói lệnh tick mới cho mọi người, rồi chạy bản SIM của máy chủ với đúng gói đó.
func step_tick() -> void:
	for id: int in peers.keys():
		if tick - _heard[id] > DROP_AFTER_S * SimClock.TICKS_PER_SECOND:
			drop_peer(id, "silent")  # NET-16
	tick += 1
	# Qua JSON như máy khách nhận (số thực làm tròn giống hệt) → bản SIM của máy chủ áp đúng lệnh mọi máy áp.
	var bundle: Array = JSON.parse_string(JSON.stringify(_pending.get(tick, [])))
	_pending.erase(tick)
	for id: int in peers:
		peers[id].send({"t": "tick", "n": tick, "c": bundle})
	if not bundle.is_empty():
		log.append([tick, bundle])
	_send_backfill()
	for entry: Dictionary in bundle:
		world.enqueue(NetCodec.command_from(entry["c"]))
	world.step()
	if tick % LockstepClient.HASH_EVERY == 0:
		_hashes[tick] = world.state_hash().hex_encode()
		_hashes.erase(tick - HASH_KEEP * LockstepClient.HASH_EVERY)


## NET-24: trận kết thúc — gửi nốt nhật ký cho người đang vào lại trước tin `end` (máy chủ ngừng chạy tick sau đó).
func flush_backfill() -> void:
	_send_backfill(true)


## NET-22: gửi tiếp nhật ký cho người vào lại khi hàng gửi còn chỗ: {history, from, to, c: [[tick, gói]…]} — tick trong
## from..to không có trong c là gói rỗng. `force`: gửi hết bất kể hàng gửi (NET-24 — trận kết thúc).
func _send_backfill(force: bool = false) -> void:
	for id: int in _backfill.keys():
		var b: Array = _backfill[id]
		while int(b[1]) <= int(b[2]) and (force or peers[id].buffered() < BACKFILL_BUFFER):
			var part: Array = []
			var i: int = b[0]
			while i < log.size() and int(log[i][0]) <= int(b[2]) and part.size() < history_chunk:
				part.append(log[i])
				i += 1
			var more: bool = i < log.size() and int(log[i][0]) <= int(b[2])
			var to: int = int(part[-1][0]) if more else int(b[2])
			peers[id].send({"t": "history", "from": b[1], "to": to, "c": part})
			b[0] = i
			b[1] = to + 1
		if int(b[1]) > int(b[2]):
			_backfill.erase(id)
