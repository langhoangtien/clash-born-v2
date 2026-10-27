#!/usr/bin/env python3
"""Đọc bản vẽ map (sketch/map_sketch.png, D-171) → nửa Blue cho map_source.json.

Quy ước màu bản vẽ (ảnh vuông = cả khung map, base Blue góc dưới trái):
  vàng xanh = đi được, đen = khối đá chặn, xanh nước = sông, xanh xám = base,
  chấm đỏ = bãi quái, chấm xanh ngọc = shop ẩn.
Ảnh vẽ tay không đối xứng tuyệt đối: lấy nửa Blue (phía dưới đường sông qua tâm) rồi xoay 180° (MAP-04).
Ghi: mountains (khối đá nửa Blue), river (cả sông), bases[0], camps, shops → in JSON ra stdout / --write.

  python3 tools/map_build/from_sketch.py [--write]
"""
import json, math, os, sys
import numpy as np, cv2
from PIL import Image
from scipy import ndimage
from shapely.geometry import Polygon, Point

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "map_source.json")
IMG = os.path.join(HERE, "sketch", "map_sketch.png")
RIVER_SLOPE = 0.747
BASE_R = 0.345  # bán kính nền base / cạnh ảnh
SHRINK = 2.5     # D-171: thu khối đá vào mỗi phía (ô guide) — lối đi rộng hơn nét vẽ
BUSHES = 7       # bụi cỏ mỗi nửa (D-72: 14 bụi cả map)  # hướng sông trên bản vẽ (đường cắt đối xứng qua tâm)


def masks(a):
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    red = (R > 200) & (G < 60) & (B < 60)
    cyan = (G > 245) & (B > 245) & (R < 60)
    river = (B > 200) & (R < 70) & (G > 90) & (B - R > 150) & ~cyan
    base = (B > 120) & (R > 40) & (R < 170) & (B - R > 40) & ~river
    walk = ((G > 150) & (R > 120) & (B < 130)) | ndimage.binary_dilation(red | cyan, iterations=14)
    river = ndimage.binary_closing(ndimage.binary_opening(river, iterations=2), iterations=6)
    return walk & ~river, river, base & ~walk, red, cyan


def symmetric(m):
    n = m.shape[0]
    y, x = np.mgrid[0:n, 0:n]
    c = (n - 1) / 2
    blue = (y - c) > RIVER_SLOPE * (x - c)
    return (m & blue) | (m & blue)[::-1, ::-1]


def spots(m):
    lb, n = ndimage.label(m)
    cs = ndimage.center_of_mass(m, lb, range(1, n + 1))
    sz = ndimage.sum(m, lb, range(1, n + 1))
    return [(x, y) for (y, x), s in zip(cs, sz) if 200 < s < 900]


