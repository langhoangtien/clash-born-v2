class_name BenchPlan
extends RefCounted
## D-272: kịch bản Benchmark A/B cố định. Cảnh dừng SIM (chỉ đo vẽ): ổn định → mốc đủ đồ họa → mỗi phần tắt
## một mình, kẹp giữa hai mốc đủ (A/B/A) → độ phân giải 75 % / 50 % → cuối cùng SIM chạy để đo CPU.

## Giây: chờ ổn định đầu, mỗi đoạn đo, đoạn SIM chạy; bỏ phần đầu mỗi đoạn (đổi cài đặt xong số mới ổn).
const SETTLE: float = 3.0
const SEGMENT: float = 4.0
const SIM_SECONDS: float = 15.0
const WARM: float = 0.75
## Phần đồ họa (khóa bảng chẩn đoán) và tên hiện.
const PARTS: Array[StringName] = [&"fog", &"ground", &"scenery", &"actors", &"water", &"layer", &"vfx"]
const NAMES: Dictionary[StringName, String] = {&"fog": "Sương", &"ground": "Nền ảnh", &"scenery": "Cảnh vật",
	&"actors": "Nhân vật", &"water": "Nước", &"layer": "Lớp phủ", &"vfx": "Hiệu ứng"}
const SCALES: Array[int] = [75, 50]


## Mỗi bước: label, seconds, sim (SIM chạy), base (mốc đủ), settle, off (phần tắt), scale (%), key (phần đo).
static func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_step("Ổn định", SETTLE, {"settle": true}), _base()]
	for p: StringName in PARTS:
		out.append(_step("Tắt " + NAMES[p], SEGMENT, {"key": p, "off": [p]}))
		out.append(_base())
	for sc: int in SCALES:
		out.append(_step("Độ phân giải %d%%" % sc, SEGMENT, {"key": StringName("scale_%d" % sc), "scale": sc}))
		out.append(_base())
	out.append(_step("SIM chạy (chia tick)", SIM_SECONDS, {"sim": true}))
	out.append(_step("SIM chạy (không chia tick)", SIM_SECONDS, {"sim": true, "split": false}))  # D-276: so hai chế độ
	return out


static func _base() -> Dictionary:
	return _step("Đủ đồ họa", SEGMENT, {"base": true})


static func _step(label: String, seconds: float, extra: Dictionary) -> Dictionary:
	var s: Dictionary = {"label": label, "seconds": seconds, "sim": false, "base": false, "settle": false, "off": [], "scale": 100}
	s.merge(extra, true)
	return s


static func total_seconds() -> float:
	var t: float = 0.0
	for s: Dictionary in steps():
		t += float(s["seconds"])
	return t


## Bước đang chạy ở giây `t` tính từ lúc bắt đầu đo; -1 = đã hết.
static func index_at(t: float) -> int:
	var acc: float = 0.0
	var list: Array[Dictionary] = steps()
	for i: int in list.size():
		acc += float(list[i]["seconds"])
		if t < acc:
			return i
	return -1
