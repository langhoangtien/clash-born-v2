class_name PerfReport
extends RefCounted
## D-268: định dạng kết quả PerfRecorder — tóm tắt (dict / chữ ngắn để dán chat), CSV (theo lô), JSON đầy đủ.

## Ngưỡng thời gian khung (ms): 60 / 55 / 50 / 45 fps và giật (2 nhịp 60 Hz).
const THRESHOLDS: Array[float] = [16.7, 18.2, 20.0, 22.2, 33.3]


static func summary(r: PerfRecorder) -> Dictionary:
	var h: FrameHistogram = r.hist
	var s: Dictionary = {
		"frames": h.count, "duration_s": snappedf(h.sum_ms / 1000.0, 0.1),
		"avg_fps": snappedf(h.avg_fps(), 0.1), "min_fps": snappedf(h.min_fps(), 0.1),
		"low_1pct_fps": snappedf(h.low_fps(0.01), 0.1), "low_0_1pct_fps": snappedf(h.low_fps(0.001), 0.1),
		"p50_frame_ms": h.percentile(0.5), "p95_frame_ms": h.percentile(0.95), "p99_frame_ms": h.percentile(0.99),
		"spikes": r.spike_total, "big_spikes": r.big_total,
	}
	for ms: float in THRESHOLDS:
		s["share_over_" + str(ms).replace(".", "_")] = snappedf(h.share_over(ms), 0.0001)
	s.merge(r.section_ms(r.total_us, maxi(1, r.total_frames)))
	s["objects_per_min"] = _growth(r, "objects")
	s["mem_static_mb_per_min"] = _growth(r, "mem_static_mb")
	s.merge(_drift(r))
	return s


## Mức tăng mỗi phút của cột `col` (dòng đầu → dòng cuối); N/A nếu thiếu.
static func _growth(r: PerfRecorder, col: String) -> Variant:
	if r.rows.size() < 2:
		return "N/A"
	var a: Dictionary = r.row_dict(0)
	var b: Dictionary = r.row_dict(r.rows.size() - 1)
	var minutes: float = (float(b["time_s"]) - float(a["time_s"])) / 60.0
	if minutes <= 0.0 or not String(a[col]).is_valid_float() or not String(b[col]).is_valid_float():
		return "N/A"
	return snappedf((float(b[col]) - float(a[col])) / minutes, 0.1)


## Máy nóng / chậm dần: ms khung và số đơn vị trung bình 10 % thời gian đầu so với 10 % cuối.
static func _drift(r: PerfRecorder) -> Dictionary:
	var n: int = r.rows.size()
	if n < 10:
		return {}
	var k: int = maxi(1, n / 10)
	return {"frame_ms_first10": _avg(r, "frame_avg_ms", 0, k), "frame_ms_last10": _avg(r, "frame_avg_ms", n - k, n),
		"entities_first10": _avg(r, "entities", 0, k), "entities_last10": _avg(r, "entities", n - k, n)}


static func _avg(r: PerfRecorder, col: String, from: int, to: int) -> Variant:
	var total: float = 0.0
	for i: int in range(from, to):
		var v: String = r.row_dict(i)[col]
		if not v.is_valid_float():
			return "N/A"
		total += float(v)
	return snappedf(total / (to - from), 0.01)


## CSV từ dòng `from` (ghi theo lô: lô sau không lặp tiêu đề).
static func csv(r: PerfRecorder, from: int, header: bool = true) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if header:
		lines.append(",".join(PerfRecorder.COLUMNS))
	for i: int in range(from, r.rows.size()):
		lines.append(",".join(r.rows[i]))
	return "\n".join(lines) + "\n"


static func json(r: PerfRecorder) -> String:
	return JSON.stringify(data(r), "\t")


## Nội dung JSON (dùng chung cho file và gửi lên máy chủ, D-287).
static func data(r: PerfRecorder) -> Dictionary:
	var rows: Array = []
	for row: PackedStringArray in r.rows:
		rows.append(Array(row))
	return {"meta": r.meta, "summary": summary(r), "markers": r.markers, "spikes": r.spikes,
		"big_spikes": r.big_spikes, "columns": Array(PerfRecorder.COLUMNS), "rows": rows}


## Vài chục dòng chữ để dán thẳng vào chat.
static func summary_text(r: PerfRecorder) -> String:
	var s: Dictionary = summary(r)
	var m: Dictionary = r.meta
	var out: PackedStringArray = PackedStringArray([
		"Clashborn %s · %s · %s" % [m.get("version", "?"), m.get("device", "?"), m.get("gpu", "?")],
		"Cài đặt: %s · %s" % [m.get("graphics", "?"), m.get("resolution", "?")],
		"Thời gian đo %.0f s · %d khung" % [s["duration_s"], s["frames"]],
		"FPS TB %.1f · thấp nhất %.1f · 1%% low %.1f · 0.1%% low %.1f" % [s["avg_fps"], s["min_fps"], s["low_1pct_fps"], s["low_0_1pct_fps"]],
		"Khung P50 %.2f · P95 %.2f · P99 %.2f ms" % [s["p50_frame_ms"], s["p95_frame_ms"], s["p99_frame_ms"]],
	])
	var over: PackedStringArray = PackedStringArray()
	for ms: float in THRESHOLDS:
		over.append(">%s ms: %.1f%%" % [str(ms), 100.0 * float(s["share_over_" + str(ms).replace(".", "_")])])
	out.append("Khung vượt ngưỡng: " + " · ".join(over))
	out.append("Giật > 33,3 ms: %d lần · trong đó > 50 ms (đứng hình): %d lần" % [s["spikes"], s["big_spikes"]])
	out.append("TB/khung: xử lý %s · SIM %s · HUD %s · xương %s · dựng 3D %s · GPU %s ms" % [s["process_ms"],
		s["sim_ms"], s["hud_ms"], s["bones_ms"], s["render_ms"], s["gpu_ms"]])
	out.append("Object +%s/phút · bộ nhớ +%s MB/phút" % [s["objects_per_min"], s["mem_static_mb_per_min"]])
	if s.has("frame_ms_first10"):
		out.append("10%% đầu: %s ms (%s đv) · 10%% cuối: %s ms (%s đv)" % [s["frame_ms_first10"],
			s["entities_first10"], s["frame_ms_last10"], s["entities_last10"]])
	out.append("Mốc bật/tắt đồ họa: %d" % r.markers.size())
	return "\n".join(out)