def polygons(m, k, min_area):
    m = ndimage.binary_opening(ndimage.binary_closing(m, iterations=2), iterations=2)
    cs, hier = cv2.findContours(m.astype(np.uint8), cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    out = []
    for i, c in enumerate(cs):
        if hier[0][i][3] != -1:
            continue
        c = cv2.approxPolyDP(c, 1.2, True)[:, 0, :]
        if len(c) < 3:
            continue
        p = Polygon([k(x, y) for x, y in c]).buffer(0)
        if p.area >= min_area:
            out.append(p)
    return out


def snap(c, frame):
    """Điểm sát khung (≤ 3 ô) dính hẳn vào khung: mép base trùng mép map không sinh rào (MAP-09)."""
    x, y = c
    x = frame[0] if x - frame[0] <= 3 else frame[2] if frame[2] - x <= 3 else x
    y = frame[1] if y - frame[1] <= 3 else frame[3] if frame[3] - y <= 3 else y
    return [x, y]


def main():
    src = json.load(open(SRC))
    fx0, fy0, fx1, fy1 = src["frame"]
    a = np.array(Image.open(IMG).convert("RGB")).astype(int)
    n = a.shape[0]
    s = (fx1 - fx0) / n
    k = lambda x, y: (round(fx0 + (x + 0.5) * s, 1), round(fy0 + (y + 0.5) * s, 1))
    walk, river, base, red, cyan = masks(a)
    walk, river, base = symmetric(walk), symmetric(river), symmetric(base)
    n0 = base.shape[0]
    yy, xx = np.mgrid[0:n0, 0:n0]
    disk = np.hypot(xx, n0 - 1 - yy) < BASE_R * n0  # nền base = phần tư hình tròn góc (cả nét tối của hình base)
    base = ((base & ndimage.binary_dilation(disk, iterations=40)) | disk)
    base = symmetric(ndimage.binary_fill_holes(base | base[::-1, ::-1]) & ~walk)
    block = ~(walk | river | base)
    blue = lambda p: p.y > p.x
    blocks = [g for p in polygons(block, k, 4.0) if blue(p.representative_point())
              for g in getattr(p.buffer(-SHRINK, join_style="round"), "geoms", [p.buffer(-SHRINK, join_style="round")])
              if g.area >= 4.0 and g.geom_type == "Polygon"]
    rivers = polygons(river, k, 20.0)
    bases = [p for p in polygons(base, k, 200.0) if blue(p.representative_point())]
    camps = [Point(k(x, y)) for x, y in spots(red)]
    shops = [Point(k(x, y)) for x, y in spots(cyan)]
    out = {
        "mountains": [[[round(x, 1), round(y, 1)] for x, y in p.simplify(0.4).exterior.coords[:-1]] for p in blocks],
        "river": [[list(c) for c in p.exterior.coords[:-1]] for p in rivers],
        "base0": [snap(c, src["frame"]) for c in max(bases, key=lambda p: p.area).simplify(1.0).exterior.coords[:-1]],
        "camps": [[round(p.x, 1), round(p.y, 1)] for p in camps if blue(p)],
        "shops": [[round(p.x, 1), round(p.y, 1)] for p in shops if blue(p)],
    }
    print(f"khối nửa Blue {len(blocks)}, sông {len(rivers)}, trại {len(out['camps'])}, shop ẩn {len(out['shops'])}", file=sys.stderr)
    json.dump(out, open(os.path.join(HERE, "sketch", "sketch_import.json"), "w"), indent=0)
    if "--write" in sys.argv:
        apply(src, out)
        json.dump(src, open(SRC, "w"), ensure_ascii=False, indent=1)
        print("đã ghi map_source.json", file=sys.stderr)


def apply(src, out):
    """Thay vật cản / sông / base / trại / shop của nguồn bằng bản vẽ; trại giữ id, loại theo trại cũ gần nhất."""
    src["mountains"], src["river"], src["forest"], src["rock_lines"] = out["mountains"], out["river"], [], []
    src["bases"][0]["polygon"] = out["base0"]
    for key in ("river_bank", "ring", "tree_alcove", "door_clear"):  # D-171: bờ sông, hốc trại là khối đá
        src.pop(key, None)
    src["clear_circles"] = []
    solid = [Polygon(p).buffer(0) for p in out["mountains"] + out["river"]]
    src["camps"] = [c for c in src["camps"] if c["side"] != -1]  # D-171: bỏ boss
    src.pop("landmarks", None)
    src["bushes"] = bushes(src, out)
    old = [c for c in src["camps"] if c["side"] == 0]
    left = list(out["camps"])
    for c in old:
        best = min(left, key=lambda q: math.dist(q, c["pos"]))
        left.remove(best)
        c["pos"] = best
        c.pop("alcove", None)
    src["shops"] = [{"name": "S%d" % (i + 1), "pos": p} for i, p in enumerate(out["shops"])]


def bushes(src, out):
    """VIS-06 / D-72: đặt BUSHES bụi nửa Blue trên lối rừng — đủ rộng, ngoài tầm trụ, xa trại / lane,
    trải đều (chọn điểm xa nhau nhất); bụi nằm dọc theo hướng lối đi."""
    from shapely.geometry import box, LineString
    from shapely.ops import unary_union
    fx0, fy0, fx1, fy1 = src["frame"]
    rot = lambda q: (fx0 + fx1 - q[0], fy0 + fy1 - q[1])
    solid = [Polygon(p).buffer(0) for p in out["mountains"]]
    solid += [Polygon([rot(q) for q in p]).buffer(0) for p in out["mountains"]]
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
            if y < x + 6 or not walk.contains(q.buffer(7)) or water.distance(q) < 6 or lanes.distance(q) < 13:
                continue
            if min(t.distance(q) for t in towers) < 550 / sc + 13 or min(c.distance(q) for c in camps) < 36:  # xa trại: không che lối kéo quái (D-76)
                continue
            cand.append(q)
    pick = [min(cand, key=lambda q: q.distance(Point(300, 420)))]
    while len(pick) < BUSHES:
        far = lambda q: min(min(q.distance(p), q.distance(Point(rot((p.x, p.y))))) for p in pick)
        pick.append(max(cand, key=far))
    out_b = []
    for q in pick:
        near = [c for c in cand if c.distance(q) < 14] or [q]
        xs = np.array([[c.x - q.x, c.y - q.y] for c in near])
        ang = 0.0
        if len(xs) > 2:
            w, v = np.linalg.eigh(xs.T @ xs)
            ang = math.degrees(math.atan2(v[1, 1], v[0, 1]))
        out_b.append({"pos": [q.x, q.y], "rx": 11, "ry": 6, "angle": round(ang)})
    return out_b


if __name__ == "__main__":
    main()
