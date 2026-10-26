"""Ổ quái và rào của map v3.1 (D-169), toạ độ guide.

Ổ quái (MAP-08) có hai kiểu, khai báo ở từng trại (`alcove.style`):
  ring   vòng đá một mảnh (mô hình Tripo có lối vào): vật cản là cung tròn khớp đúng mô hình —
         bán kính / độ dày / góc hở lấy từ số đo mô hình (`ring`), xoay cho lối vào nhìn về `open`
  trees  vòng cây: cung rừng dày `tree_width`, hở `tree_gap` độ về `open`
Rào đá (vẽ khối tường + cột): quanh base, chỉ hở chỗ 3 lane đi qua (MAP-09); quanh vùng hồi máu
fountain, một cổng hướng về nhà chính (MAP-10)."""
import math
from shapely.geometry import Polygon, Point
import geometry as G


def camp_alcoves(src, sym, scale):
    """→ (vật cản vòng đá [(line, width)], vòng đá để vẽ [dict], polygon vòng cây [Polygon],
    vòng tròn trước cửa ổ phải trống [(tâm, bán kính)])."""
    ring = src["ring"]
    world = ring["scale"] * 100.0 / scale  # mô hình (m) → ô guide: 1 m = 100 thế giới
    lines, rings, trees, doors = [], [], [], []
    for c in src["camps"]:
        a = c.get("alcove")
        if a is None:
            continue
        spots = [(c["pos"], a["open"])]
        if c["side"] == 0:
            spots.append((sym.rot(c["pos"]), a["open"] + 180))
        for pos, open_deg in spots:
            reach = (ring["r"] + ring["width"]) * world if a["style"] == "ring" else src["tree_alcove"]["r"] + src["tree_alcove"]["width"]
            t = math.radians(open_deg)
            doors.append(((pos[0] + math.cos(t) * reach, pos[1] + math.sin(t) * reach), src["door_clear"]))
            if a["style"] == "ring":
                lines.append((G.arc_line(pos, ring["r"] * world, open_deg, ring["gap"]), ring["width"] * world))
                rings.append({"pos": pos, "open": open_deg, "model": a.get("model", 0)})
            else:
                arc = G.arc_line(pos, src["tree_alcove"]["r"], open_deg, src["tree_alcove"]["gap"])
                trees.append(arc.buffer(src["tree_alcove"]["width"] / 2, **G.ROUND))
    return lines, rings, trees, doors


def fences(src, s, frame):
    """Rào base (mép base lùi vào) và rào fountain (cung quanh fountain, cổng về phía nhà chính)."""
    f = src["fence"]
    out = []
    for b in s["bases"]:
        out += [(l, f["width"]) for l in G.base_fence(Polygon(b["polygon"]), frame, f["base_inset"])]
    for team, p in enumerate(s["fountains"]):
        core = s["cores"][team]
        toward = math.degrees(math.atan2(core[1] - p[1], core[0] - p[0]))
        arc = G.arc_line(p, f["fountain_r"], toward, f["fountain_gate"], n=16).intersection(frame.buffer(-f["width"]))
        out += [(G.to_frame(l, frame, f["width"] + 1.0), f["width"]) for l in G.lines_of(arc)]
    return out
