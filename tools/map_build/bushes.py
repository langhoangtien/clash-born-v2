"""Bụi cỏ nửa Blue (VIS-06, D-72) trên lối đi của map đã thiết kế (plateau_design.py)."""
import json, math, os
import numpy as np
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
BUSHES = 7  # bụi cỏ mỗi nửa (D-72: 14 bụi cả map)
RX, RY = 15, 8  # bán trục bụi (ô guide; D-179: 240 × 128, to hơn 176 × 96)
WOB = 1.25      # build_map làm mép bụi gợn, bán kính tới WOB × bán trục


def place(src, out):
    """VIS-06 / D-72: đặt BUSHES bụi nửa Blue trên lối rừng — đủ rộng, ngoài tầm trụ, xa trại / lane,
    trải đều (chọn điểm xa nhau nhất); bụi nằm dọc theo hướng lối đi. `out`: mountains, forest (vật cản
    nửa Blue), base0, river, camps (vị trí trại nửa Blue)."""
    fx0, fy0, fx1, fy1 = src["frame"]
    rot = lambda q: (fx0 + fx1 - q[0], fy0 + fy1 - q[1])
    solid = [Polygon(p).buffer(0) for p in out["mountains"] + out["forest"]]
    solid += [Polygon([rot(q) for q in p]).buffer(0) for p in out["mountains"] + out["forest"]]
    base = Polygon(out["base0"]).buffer(0)
    walk = box(fx0, fy0, fx1, fy1).difference(unary_union(solid + [base, Polygon([rot(q) for q in out["base0"]]).buffer(0)]))
    water = unary_union([Polygon(p).buffer(0) for p in out["river"]])
    built = json.load(open(os.path.join(HERE, "..", "..", "data", "maps", "clashborn_map.json")))
    sc = src["scale"]
    towers = [Point(t["pos"][0] / sc + fx0, t["pos"][1] / sc + fy0) for t in built["towers"]]
    lanes = unary_union([LineString(l) for l in src["lanes"].values()] + [LineString([rot(q) for q in l]) for l in src["lanes"].values()])
    camps = [Point(c) for c in out["camps"]]
    cand = []
    for x in range(int(fx0), int(fx1), 2):
        for y in range(int(fy0), int(fy1), 2):
            q = Point(x, y)
            if y < x + 6 or not fx0 + 60 < x < fx1 - 60 or not fy0 + 60 < y < fy1 - 60 or not walk.contains(q.buffer(RY * WOB)) or water.distance(q) < 6 or lanes.distance(q) < RX:
                continue
            if min(t.distance(q) for t in towers) < 550 / sc + RX * WOB or min(c.distance(q) for c in camps) < 36:  # xa trại: không che lối kéo quái (D-76)
                continue
            cand.append(q)
    pick = [min(cand, key=lambda q: q.distance(Point(fx0 + 0.5 * (fx1 - fx0), fy0 + 0.73 * (fy1 - fy0))))]
    while len(pick) < BUSHES:
        far = lambda q: min(min(q.distance(p), q.distance(Point(rot((p.x, p.y))))) for p in pick)
        pick.append(max(cand, key=far))
    out_b = []
    for q in pick:
        near = [c for c in cand if c.distance(q) < RX + 3] or [q]
        xs = np.array([[c.x - q.x, c.y - q.y] for c in near])
        ang = 0.0
        if len(xs) > 2:
            w, v = np.linalg.eigh(xs.T @ xs)
            ang = math.degrees(math.atan2(v[1, 1], v[0, 1]))
        out_b.append({"pos": [q.x, q.y], "rx": RX, "ry": RY, "angle": round(ang)})
    return out_b
