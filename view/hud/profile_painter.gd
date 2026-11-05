class_name ProfilePainter
extends RefCounted
## D-261: chữ của bảng đo thời gian từng phần (mở cùng bảng chẩn đoán D-179). Mỗi dòng: tên phần, ms trung
## bình / khung, ms khung nặng nhất trong 1 giây vừa qua. "khác" = phần cha trừ các phần con đã đo riêng.

const LABELS: Dictionary[StringName, String] = {
	&"process": "Xử lý (_process)", &"scene": "  Màn trận", &"sim": "    SIM",
	&"ground": "    Đất + lớp phủ", &"actors": "    Nhân vật 3D", &"events": "    Đạn + sự kiện",
	&"corpses": "    Gỡ hình + xác", &"scene_other": "    Màn trận khác", &"process_other": "  _process khác",
	&"draw2d": "Vẽ 2D (HUD _draw)", &"render": "Dựng khung 3D (CPU)", &"gpu": "GPU",
}
## Thứ tự hiện (cây cha – con).
const ORDER: Array[StringName] = [&"process", &"scene", &"sim", &"ground", &"actors", &"events", &"corpses",
	&"scene_other", &"process_other", &"draw2d", &"render", &"gpu"]
const SCENE_PARTS: Array[StringName] = [&"sim", &"ground", &"actors", &"events", &"corpses"]


## [nhãn, ms trung bình, ms đỉnh] theo ORDER; phần chưa đo thì bỏ.
static func rows(p: FrameProfile) -> Array[Array]:
	var avg: Dictionary[StringName, float] = p.avg_ms.duplicate()
	var peak: Dictionary[StringName, float] = p.peak_ms.duplicate()
	if avg.has(&"scene"):
		avg[&"scene_other"] = maxf(0.0, avg[&"scene"] - _sum(avg, SCENE_PARTS))
		avg[&"process_other"] = maxf(0.0, avg.get(&"process", 0.0) - avg[&"scene"])
	var out: Array[Array] = []
	for key: StringName in ORDER:
		if avg.has(key):
			out.append([LABELS[key], avg[key], peak.get(key, -1.0)])
	return out


static func _sum(d: Dictionary[StringName, float], keys: Array[StringName]) -> float:
	var s: float = 0.0
	for k: StringName in keys:
		s += d.get(k, 0.0)
	return s


## Dòng đầu: cả khung; hai dòng cuối: bộ đếm.
static func header(p: FrameProfile) -> String:
	return "Khung %.1f ms (đỉnh %.1f) · %d khung/s" % [p.avg_ms.get(FrameProfile.FRAME, 0.0),
		p.peak_ms.get(FrameProfile.FRAME, 0.0), p.frames]


static func count_lines(p: FrameProfile) -> PackedStringArray:
	var c: Dictionary[StringName, int] = p.counts
	return PackedStringArray([
		"Đơn vị %d · hình 3D %d · xác %d · đạn %d · hiệu ứng %d" % [c.get(&"entities", 0), c.get(&"actors", 0),
			c.get(&"corpses", 0), c.get(&"projectiles", 0), c.get(&"vfx", 0)],
		"Node %d (mồ côi %d) · object %d · %d lệnh vẽ · %dk tam giác" % [c.get(&"nodes", 0), c.get(&"orphans", 0),
			c.get(&"objects", 0), c.get(&"draw_calls", 0), c.get(&"triangles_k", 0)],
	])


## Vẽ vào `ci` trong khung `box`.
static func draw(ci: CanvasItem, box: Rect2, p: FrameProfile) -> void:
	UiStyle.panel(ci, box, 12)
	var at: Vector2 = box.position + Vector2(18, 36)
	ci.draw_string(UiStyle.sans(true), at, header(p), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 18, UiStyle.TEXT)
	for r: Array in rows(p):
		at.y += 26
		ci.draw_string(UiStyle.sans(false), at, r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.TEXT)
		var nums: String = "%5.2f  /  %5.1f" % [r[1], r[2]]
		ci.draw_string(UiStyle.sans(false), Vector2(box.end.x - 170, at.y), nums, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.TEXT)
	for line: String in count_lines(p):
		at.y += 28
		ci.draw_string(UiStyle.sans(false), at, line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 30, 16, UiStyle.TEXT)
