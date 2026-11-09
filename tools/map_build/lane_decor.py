"""D-312: ven lane tự nhiên như ảnh mẫu người chơi (art_inbox/08_style/ref/lane_ref.png): dọc hai mép đất lane, phía cỏ,
rải cụm cỏ / khóm dương xỉ xanh / đá nhỏ thưa, khoảng cách lệch ngẫu nhiên — mép đường không còn là đường cong trơn.
Dùng bởi decor.py. Toạ độ thế giới px (100 px = 1 m)."""
import math
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

EDGE_OUT = 35.0          # mép đất lane = lane_width / 2 + EDGE_OUT (decor.py vẽ đất lane rộng lane_width + 2·EDGE_OUT)
STEP = (110.0, 260.0)    # khoảng cách giữa hai cụm dọc mép (px)
KINDS = [("grass_tuft", 0.5), ("plant_green", 0.3), ("rock_small", 0.2)]  # (mô hình, tỉ lệ)
CLEAR_STRUCT = 260.0     # không đặt sát trụ (sân lát D-310)


def edges(items, m, forest, wet, rng):
    lw = m["lane_width"]
    block = unary_union(list(forest) + [wet.buffer(80)] + [Polygon(b["polygon"]) for b in m["bases"]])
    block = unary_union([block] + [Point(t["pos"]).buffer(CLEAR_STRUCT) for t in m["towers"]])
    lanes = unary_union([LineString(p).buffer(lw / 2 + 20) for p in m["lanes"].values()])
    for pts in m["lanes"].values():
        line = LineString(pts)
        for side in (-1, 1):
            edge = line.parallel_offset(lw / 2 + EDGE_OUT, "left" if side < 0 else "right", join_style=2)
            for g in getattr(edge, "geoms", [edge]):
                _walk(items, g, block, lanes, rng)


def _walk(items, edge, block, lanes, rng):
    d = rng.uniform(0, STEP[1])
    while d < edge.length:
        p = edge.interpolate(d)
        q = Point(p.x + rng.uniform(-35, 35), p.y + rng.uniform(-35, 35))
        if not block.contains(q) and not lanes.contains(q):
            kind = _pick(rng)
            items.append([kind, q.x, q.y, rng.uniform(0, math.tau), rng.uniform(0.7, 1.05)])
            if kind == "grass_tuft" and rng.random() < 0.5:  # cụm đôi cho dày mép
                items.append(["grass_tuft", q.x + rng.uniform(-40, 40), q.y + rng.uniform(-40, 40), rng.uniform(0, math.tau), rng.uniform(0.6, 0.9)])
        d += rng.uniform(*STEP)


def _pick(rng):
    r = rng.random()
    for kind, share in KINDS:
        if r < share:
            return kind
        r -= share
    return KINDS[0][0]
