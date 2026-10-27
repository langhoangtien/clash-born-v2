"""Rào của map (D-169), toạ độ guide. Rào đá (vẽ khối tường + cột): quanh base, chỉ hở chỗ 3 lane đi qua (MAP-09); quanh vùng hồi máu
fountain, một cổng hướng về nhà chính (MAP-10)."""
import math
from shapely.geometry import Polygon
import geometry as G


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
