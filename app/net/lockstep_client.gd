class_name LockstepClient
extends RefCounted
## D-337 (NET-01, NET-02, NET-04): máy khách lockstep — lệnh người chơi (World.remote_sink) gửi lên máy chủ kèm tick
## mong muốn; World chỉ chạy tick T khi đã có gói lệnh T của máy chủ (`ready_to_step` / `feed`); mỗi HASH_EVERY tick gửi
## mã băm. Đo: RTT, trễ bấm → hiệu lực, số khung chờ mạng, hàng gói chờ, lệch. Không đụng SIM ngoài remote_sink / enqueue.

const HASH_EVERY: int = 30
const PING_EVERY_S: float = 1.0
const MAX_STEPS_PER_FRAME: int = 5
## Hàng gói chờ quá chừng này (máy tụt lại) → chạy bù không chờ nhịp.
const CATCH_UP_BACKLOG: int = 6

var world: World
var transport: NetTransport
var input_delay: int = 3
## Mã của máy này trong phòng (máy chủ báo lúc chào) — nhận ra lệnh của mình trong gói (đo trễ).
var peer_id: int = -1
## Tick mới nhất đã có gói lệnh.
var last_tick: int = 0
var _bundles: Dictionary[int, Array] = {}
var _seq: int = 0
var _sent_at: Dictionary[int, float] = {}
var _ping_in: float = 0.0
var clock: float = 0.0           ## giây (APP / test đặt — thời gian thật hoặc đồng hồ ảo)

# Số đo (D-337 mục 9)
var rtt_ms: float = 0.0
var jitter_ms: float = 0.0
var input_latency_ms: float = 0.0
var stalls: int = 0               ## số khung tới hạn chạy tick mà hết sạch gói (đứng hình vì mạng)
var holds: int = 0                ## số khung chờ cho đầy đệm (chậm lại chút, chưa đứng hình)
## Đệm gói giữ lại (tick) để dao động mạng không làm đứng hình: tự chỉnh theo dao động đo được (1–6).
var buffer_target: int = 1
var _acc: float = 0.0             ## thời gian đã trôi chưa chạy thành tick
var max_backlog: int = 0
var desync_tick: int = -1         ## tick lệch đầu tiên máy chủ báo (-1 = chưa)
var hashes: Dictionary[int, String] = {}  ## mã băm đã gửi (chẩn đoán)
## NET-22 (M9.8): đang tua tới tick này sau khi vào lại (-1 = không tua); thời gian chạy SIM tối đa mỗi khung khi tua.
var resume_to: int = -1
var catch_up_ms: float = 24.0
## NET-16 (D-402): tin `notice` của máy chủ (người rớt…) chờ HUD hiện.
var notices: Array[Dictionary] = []
## NET-24 (D-409): máy chủ đã báo `end` (trận có đội thắng, không còn gói tick mới) → chạy hết gói đã nhận, bỏ đệm.
var ended: bool = false
## M9.6: APP móc vào trước / sau mỗi tick (màn trận: chụp vị trí nội suy, gửi lệnh đang giữ; âm thanh).
var on_before: Callable = Callable()
var on_after: Callable = Callable()


func _init(t: NetTransport) -> void:
	transport = t


## Gắn World đã dựng theo cấu hình máy chủ gửi; lệnh người chơi từ nay đi qua mạng.
func attach(w: World, delay: int, peer: int) -> void:
	world = w
	input_delay = delay
	peer_id = peer
	w.remote_sink = _send_command


func _send_command(c: Command) -> void:
	if not transport.is_open():
		return
	_seq += 1
	_sent_at[_seq] = clock
	transport.send({"t": "cmd", "want": last_tick + input_delay, "s": _seq, "c": NetCodec.command_to(c)})


## Nhận tin (gọi mỗi khung). Trả các tin không phải của lockstep (vd sảnh) cho APP xử lý.
func pump(now: float) -> Array[Dictionary]:
	var dt: float = now - clock
	clock = now
	var other: Array[Dictionary] = []
	for msg: Dictionary in transport.receive():
		if not handle(msg):
			other.append(msg)
	_ping_in -= dt
	if _ping_in <= 0.0 and transport.is_open():
		_ping_in = PING_EVERY_S
		transport.send({"t": "ping", "at": clock})
	if world != null:
		max_backlog = maxi(max_backlog, last_tick - world.tick)
	return other


