class_name LoopbackNet
extends RefCounted
## D-337 (NET, test): mạng giả trong tiến trình có đồng hồ ảo `now` (giây) — mỗi đường nối có RTT, dao động, mất gói
## kiểu TCP (đến đúng thứ tự; gói mất thì đến muộn thêm một vòng RTT, như gửi lại). RNG riêng theo seed → chạy lại ra
## đúng trận mạng đó. Tin nhắn đi qua JSON như dây thật.

var now: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


## Hai đầu của một đường nối: [đầu máy khách, đầu máy chủ].
func link(rtt_ms: float, jitter_ms: float, loss: float) -> Array[End]:
	var a: End = End.new(self, rtt_ms / 2000.0, jitter_ms / 1000.0, loss)
	var b: End = End.new(self, rtt_ms / 2000.0, jitter_ms / 1000.0, loss)
	a.peer = b
	b.peer = a
	return [a, b]


class End:
	extends NetTransport
	var net: LoopbackNet
	var peer: End
	var one_way: float
	var jitter: float
	var loss: float
	var open: bool = true
	var _inbox: Array = []          ## [[giờ đến, chuỗi JSON]] theo thứ tự đến
	var _last_arrival: float = 0.0  ## TCP: không đến trước tin gửi trước

	func _init(n: LoopbackNet, w: float, j: float, l: float) -> void:
		net = n
		one_way = w
		jitter = j
		loss = l

	func send(msg: Dictionary) -> void:
		if not open or not peer.open:
			return
		var at: float = net.now + one_way + net.rng.randf() * jitter
		if net.rng.randf() < loss:
			at += one_way * 2.0  # gửi lại sau một vòng
		peer._last_arrival = maxf(at, peer._last_arrival)
		peer._inbox.append([peer._last_arrival, JSON.stringify(msg)])

	func receive() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		while not _inbox.is_empty() and _inbox[0][0] <= net.now:
			var d: Variant = JSON.parse_string(_inbox.pop_front()[1])
			if d is Dictionary:
				out.append(d)
		return out

	func is_open() -> bool:
		return open and peer.open

	func close() -> void:
		open = false
		_inbox.clear()
