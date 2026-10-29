#!/usr/bin/env python3
"""Đọc bản vẽ map (sketch/map_sketch.png, D-171) → sông, base, shop ẩn nửa Blue cho map_source.json.

Quy ước màu bản vẽ (ảnh vuông = cả khung map, base Blue góc dưới trái):
  vàng xanh = đi được, đen = khối chặn, xanh nước = sông, xanh xám = base,
  chấm đỏ = bãi quái, chấm xanh ngọc = shop ẩn.
Ảnh vẽ tay không đối xứng tuyệt đối: lấy nửa Blue (phía dưới đường sông qua tâm) rồi xoay 180° (MAP-04).
Bục rừng, đá bờ, rìa map, trại và bụi do plateau_design.py làm (D-178) — bản vẽ chỉ còn cho sông / base / shop.
Ghi: river (cả sông), bases[0], shops → sketch_import.json / --write.

  python3 tools/map_build/from_sketch.py [--write]
"""
import json, os, sys
import numpy as np, cv2
from PIL import Image
from scipy import ndimage
from shapely.geometry import Polygon, Point

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "map_source.json")
IMG = os.path.join(HERE, "sketch", "map_sketch.png")
RIVER_SLOPE = 0.747
BASE_ART_R = 0.345  # bán kính hình base trong bản vẽ / cạnh ảnh
BASE_R = 0.29       # D-172: nền base (đất cao) nhỏ hơn hình vẽ; phần hình base thừa thành đất đi được


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
    corner = np.hypot(xx, n0 - 1 - yy)
    art = ((base & ndimage.binary_dilation(corner < BASE_ART_R * n0, iterations=40)) | (corner < BASE_ART_R * n0))
    art = symmetric(ndimage.binary_fill_holes(art | art[::-1, ::-1]) & ~walk)  # cả nét tối của hình base
    base = symmetric(art & (corner < BASE_R * n0))
    walk = walk | (art & ~base)
    blue = lambda p: p.y > p.x
    rivers = polygons(river, k, 20.0)
    bases = [p for p in polygons(base, k, 200.0) if blue(p.representative_point())]
    shops = [Point(k(x, y)) for x, y in spots(cyan)]
    out = {
        "river": [[list(c) for c in p.exterior.coords[:-1]] for p in rivers],
        "base0": [snap(c, src["frame"]) for c in max(bases, key=lambda p: p.area).simplify(1.0).exterior.coords[:-1]],
        "shops": [[round(p.x, 1), round(p.y, 1)] for p in shops if blue(p)],
    }
    print(f"sông {len(rivers)}, shop ẩn {len(out['shops'])}", file=sys.stderr)
    json.dump(out, open(os.path.join(HERE, "sketch", "sketch_import.json"), "w"), indent=0)
    if "--write" in sys.argv:
        apply(src, out)
        json.dump(src, open(SRC, "w"), ensure_ascii=False, indent=1)
        print("đã ghi map_source.json", file=sys.stderr)


def apply(src, out):
    """Thay sông / base / shop của nguồn bằng bản vẽ."""
    src["river"], src["rock_lines"] = out["river"], []
    src["bases"][0]["polygon"] = out["base0"]
    src["clear_circles"] = []
    src.pop("landmarks", None)
    src["shops"] = [{"name": "S%d" % (i + 1), "pos": p} for i, p in enumerate(out["shops"])]


if __name__ == "__main__":
    main()
