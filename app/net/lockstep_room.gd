class_name LockstepRoom
extends RefCounted
## D-337 (NET-01..04): lõi một phòng ở máy chủ — không phụ thuộc kiểu kết nối (máy chủ thật M9.5 bọc WebSocket quanh nó;
## test dùng LoopbackNet). Máy chủ giữ nhịp: `step_tick` mỗi 1/30 giây theo đồng hồ của máy chủ, không chờ ai; lệnh
## nhận được xếp vào tick thực thi = max(tick mong muốn, tick hiện tại + 1); mỗi tick phát gói lệnh rồi chạy bản SIM của
## máy chủ (so mã băm, sau này cho vào lại trận). Chỉ nhận lệnh cho đơn vị người gửi điều khiển (NET-03).

const MAX_COMMANDS_PER_S: int = 30
const HASH_KEEP: int = 40          ## số mốc mã băm giữ lại để so (40 × 30 tick = 40 giây)

var world: World
var tick: int = 0
var input_delay: int = 3
var peers: Dictionary[int, NetTransport] = {}
## Mã người chơi → đơn vị điều khiển.
var seats: Dictionary[int, int] = {}
var dropped: int = 0               ## lệnh bị bỏ (sai quyền / sai dạng / quá nhiều)
## Mã người chơi → tick lệch đầu tiên (NET-04).
var desyncs: Dictionary[int, int] = {}
var _pending: Dictionary[int, Array] = {}
var _hashes: Dictionary[int, String] = {}
var _rate: Dictionary[int, Array] = {}  ## mã → [giây đang đếm, số lệnh]


func _init(w: World, delay: int = 3) -> void:
	world = w
	input_delay = delay


func add_peer(id: int, t: NetTransport, entity_id: int) -> void:
	peers[id] = t
	seats[id] = entity_id


func remove_peer(id: int) -> void:
	peers.erase(id)


## Đọc tin của mọi người chơi (gọi mỗi vòng của máy chủ).
func pump() -> void:
	for id: int in peers.keys():
		for msg: Dictionary in peers[id].receive():
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
		"ping":
			peers[id].send({"t": "pong", "at": msg.get("at", 0.0)})


## NET-02 / NET-03: kiểm quyền + dạng + nhịp, rồi xếp vào tick thực thi.
func _command(id: int, msg: Dictionary) -> void:
	var c: Command = NetCodec.command_from(msg.get("c"))
	if c == null or c.entity_id != seats.get(id, -1) or not _allow(id):
		dropped += 1
		return
	var want: Variant = msg.get("want")
	var at: int = maxi(int(want) if want is int or want is float else 0, tick + 1)
	if not _pending.has(at):
		_pending[at] = []
	_pending[at].append({"c": NetCodec.command_to(c), "p": id, "s": int(msg.get("s", -1)) if msg.get("s") is float or msg.get("s") is int else -1})


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
	tick += 1
	# Qua JSON như máy khách nhận (số thực làm tròn giống hệt) → bản SIM của máy chủ áp đúng lệnh mọi máy áp.
	var bundle: Array = JSON.parse_string(JSON.stringify(_pending.get(tick, [])))
	_pending.erase(tick)
	for id: int in peers:
		peers[id].send({"t": "tick", "n": tick, "c": bundle})
	for entry: Dictionary in bundle:
		world.enqueue(NetCodec.command_from(entry["c"]))
	world.step()
	if tick % LockstepClient.HASH_EVERY == 0:
		_hashes[tick] = world.state_hash().hex_encode()
		_hashes.erase(tick - HASH_KEEP * LockstepClient.HASH_EVERY)
