"""Đặt trụ nửa Blue (D-168, MAP-04): trụ đứng sát mép lane, cùng một bên, cách tim lane đúng
`tower_offset` ô guide — thẳng hàng với đường. T1 lùi `tower_layout[lane]` (thế giới) từ điểm gặp
của lane (giữa lane); T2/T3 giữ khoảng cách dọc lane của `pos` trong nguồn (chiếu lên lane)."""
import math
from shapely.geometry import LineString, Point


def place(src, lanes):
    scale = src["scale"]
    layout = src["tower_layout"]
    out = []
    for t in src["towers"]:
        t = dict(t)
        if t["lane"] in lanes:
            line = LineString(lanes[t["lane"]])
            d = line.length / 2 - layout[t["lane"]] / scale if t["tier"] == 1 else line.project(Point(t["pos"]))
            t["pos"] = _beside(line, d, src["tower_offset"], src["tower_side"][t["lane"]])
        out.append(t)
    return out


def _beside(line, d, offset, side):
    """Điểm cách tim lane `offset`, bên phải (`right`) hay trái (`left`) theo chiều Blue → Red."""
    p = line.interpolate(d)
    q = line.interpolate(min(line.length, d + 1.0))
    tx, ty = q.x - p.x, q.y - p.y
    n = math.hypot(tx, ty) or 1.0
    sign = 1.0 if side == "right" else -1.0
    # y hướng xuống: pháp tuyến bên phải của (tx, ty) là (-ty, tx)
    return [round(p.x - ty / n * offset * sign, 2), round(p.y + tx / n * offset * sign, 2)]
