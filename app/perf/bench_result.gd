class_name BenchResult
extends RefCounted
## D-272: kết quả Benchmark A/B — mỗi đoạn một phân bố thời gian khung + tổng µs theo phần; so mỗi phần tắt với
## trung bình hai mốc "đủ đồ họa" kề nó (A/B/A) để bớt nhiễu do máy nóng / cảnh đổi.

const COLUMNS: PackedStringArray = ["label", "frames", "frame_ms", "p95_ms", "over_16_7", "gpu_ms", "render_ms",
	"process_ms", "sim_ms", "hud_ms"]

## Mỗi đoạn: {step, hist, us: Dictionary[StringName, int]}.
var segments: Array[Dictionary] = []


func begin(step: Dictionary) -> void:
	segments.append({"step": step, "hist": FrameHistogram.new(), "us": {}})


## Một khung (µs theo phần như FrameProfile) vào đoạn hiện tại.
func add(frame: Dictionary) -> void:
	if segments.is_empty():
		return
	var seg: Dictionary = segments[-1]
	var ms: float = frame.get(&"frame", 0) / 1000.0
	if ms <= 0.0:
		return
	(seg["hist"] as FrameHistogram).add(ms)
	var us: Dictionary = seg["us"]
	for key: StringName in [&"gpu", &"render", &"process", &"sim", &"hud"]:
		us[key] = us.get(key, 0) + frame.get(key, 0)


func row(seg: Dictionary) -> Dictionary:
	var h: FrameHistogram = seg["hist"]
	var n: int = maxi(1, h.count)
	var us: Dictionary = seg["us"]
	var out: Dictionary = {"label": seg["step"]["label"], "frames": h.count,
		"frame_ms": snappedf(h.sum_ms / n, 0.01), "p95_ms": h.percentile(0.95), "over_16_7": snappedf(h.share_over(16.7), 0.001)}
	for key: StringName in [&"gpu", &"render", &"process", &"sim", &"hud"]:
		out[String(key) + "_ms"] = snappedf(us.get(key, 0) / 1000.0 / n, 0.01)
	if us.get(&"gpu", 0) <= 0:
		out["gpu_ms"] = "N/A"
	return out


func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seg: Dictionary in segments:
		if not seg["step"].get("settle", false):
			out.append(row(seg))
	return out


## Mỗi phần tắt: chênh lệch so với trung bình hai mốc đủ đồ họa kề (thiếu một bên thì dùng bên còn lại).
func compare() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in segments.size():
		var step: Dictionary = segments[i]["step"]
		if not step.has("key") or step.get("sim", false):
			continue
		var bases: Array[Dictionary] = []
		for j: int in [i - 1, i + 1]:
			if j >= 0 and j < segments.size() and segments[j]["step"].get("base", false):
				bases.append(row(segments[j]))
		if bases.is_empty():
			continue
		var me: Dictionary = row(segments[i])
		var c: Dictionary = {"label": step["label"], "key": String(step["key"])}
		for col: String in ["frame_ms", "gpu_ms", "over_16_7"]:
			c[col.replace("_ms", "") + "_delta" + ("_ms" if col.ends_with("_ms") else "")] = _delta(me, bases, col)
		out.append(c)
	return out


static func _delta(me: Dictionary, bases: Array[Dictionary], col: String) -> Variant:
	if not (me[col] is float or me[col] is int):
		return "N/A"
	var total: float = 0.0
	for b: Dictionary in bases:
		if not (b[col] is float or b[col] is int):
			return "N/A"
		total += float(b[col])
	return snappedf(float(me[col]) - total / bases.size(), 0.01 if col.ends_with("_ms") else 0.001)


## Bảng chữ ngắn để dán chat.
func text(meta: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray([
		"Benchmark A/B · Clashborn %s · %s · %s · %s" % [meta.get("version", "?"), meta.get("device", "?"),
			meta.get("gpu", "?"), meta.get("resolution", "?")],
		"Cảnh: %s" % meta.get("scene", "?"),
	])
	var base: Array[Dictionary] = rows().filter(func(r: Dictionary) -> bool: return r["label"] == "Đủ đồ họa")
	if not base.is_empty():
		out.append("Mốc đủ đồ họa (đoạn đầu): khung %s ms · GPU %s ms · khung > 16,7 ms %s%%" % [base[0]["frame_ms"],
			base[0]["gpu_ms"], snappedf(float(base[0]["over_16_7"]) * 100.0, 0.1)])
	out.append("Tắt từng phần (so với mốc kề, âm = nhẹ đi):")
	for c: Dictionary in compare():
		var share: Variant = c["over_16_7_delta"]
		out.append("  %s: GPU %s ms · khung %s ms · khung > 16,7 ms %s điểm %%" % [c["label"], _signed(c["gpu_delta_ms"]),
			_signed(c["frame_delta_ms"]), _signed(snappedf(float(share) * 100.0, 0.1) if share is float else share)])
	for r: Dictionary in rows():
		if r["label"].begins_with("SIM"):
			out.append("SIM chạy: khung %s ms · P95 %s · GPU %s · xử lý %s · SIM %s · HUD %s ms" % [r["frame_ms"],
				r["p95_ms"], r["gpu_ms"], r["process_ms"], r["sim_ms"], r["hud_ms"]])
	return "\n".join(out)


static func _signed(v: Variant) -> String:
	return ("+" if float(v) > 0.0 else "") + str(v) if (v is float or v is int) else str(v)


func csv() -> String:
	var lines: PackedStringArray = PackedStringArray([",".join(COLUMNS)])
	for r: Dictionary in rows():
		var cells: PackedStringArray = PackedStringArray()
		for col: String in COLUMNS:
			cells.append(str(r[col]))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


func json(meta: Dictionary) -> String:
	return JSON.stringify({"meta": meta, "segments": rows(), "compare": compare()}, "\t")
