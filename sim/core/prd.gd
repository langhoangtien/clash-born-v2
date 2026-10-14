class_name Prd
extends RefCounted
## RNG-01: giả ngẫu nhiên kiểu Dota. Lần thử thứ n kể từ lần trúng trước có xác suất
## min(1, C × n); trúng thì về 1. C chọn sao cho tỉ lệ trúng trung bình đúng bằng p.
## Bộ đếm theo khóa (đơn vị + nguồn) nằm trong World.prd_counters (thuộc trạng thái trận).

static var _constants: Dictionary[float, float] = {}


## Tung với xác suất danh nghĩa `p` cho khóa `key`; số ngẫu nhiên lấy từ world.rng (RNG-02).
static func roll(world: World, key: int, p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		world.prd_counters.erase(key)
		return true
	var n: int = world.prd_counters.get(key, 0) + 1
	if world.rng.randf() < minf(1.0, constant(p) * n):
		world.prd_counters.erase(key)
		return true
	world.prd_counters[key] = n
	return false


## Khóa bộ đếm từ id đơn vị và mã nguồn (số thứ tự hiệu ứng × 16 + chỉ số trigger, hoặc hằng).
static func key(unit_id: int, source: int) -> int:
	return unit_id * 1000003 + source


## C(p) bằng chia đôi: tỉ lệ trúng trung bình của C là 1 / E[số lần thử tới khi trúng].
static func constant(p: float) -> float:
	var rounded: float = snappedf(p, 0.0001)
	if _constants.has(rounded):
		return _constants[rounded]
	var lo: float = 0.0
	var hi: float = rounded
	for i: int in range(60):
		var mid: float = (lo + hi) * 0.5
		if _rate(mid) < rounded:
			lo = mid
		else:
			hi = mid
	_constants[rounded] = (lo + hi) * 0.5
	return _constants[rounded]


static func _rate(c: float) -> float:
	var expected: float = 0.0
	var not_yet: float = 1.0
	var n: int = 1
	while not_yet > 1e-12:
		var hit: float = minf(1.0, c * n)
		expected += n * not_yet * hit
		not_yet *= 1.0 - hit
		n += 1
	return 1.0 / expected
