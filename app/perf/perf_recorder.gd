class_name PerfRecorder
extends RefCounted
## D-268: bộ ghi hiệu năng một trận. Mỗi khung nhận µs theo phần (FrameProfile) → phân bố thời gian khung
## (FrameHistogram, mọi khung), cộng dồn; mỗi SAMPLE_USEC ghi một dòng (trung bình mẫu + bối cảnh trận);
## khung dài hơn SPIKE_MS ghi riêng kèm bối cảnh. Chỉ giữ trong RAM; PerfReport định dạng, PerfFiles ghi file.
## Không đụng World: bối cảnh lấy qua `context` (APP cung cấp).

const SAMPLE_USEC: int = 500_000
## Khung giật: dài hơn 2 nhịp màn hình 60 Hz.
const SPIKE_MS: float = 1000.0 / 30.0
## Hằng số kỹ thuật: số lần giật giữ chi tiết (bộ nhớ cố định); vẫn đếm hết ở `spike_total`.
const SPIKE_CAP: int = 100
## D-269: giật lớn (đứng hình thấy rõ) có chỗ riêng, không bị giật nhỏ (lỡ một nhịp màn hình) chiếm hết.
const BIG_SPIKE_MS: float = 50.0
const BIG_SPIKE_CAP: int = 200
## Phần con trong "màn trận" (để tính phần còn lại).
const SCENE_PARTS: Array[StringName] = [&"sim", &"ground", &"actors", &"shots", &"events", &"corpses"]
## Phần đo (khóa FrameProfile, µs) → cột ms.
const SECTIONS: Dictionary[StringName, String] = {
	&"process": "process_ms", &"sim": "sim_ms", &"hud": "hud_ms", &"render": "render_ms", &"gpu": "gpu_ms",
}
## Cột lấy từ `context()` (thiếu → N/A).
const CONTEXT_KEYS: Array[StringName] = [&"draw_calls", &"triangles_k", &"nodes", &"objects", &"mem_static_mb",
	&"video_mem_mb", &"entities", &"heroes", &"lane_creeps", &"jungle", &"fighting_heroes", &"actors",
	&"projectiles", &"vfx"]
const COLUMNS: PackedStringArray = ["time_s", "match_time", "tick", "fps", "frame_avg_ms", "frame_max_ms",
	"process_ms", "sim_ms", "hud_ms", "bones_ms", "render_ms", "gpu_ms", "draw_calls", "triangles_k", "nodes",
	"objects", "mem_static_mb", "video_mem_mb", "entities", "heroes", "lane_creeps", "jungle", "fighting_heroes",
	"actors", "projectiles", "vfx", "graphics_off", "diag_open", "diag_ms", "sim_first_ms", "sim_second_ms"]
## D-277: phần chỉ có ở một số khung (nửa tick) — trung bình trên các khung có chạy, không chia đều mọi khung.
const SOMETIMES: Array[StringName] = [&"sim_first", &"sim_second"]

## Thông tin máy / bản / cài đặt (APP đặt), ghi vào JSON.
var meta: Dictionary = {}
## () -> Dictionary[StringName, Variant]: bối cảnh lúc ghi dòng / lúc giật (tick, số đơn vị, bộ nhớ…).
var context: Callable = func() -> Dictionary: return {}
var hist: FrameHistogram = FrameHistogram.new()
var rows: Array[PackedStringArray] = []
var spikes: Array[Dictionary] = []
var spike_total: int = 0
var big_spikes: Array[Dictionary] = []
var big_total: int = 0
## Mốc bật / tắt đồ họa: {t, key, value}.
var markers: Array[Dictionary] = []
## Có khung nào GPU > 0 (máy đo được GPU).
var gpu_seen: bool = false
## Cộng dồn cả trận (µs theo phần) để tóm tắt.
var total_us: Dictionary[StringName, int] = {}
var total_frames: int = 0

var _start: int = 0
var _sample_start: int = 0
var _n: int = 0
var _frame_sum: float = 0.0
var _frame_max: float = 0.0
var _sum: Dictionary[StringName, int] = {}
var _ran: Dictionary[StringName, int] = {}
var _off: PackedStringArray = PackedStringArray()


func start(at_usec: int) -> void:
	_start = at_usec
	_sample_start = at_usec


func seconds(at_usec: int) -> float:
	return (at_usec - _start) / 1_000_000.0


## Một khung xong: `frame` = µs theo phần (khóa FrameProfile, có &"frame" = cả khung).
func on_frame(frame: Dictionary, at_usec: int) -> void:
	var ms: float = frame.get(&"frame", 0) / 1000.0
	if ms <= 0.0:
		return
	hist.add(ms)
	total_frames += 1
	_n += 1
	_frame_sum += ms
	_frame_max = maxf(_frame_max, ms)
	for key: StringName in [&"process", &"sim", &"hud", &"draw2d", &"render", &"gpu", &"hud_diag"]:
		var us: int = frame.get(key, 0)
		_sum[key] = _sum.get(key, 0) + us
		total_us[key] = total_us.get(key, 0) + us
	if frame.get(&"gpu", 0) > 0:
		gpu_seen = true
	for key: StringName in SOMETIMES:
		if frame.get(key, 0) > 0:
			_sum[key] = _sum.get(key, 0) + frame[key]
			_ran[key] = _ran.get(key, 0) + 1
	if ms > SPIKE_MS:
		_spike(frame, ms, at_usec)
	if at_usec - _sample_start >= SAMPLE_USEC:
		_emit_row(at_usec)


