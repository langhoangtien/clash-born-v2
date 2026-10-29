#!/usr/bin/env python3
"""Thiết kế map kiểu bục rừng (đồ họa bước 2): vẽ MẠNG LỐI ĐI cho nửa Blue (lối chính, lối phụ, khe luồn,
bãi trại, chỗ xuống sông), bục rừng = phần đất rừng còn lại (bỏ mảnh vụn, mép vuông vức). Nửa Red xoay 180°.

  python3 tools/map_build/plateau_design.py [ảnh.png]
In số khối, bề rộng lối; vẽ ảnh xem trước (bục, lối, sông, lane, trụ, trại). Toạ độ ô guide (1 ô = 16 đơn vị).
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = json.load(open(os.path.join(HERE, "map_source.json")))
FX0, FY0, FX1, FY1 = SRC["frame"]
C = (FX0 + FX1) / 2
SLOPE = 0.747  # đường chia hai nửa dọc theo sông (from_sketch.RIVER_SLOPE)

MAIN, SIDE, GAP = 40.0, 30.0, 20.0  # bề rộng lối (ô guide): chính 640, phụ 480, khe luồn 320
# Trại nửa Blue (id → vị trí): 3 trại rừng trái (giữa lane trên, sông, mid), 3 trại rừng dưới; trại 6 sát lane
# dưới (kéo quái, D-76). Mỗi trại là hốc có 2 cửa, nằm cạnh (không nằm trên) lối chính.
CAMPS = {"camp_blue_01": (130, 380), "camp_blue_02": (222, 296), "camp_blue_03": (160, 420),
         "camp_blue_04": (340, 480), "camp_blue_05": (296, 516), "camp_blue_06": (488, 530)}
P = {
    "c1": CAMPS["camp_blue_01"], "c2": CAMPS["camp_blue_02"], "c3": CAMPS["camp_blue_03"],
    "c4": CAMPS["camp_blue_04"], "c5": CAMPS["camp_blue_05"], "c6": CAMPS["camp_blue_06"],
    "top_hi": (92, 196), "top_a": (92, 262), "top_c1": (92, 384),
    "j1": (186, 368), "mid_a": (252, 396), "mid_c3": (200, 448), "riv_head": (138, 214), "riv_c2": (256, 300),
    "mid_b": (306, 342), "j2": (360, 418), "j3": (424, 474), "bot_main": (420, 562),
    "riv_j2": (392, 404), "riv_j3": (468, 464), "bot_c5": (290, 562), "bot_c6": (540, 556),
    "mid_back": (196, 452), "bot_back": (222, 562),
}
PATHS = [
    # rừng trái
    (["top_a", "j1", "mid_a"], MAIN),           # lối chính: lane trên → giữa rừng → mid
    (["j1", "c1"], SIDE), (["c1", "top_c1"], GAP),      # trại 1: cửa từ lối chính + khe ra lane trên
    (["j1", "c2"], SIDE), (["c2", "riv_c2"], GAP),      # trại 2 (ven sông): cửa từ lối chính + khe xuống sông
    (["j1", "c3"], SIDE), (["c3", "mid_c3"], GAP),      # trại 3: cửa từ lối chính + khe ra mid
    (["top_hi", "riv_head"], SIDE),             # lane trên → đầu sông
    # rừng dưới
    (["mid_b", "j2", "j3", "bot_main"], MAIN),  # lối chính: mid → giữa rừng → lane dưới
    (["j2", "riv_j2"], SIDE), (["j3", "riv_j3"], SIDE),  # xuống sông
    (["j2", "c4"], SIDE), (["c4", "c5"], GAP),          # trại 4: cửa từ lối chính + khe sang trại 5
    (["bot_c5", "c5"], SIDE),                           # trại 5: cửa từ lane dưới
    (["j3", "c6"], SIDE), (["c6", "bot_c6"], GAP),      # trại 6: cửa từ lối chính + khe ra lane (kéo quái)
    (["mid_back", "bot_back"], GAP),            # sau trụ: mid → lane dưới (về base)
]
CAMP_R = {"large": 17.0, "medium": 16.0, "small": 15.0}  # bãi trại (MAP-08 dò ở 330 = 20,6 ô)
HOOK_W = 12.0       # bề dày vách quanh bãi trại (ô)
BANK = 5.0          # tường đá bờ sông dày (ô), hở ở chỗ lối chạm sông
MIN_BLOCK = 150.0   # mảnh bục nhỏ hơn (ô²) thì bỏ — thành đất trống
SIMPLIFY = 3.0      # mép vuông vức (ô)
ROUND = 2.5         # bo nhẹ góc nhọn
INSET = 3.0         # thu mép bục (ô) — chừa dải đất quanh tường đá


def rot(p):
    return (FX0 + FX1 - p[0], FY0 + FY1 - p[1])


def blue(p):
    return (p[1] - C) > SLOPE * (p[0] - C)


def half_region():
    """Nửa Blue (dưới đường chia dọc sông) trong khung."""
    far = 2000
    line = [(C - far, C - SLOPE * far), (C + far, C + SLOPE * far)]
    return Polygon(line + [(C + far, C + far * 3), (C - far, C + far * 3)]).intersection(box(FX0, FY0, FX1, FY1))


def lanes_all():
    out = []
    for pts in SRC["lanes"].values():
        out += [LineString(pts), LineString([rot(p) for p in pts])]
    return out


def playable(lanes):
    """Hộp trong mép ngoài các lane (lane + lề 4 ô) cộng hai base; ngoài là rìa map (rào + tường thành)."""
    m = SRC["lane_half_width"] + 4
    xs = [p[0] for l in lanes for p in l.coords]
    ys = [p[1] for l in lanes for p in l.coords]
    inner = box(min(xs) - m, min(ys) - m, max(xs) + m, max(ys) + m)
    return unary_union([inner, Polygon(SRC["bases"][0]["polygon"]), Polygon([rot(p) for p in SRC["bases"][0]["polygon"]])])


def design():
    lanes = lanes_all()
    rivers = [Polygon(r).buffer(0) for r in SRC["river"]]
    water = unary_union(rivers)
    towers = json.load(open(os.path.join(HERE, "..", "..", "data", "maps", "clashborn_map.json")))["towers"]
    tpts = [Point(t["pos"][0] / SRC["scale"] + FX0, t["pos"][1] / SRC["scale"] + FY0) for t in towers]
    corridors = unary_union([LineString([P[n] for n in names]).buffer(w / 2, cap_style="round", join_style="round") for names, w in PATHS])
    camps = unary_union([Point(CAMPS[c["id"]]).buffer(CAMP_R[c["kind"]]) for c in SRC["camps"]])
    clear = unary_union([corridors, camps] + [l.buffer(SRC["lane_half_width"] + 6) for l in lanes]
                        + [t.buffer(SRC["tower_clear_radius"] + 2) for t in tpts] + [water.buffer(3)]
                        + [Polygon(SRC["bases"][0]["polygon"]).buffer(4), Point(C, C).buffer(SRC["mid_clear_world"] / SRC["scale"])])
    region = half_region().intersection(playable(lanes))
    raw = region.difference(clear).buffer(-INSET, join_style="mitre")
    rings = unary_union([Point(CAMPS[c["id"]]).buffer(CAMP_R[c["kind"]] + HOOK_W).difference(Point(CAMPS[c["id"]]).buffer(CAMP_R[c["kind"]])) for c in SRC["camps"]])
    raw = unary_union([raw, rings.difference(clear.difference(camps))])  # vách hốc trại: lối khoét ra cửa
    blocks = []
    for g in getattr(raw, "geoms", [raw]):
        g = g.buffer(-ROUND, join_style="round").buffer(ROUND, join_style="round").simplify(SIMPLIFY)
        for q in getattr(g, "geoms", [g]):
            if q.geom_type == "Polygon" and q.area >= MIN_BLOCK:
                blocks.append(q)
    keep_open = unary_union([corridors] + [l.buffer(SRC["lane_half_width"] + 6) for l in lanes] + [Point(C, C).buffer(SRC["mid_clear_world"] / SRC["scale"])])
    bank = water.buffer(BANK).difference(water.buffer(0.5)).intersection(half_region()).difference(keep_open)
    rocks = [q for q in getattr(bank, "geoms", [bank]) if q.geom_type == "Polygon" and q.area > 20]
    return blocks, rocks, lanes, rivers, tpts, playable(lanes)


def camp_walls(solid):
    """MAP-08: số hướng (trên 24) bị chặn ở bán kính 330 (20,6 ô) quanh mỗi trại."""
    out = {}
    for cid, c in CAMPS.items():
        out[cid] = sum(solid.contains(Point(c[0] + 20.6 * math.cos(2 * math.pi * k / 24), c[1] + 20.6 * math.sin(2 * math.pi * k / 24))) for k in range(24))
    return out


def measure(blocks, lanes, rivers, edge_free):  # blocks gồm cả đá bờ
    n = int(FX1 - FX0)
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)
    for p in blocks + [Polygon([rot(c) for c in b.exterior.coords]) for b in blocks]:
        d.polygon([(x - FX0, y - FY0) for x, y in p.exterior.coords], fill=1)
    outside = box(FX0, FY0, FX1, FY1).difference(edge_free)
    for g in getattr(outside, "geoms", [outside]):
        d.polygon([(x - FX0, y - FY0) for x, y in g.exterior.coords], fill=1)
    b = np.array(im) > 0
    dist = ndi.distance_transform_edt(~b) * SRC["scale"]
    ridge = (dist > 0) & (dist >= ndi.maximum_filter(dist, size=5))
    lz = unary_union([l.buffer(SRC["lane_half_width"] + 16) for l in lanes] + rivers)
    v = [dist[y, x] * 2 for y, x in zip(*np.nonzero(ridge)) if not lz.contains(Point(x + FX0, y + FY0))]
    v = np.array(v)
    blocked = b.mean()
    return np.median(v), (v < 300).mean(), (v >= 500).mean(), blocked


def draw(path, blocks, rocks, lanes, rivers, tpts, edge_free):
    k = 2
    img = Image.new("RGB", (int(FX1 - FX0) * k, int(FY1 - FY0) * k), (104, 124, 74))
    d = ImageDraw.Draw(img)
    T = lambda pts: [((x - FX0) * k, (y - FY0) * k) for x, y in pts]
    outside = box(FX0, FY0, FX1, FY1).difference(edge_free)
    for g in getattr(outside, "geoms", [outside]):
        d.polygon(T(g.exterior.coords), fill=(120, 116, 108))
    for b in blocks:
        for q in (list(b.exterior.coords), [rot(c) for c in b.exterior.coords]):
            d.polygon(T(q), fill=(42, 72, 64), outline=(150, 154, 160))
    for r in rivers:
        d.polygon(T(r.exterior.coords), fill=(34, 86, 104))
    for b in rocks:
        for q in (list(b.exterior.coords), [rot(c) for c in b.exterior.coords]):
            d.polygon(T(q), fill=(150, 152, 156))
    for l in lanes:
        d.line(T(l.coords), fill=(176, 160, 120), width=int(SRC["lane_half_width"] * 2 * k))
    for t in tpts:
        for q in (t, Point(rot((t.x, t.y)))):
            d.ellipse([(q.x - FX0) * k - 7, (q.y - FY0) * k - 7, (q.x - FX0) * k + 7, (q.y - FY0) * k + 7], fill=(80, 140, 230) if blue((q.x, q.y)) else (220, 80, 70))
    for c in CAMPS.values():
        for q in (c, rot(c)):
            d.ellipse([(q[0] - FX0) * k - 6, (q[1] - FY0) * k - 6, (q[0] - FX0) * k + 6, (q[1] - FY0) * k + 6], fill=(240, 200, 60))
    img.save(path)


def main():
    blocks, rocks, lanes, rivers, tpts, edge_free = design()
    med, narrow, wide, blocked = measure(blocks + rocks, lanes, rivers, edge_free)
    solid = unary_union(blocks + rocks + [box(FX0, FY0, FX1, FY1).difference(edge_free)])
    print("MAP-08 hướng chặn / 24:", camp_walls(solid))
    print(f"bục / nửa {len(blocks)}; lối rộng trung vị {med:.0f}, hẹp < 300: {narrow * 100:.0f}%, ≥ 500: {wide * 100:.0f}%; vật cản {blocked * 100:.0f}% khung")
    draw(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "plateau_preview.png"), blocks, rocks, lanes, rivers, tpts, edge_free)


if __name__ == "__main__":
    main()
