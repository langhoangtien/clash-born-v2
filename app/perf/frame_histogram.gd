class_name FrameHistogram
extends RefCounted
## D-268: phân bố thời gian TỪNG khung trong cả trận (không lấy mẫu thưa) → FPS trung bình / thấp nhất,
## 1% low, phân vị, % khung vượt ngưỡng. Ô BIN_MS; khung dài hơn bảng giữ nguyên giá trị (hiếm). Bộ nhớ cố định.

## Hằng số kỹ thuật: cỡ ô (ms) và số ô (bảng phủ 0–200 ms).
const BIN_MS: float = 0.25
const BINS: int = 800

var count: int = 0
var sum_ms: float = 0.0
var max_ms: float = 0.0
var _bins: PackedInt32Array = PackedInt32Array()
## Khung ≥ BINS × BIN_MS: giữ giá trị thật.
var _over: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	_bins.resize(BINS)


func add(ms: float) -> void:
	count += 1
	sum_ms += ms
	max_ms = maxf(max_ms, ms)
	var i: int = floori(ms / BIN_MS)
	if i >= BINS:
		_over.append(ms)
	else:
		_bins[maxi(i, 0)] += 1


func avg_fps() -> float:
	return count * 1000.0 / sum_ms if sum_ms > 0.0 else 0.0


func min_fps() -> float:
	return 1000.0 / max_ms if max_ms > 0.0 else 0.0


## Thời gian khung tại phân vị `p` (0..1), ms (mép trên của ô).
func percentile(p: float) -> float:
	if count == 0:
		return 0.0
	var rank: int = clampi(ceili(p * count), 1, count)
	var seen: int = 0
	for i: int in BINS:
		seen += _bins[i]
		if seen >= rank:
			return (i + 1) * BIN_MS
	var over: PackedFloat32Array = _over.duplicate()
	over.sort()
	return over[clampi(rank - seen - 1, 0, over.size() - 1)]


## Tỉ lệ khung dài hơn `ms` (theo ô: ô có mép dưới ≥ ms).
func share_over(ms: float) -> float:
	if count == 0:
		return 0.0
	var n: int = 0
	for v: float in _over:
		if v > ms:
			n += 1
	for i: int in range(mini(ceili(ms / BIN_MS), BINS), BINS):
		n += _bins[i]
	return float(n) / count


## "Low" FPS: 1000 / thời gian trung bình của tỉ lệ `share` khung chậm nhất (1% low: share = 0,01).
func low_fps(share: float) -> float:
	if count == 0:
		return 0.0
	var want: int = maxi(1, ceili(share * count))
	var took: int = 0
	var total: float = 0.0
	var over: PackedFloat32Array = _over.duplicate()
	over.sort()
	for k: int in range(over.size() - 1, -1, -1):
		if took < want:
			total += over[k]
			took += 1
	var i: int = BINS - 1
	while took < want and i >= 0:
		var n: int = mini(_bins[i], want - took)
		total += n * (i + 0.5) * BIN_MS
		took += n
		i -= 1
	return 1000.0 / (total / took) if total > 0.0 else 0.0
