class_name FrameProfile
extends RefCounted
## D-261: đo thời gian CPU mỗi khung theo từng phần (SIM, đồng bộ nhân vật 3D, vẽ HUD…) để tìm chỗ
## nghẽn trên máy thật. Mỗi phần cộng µs trong khung; hết cửa sổ WINDOW_USEC thì công bố trung bình
## và đỉnh (ms / khung) vào `avg_ms` / `peak_ms`. Kèm bộ đếm (`counts`) cho thứ có thể tăng dần theo
## trận. Chỉ APP / VIEW dùng; không đụng World.

const WINDOW_USEC: int = 1_000_000
## Tên phần đặc biệt: khoảng cách giữa hai lần `next_frame` (cả khung, gồm vẽ và chờ).
const FRAME: StringName = &"frame"

## Bản dùng chung cho cả màn trận (bảng chẩn đoán đọc).
static var shared: FrameProfile = FrameProfile.new()

## Cửa sổ vừa xong: ms trung bình / ms lớn nhất mỗi khung theo phần.
var avg_ms: Dictionary[StringName, float] = {}
var peak_ms: Dictionary[StringName, float] = {}
## Số khung trong cửa sổ vừa xong.
var frames: int = 0
var counts: Dictionary[StringName, int] = {}
## D-268: (µs theo phần của khung vừa xong, thời điểm µs) — bộ ghi log hiệu năng nghe; rỗng = không ai nghe.
var frame_listener: Callable = Callable()

var _frame: Dictionary[StringName, int] = {}
var _sum: Dictionary[StringName, int] = {}
var _peak: Dictionary[StringName, int] = {}
var _frames: int = 0
var _window_start: int = -1
var _last_frame: int = -1


static func now() -> int:
	return Time.get_ticks_usec()


## Cộng thời gian từ `since` (µs, lấy bằng `now()`) tới `at` vào phần `key` của khung hiện tại.
func add(key: StringName, since: int, at: int = -1) -> void:
	var end: int = at if at >= 0 else now()
	_frame[key] = _frame.get(key, 0) + maxi(0, end - since)


## Như `add` tới bây giờ; trả về bây giờ để đo tiếp phần sau.
func lap(key: StringName, since: int) -> int:
	var t: int = now()
	add(key, since, t)
	return t


## D-263: thời gian `_draw` của một bảng HUD — cộng vào phần riêng `key` và tổng "hud".
func hud(key: StringName, since: int, at: int = -1) -> void:
	var end: int = at if at >= 0 else now()
	add(key, since, end)
	add(&"hud", since, end)


func set_count(key: StringName, value: int) -> void:
	counts[key] = value


## Gọi một lần đầu mỗi khung: gộp khung trước vào cửa sổ, hết cửa sổ thì công bố.
func next_frame(at: int = -1) -> void:
	var t: int = at if at >= 0 else now()
	if _last_frame >= 0:
		_frame[FRAME] = t - _last_frame
		for key: StringName in _frame:
			_sum[key] = _sum.get(key, 0) + _frame[key]
			_peak[key] = maxi(_peak.get(key, 0), _frame[key])
		_frames += 1
		if frame_listener.is_valid():
			frame_listener.call(_frame, t)
	_frame.clear()
	_last_frame = t
	if _window_start < 0:
		_window_start = t
	if t - _window_start >= WINDOW_USEC and _frames > 0:
		_publish()
		_window_start = t


func _publish() -> void:
	avg_ms.clear()
	peak_ms.clear()
	for key: StringName in _sum:
		avg_ms[key] = _sum[key] / 1000.0 / _frames
		peak_ms[key] = _peak[key] / 1000.0
	frames = _frames
	_sum.clear()
	_peak.clear()
	_frames = 0


## Các phần (trừ FRAME) xếp theo ms trung bình giảm dần.
func sections_by_cost() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in avg_ms:
		if key != FRAME:
			keys.append(key)
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return avg_ms[a] > avg_ms[b])
	return keys