func _spike(frame: Dictionary, ms: float, at_usec: int) -> void:
	var big: bool = ms > BIG_SPIKE_MS
	spike_total += 1
	big_total += 1 if big else 0
	var list: Array[Dictionary] = big_spikes if big else spikes
	if list.size() < (BIG_SPIKE_CAP if big else SPIKE_CAP):
		list.append({"t": snappedf(seconds(at_usec), 0.01), "frame_ms": snappedf(ms, 0.01),
			"sections": spike_parts(frame), "context": plain(context.call())})


## D-269: mọi phần đo được của một khung (ms), kể cả phần con và phần "còn lại" của từng nhóm.
static func spike_parts(frame: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in frame:
		if key != FrameProfile.FRAME:
			out[String(key) + "_ms"] = snappedf(frame[key] / 1000.0, 0.01)
	var scene: int = frame.get(&"scene", 0)
	var parts: int = 0
	for key: StringName in SCENE_PARTS:
		parts += frame.get(key, 0)
	out["scene_other_ms"] = snappedf(maxi(0, scene - parts) / 1000.0, 0.01)
	out["process_other_ms"] = snappedf(maxi(0, frame.get(&"process", 0) - scene) / 1000.0, 0.01)
	out["bones_ms"] = snappedf(maxi(0, frame.get(&"draw2d", 0) - frame.get(&"hud", 0)) / 1000.0, 0.01)
	if frame.get(&"gpu", 0) <= 0:
		out["gpu_ms"] = "N/A"
	return out


## Mốc bật / tắt một phần đồ họa (bảng chẩn đoán); dòng sau đó ghi các phần đang tắt.
func mark(key: StringName, value: int, at_usec: int) -> void:
	markers.append({"t": snappedf(seconds(at_usec), 0.01), "key": String(key), "value": value})
	var name: String = String(key)
	if value == 0 and not _off.has(name):
		_off.append(name)
	elif value != 0 and _off.has(name):
		_off.remove_at(_off.find(name))


## ms theo cột từ µs cộng dồn của `n` khung; "N/A" cho GPU khi máy không đo được.
func section_ms(us: Dictionary, n: int) -> Dictionary:
	var out: Dictionary = {}
	for key: StringName in SECTIONS:
		out[SECTIONS[key]] = snappedf(us.get(key, 0) / 1000.0 / n, 0.01)
	out["bones_ms"] = snappedf(maxf(0.0, us.get(&"draw2d", 0) - us.get(&"hud", 0)) / 1000.0 / n, 0.01)
	if us.get(&"gpu", 0) <= 0:
		out["gpu_ms"] = "N/A"
	return out


func _emit_row(at_usec: int) -> void:
	var dt: float = (at_usec - _sample_start) / 1_000_000.0
	var ctx: Dictionary = context.call()
	var v: Dictionary = section_ms(_sum, _n)
	v["time_s"] = snappedf(seconds(at_usec), 0.01)
	v["tick"] = ctx.get(&"tick", "N/A")
	v["match_time"] = MatchHud.clock_text(int(ctx[&"tick"])) if ctx.has(&"tick") else "N/A"
	v["fps"] = snappedf(_n / dt, 0.1)
	v["frame_avg_ms"] = snappedf(_frame_sum / _n, 0.01)
	v["frame_max_ms"] = snappedf(_frame_max, 0.01)
	for key: StringName in CONTEXT_KEYS:
		v[String(key)] = ctx.get(key, "N/A")
	v["graphics_off"] = ";".join(_off)
	v["diag_open"] = ctx.get(&"diag_open", "N/A")
	v["diag_ms"] = snappedf(_sum.get(&"hud_diag", 0) / 1000.0 / _n, 0.01)
	for key: StringName in SOMETIMES:
		v[String(key) + "_ms"] = snappedf(_sum.get(key, 0) / 1000.0 / _ran[key], 0.01) if _ran.get(key, 0) > 0 else "N/A"
	var row: PackedStringArray = PackedStringArray()
	for col: String in COLUMNS:
		row.append(str(v[col]))
	rows.append(row)
	_sample_start = at_usec
	_n = 0
	_frame_sum = 0.0
	_frame_max = 0.0
	_sum.clear()
	_ran.clear()


## Khóa StringName → String (để JSON / so sánh dùng tên thường).
static func plain(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d:
		out[String(k)] = d[k]
	return out


## Dòng thứ `i` dạng tên cột → giá trị (chuỗi).
func row_dict(i: int) -> Dictionary:
	var out: Dictionary = {}
	for k: int in COLUMNS.size():
		out[COLUMNS[k]] = rows[i][k]
	return out