## Một tin của lockstep (gói lệnh, pong, báo lệch); false = không phải (APP xử lý). APP gọi thẳng cho các tin đến cùng đợt
## với lời chào (trước khi có LockstepClient).
func handle(msg: Dictionary) -> bool:
	match String(msg.get("t", "")):
		"tick":
			var n: int = int(msg.get("n", 0))
			_bundles[n] = msg.get("c", [])
			last_tick = maxi(last_tick, n)
		"pong":
			var r: float = (clock - float(msg.get("at", clock))) * 1000.0
			jitter_ms = lerpf(jitter_ms, absf(r - rtt_ms), 0.2) if rtt_ms > 0.0 else 0.0
			rtt_ms = r if rtt_ms == 0.0 else lerpf(rtt_ms, r, 0.2)
		"desync":
			if desync_tick < 0:
				desync_tick = int(msg.get("n", -1))
		"notice":
			notices.append(msg)
		"end":  # NET-24
			ended = true
		"history":  # NET-22: gói tick from..to (không liệt kê = rỗng)
			var listed: Dictionary = {}
			for e: Variant in msg.get("c", []):
				if e is Array and (e as Array).size() == 2:
					listed[int(e[0])] = e[1]
			var done_tick: int = world.tick if world != null else 0
			for t: int in range(maxi(int(msg.get("from", 1)), done_tick + 1), int(msg.get("to", 0)) + 1):
				if not _bundles.has(t):
					_bundles[t] = listed.get(t, [])
			last_tick = maxi(last_tick, int(msg.get("to", 0)))
		_:
			return false
	return true


func ready_to_step() -> bool:
	return world != null and world.winner < 0 and _bundles.has(world.tick + 1)


## Nhịp chạy mỗi khung (APP / test): 30 tick / giây theo thời gian trôi, chỉ khi đã có gói (NET-01), giữ `buffer_target`
## gói làm đệm chống dao động; hết sạch gói lúc tới hạn → một khung đứng hình (stalls); tụt sau máy chủ nhiều → chạy bù.
## NET-24: máy chủ đã báo `end` → không còn gói mới để chờ, chạy ngay mọi gói đã có (tới tick thắng).
func advance(dt: float) -> int:
	if resume_to >= 0:
		return _fast_forward()
	_acc += dt
	buffer_target = clampi(ceili(jitter_ms / (SimClock.TICK_SECONDS * 1000.0)) + 1, 1, 6)
	var n: int = 0
	while n < MAX_STEPS_PER_FRAME and ready_to_step() and (ended or
			(_acc >= SimClock.TICK_SECONDS and backlog() >= buffer_target) or backlog() > buffer_target + CATCH_UP_BACKLOG):
		step()
		_acc = maxf(0.0, _acc - SimClock.TICK_SECONDS)
		n += 1
	if _acc >= SimClock.TICK_SECONDS and transport.is_open() and not ended:
		if not ready_to_step():
			stalls += 1
		else:
			holds += 1
		_acc = minf(_acc, SimClock.TICK_SECONDS * 2.0)  # không dồn: đệm đầy lại thì chạy đều tiếp
	return n


## Đưa gói lệnh của tick kế vào World rồi chạy tick đó (NET-01); gửi mã băm định kỳ (NET-04).
func step() -> void:
	if on_before.is_valid():
		on_before.call()
	var bundle: Array = _bundles[world.tick + 1]
	_bundles.erase(world.tick + 1)
	for entry: Variant in bundle:
		var c: Command = NetCodec.command_from(entry.get("c") if entry is Dictionary else null)
		if c == null:
			continue
		world.enqueue(c)
		var s: int = int(entry.get("s", -1))
		if int(entry.get("p", -2)) == peer_id and _sent_at.has(s):
			input_latency_ms = lerpf(input_latency_ms, (clock - _sent_at[s]) * 1000.0, 0.2) if input_latency_ms > 0.0 \
				else (clock - _sent_at[s]) * 1000.0
			_sent_at.erase(s)
	world.step()
	if on_after.is_valid():
		on_after.call()
	if world.tick % HASH_EVERY == 0:
		hashes[world.tick] = world.state_hash().hex_encode()
		transport.send({"t": "hash", "n": world.tick, "h": hashes[world.tick]})


## Số gói đã đến mà chưa chạy.
func backlog() -> int:
	return last_tick - (world.tick if world != null else 0)


## Phần đã trôi của tick kế (0..1) — VIEW nội suy.
func phase() -> float:
	return clampf(_acc / SimClock.TICK_SECONDS, 0.0, 0.999)


## NET-22: tua — chạy tick có gói tới hết `catch_up_ms` mỗi khung (không chờ nhịp); tới tick vào lại và hàng gói ngắn lại
## thì báo máy chủ `caught_up` (NET-18).
func _fast_forward() -> int:
	var start: int = Time.get_ticks_usec()
	var n: int = 0
	while ready_to_step() and (Time.get_ticks_usec() - start) < catch_up_ms * 1000.0:
		step()
		n += 1
	if world != null and world.tick >= resume_to and backlog() <= buffer_target + 2:
		resume_to = -1
		_acc = 0.0
		transport.send({"t": "caught_up"})
	return n
