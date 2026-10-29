#!/usr/bin/env python3
"""Cảnh mẫu phong cách mới (bước 1 đồ họa): góc Tây Bắc map 40 × 40 m — tường thành, rào ranh giới, lane,
bục rừng viền đá, hốc trại, sông. Ra:
  out/sample.json   vị trí từng asset [model, x, z, góc, cỡ] + polygon nước (mét, x đông, z nam)
  out/ground_mask.png  R đất, G đá lát, B nền rừng tối, A độ sâu nước (20 px / m)
  out/shadow.png    bóng vẽ sẵn dưới cây / đá, lệch về đông nam (nắng từ tây bắc)
  out/grass.png, dirt.png, pave.png  ảnh nền lặp liền mép 512 (tạm, tự sinh — sẽ thay bằng ảnh Codex vẽ)

  python3 tools/style_sample/make_sample.py
"""
import json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SIZE = 40.0
PPM = 20  # điểm ảnh mặt nạ mỗi mét
rng = random.Random(7)

# --- bố cục (mét) ----------------------------------------------------------------------------
FENCE_N, FENCE_W = 2.0, 2.0                       # rào ranh giới (mép trong)
LANE = LineString([(40, 5.5), (8, 5.5), (5.5, 8), (5.5, 40)])
LANE_W = 3.2
BLOCKS = [  # bục rừng
    Polygon([(11, 10), (22, 9.5), (25, 13), (21, 17.5), (13, 18), (10, 14)]),
    Polygon([(27, 17), (36, 16), (38, 21), (37, 28), (31, 29.5), (28.5, 27), (33, 25.5), (34, 21.5), (30, 20.5), (27.5, 21.5)]),  # hốc trại (mở phía tây)
    Polygon([(10, 24), (16, 23), (18, 27), (15, 31.5), (10.5, 31)]),
]
CAMP = (30.0, 24.0)
RIVER = LineString([(40, 31), (33, 34), (27, 37.5), (22, 41)]).buffer(3.2, cap_style=2)
HERO = (19.5, 21.5)


def edge_items(poly, items):
    """Tường đá liền dọc mép bục (khối đặt sát, chồng nhẹ, thân dọc theo mép): mép quay bắc (xa camera) khối cao,
    mép quay nam (gần camera) khối thấp + khóm lá — không che tướng (D-177). Thỉnh thoảng hở một quãng."""
    ring = list(poly.exterior.coords)
    ccw = poly.exterior.is_ccw
    for a, b in zip(ring, ring[1:]):
        seg = LineString([a, b])
        nx, nz = (b[1] - a[1]), -(b[0] - a[0])
        if not ccw:
            nx, nz = -nx, -nz
        ln = math.hypot(nx, nz)
        north, south = nz < -0.35 * ln, nz > 0.35 * ln
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        d = 0.0
        while d < seg.length:
            p = seg.interpolate(d)
            if south:
                kind, step = rng.choice([("rock_low", 1.5), ("rock_low", 1.5), ("plant_orange", 1.0)])
            else:
                kind, step = rng.choice([("rock_tall", 1.3), ("rock_wide", 1.8)] if north else [("rock_wide", 1.8), ("rock_low", 1.5), ("rock_tall", 1.3)])
            if rng.random() > 0.08:
                items.append([kind, p.x, p.y, -ang + rng.uniform(-0.12, 0.12), rng.uniform(0.9, 1.15)])
            d += step * rng.uniform(0.85, 1.0)


def fill_trees(poly, items):
    """Cây trong bục, lùi mép 1,2 m; nửa bắc thông cao, nửa nam thông thấp (camera ở nam)."""
    inner = poly.buffer(-1.2)
    x0, z0, x1, z1 = inner.bounds
    z = z0
    while z < z1:
        x = x0 + rng.uniform(0, 1.0)
        while x < x1:
            p = Point(x + rng.uniform(-0.5, 0.5), z + rng.uniform(-0.5, 0.5))
            if inner.contains(p):
                t = (p.y - z0) / max(0.1, z1 - z0)            # 0 bắc → 1 nam
                kind = "pine_l" if t < 0.35 else ("pine_m" if t < 0.7 else "pine_s")
                if rng.random() < 0.14:
                    kind = rng.choice(["tree_round", "tree_autumn"])
                items.append([kind, p.x, p.y, rng.uniform(0, 6.28), rng.uniform(0.85, 1.1)])
            x += 1.9
        z += 1.7


def border(items):
    for x in np.arange(FENCE_W, SIZE + 4, 4.0):
        items.append(["fence", x + 2.0, FENCE_N - 0.3, 0.0, 1.0])
    for z in np.arange(FENCE_N, SIZE + 4, 4.0):
        items.append(["fence", FENCE_W - 0.3, z + 2.0, math.pi / 2, 1.0])
    for x in np.arange(-10, SIZE + 10, 10.0):
        items.append(["great_wall", x + 5.0, -5.5, 0.0, 1.0])     # bắc: cao bao nhiêu cũng được
    for z in np.arange(-10, SIZE + 10, 10.0):
        items.append(["great_wall", -5.5, z + 5.0, math.pi / 2, 1.0])  # tây: camera nhìn ngang, không che


def scatter(items, solid):
    for _ in range(70):
        p = Point(rng.uniform(3, 39), rng.uniform(3, 39))
        if solid.distance(p) < 0.6 or LANE.distance(p) < LANE_W / 2 + 0.3 or RIVER.contains(p):
            continue
        near = solid.distance(p) < 2.5 or LANE.distance(p) < LANE_W / 2 + 1.5
        if near and rng.random() < 0.5:
            items.append([rng.choice(["plant_orange", "plant_orange", "rock_small"]), p.x, p.y, rng.uniform(0, 6.28), rng.uniform(0.7, 1.0)])


def river_bank(items):
    edge = RIVER.exterior
    north_side = [p for p in (edge.interpolate(d) for d in np.arange(0, edge.length, 1.6)) if p.y < 33 + (40 - p.x) * 0.5 and 2 < p.x < 39 and p.y < 39]
    for p in north_side[: len(north_side) // 2]:
        items.append([rng.choice(["rock_wide", "rock_low"]), p.x, p.y, rng.uniform(-0.3, 0.3), rng.uniform(0.8, 1.0)])


def mask(blocks):
    n = int(SIZE * PPM)
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = lambda pts: [(x * PPM, z * PPM) for x, z in pts]
    dirt = unary_union([Point(CAMP).buffer(4.5), Point(HERO).buffer(3.5), LANE.buffer(LANE_W / 2 + 0.9)])
    for g in getattr(dirt, "geoms", [dirt]):
        d.polygon(s(g.exterior.coords), fill=(255, 0, 0, 0))
    r, g_, b, a = img.split()
    pave = Image.new("L", (n, n), 0)
    ImageDraw.Draw(pave).polygon(s(LANE.buffer(LANE_W / 2 - 0.2).exterior.coords), fill=255)
    forest = Image.new("L", (n, n), 0)
    for bl in blocks:
        ImageDraw.Draw(forest).polygon(s(bl.buffer(0.8).exterior.coords), fill=255)
    water = Image.new("L", (n, n), 0)
    ImageDraw.Draw(water).polygon(s(RIVER.exterior.coords), fill=255)
    depth = np.array(water.filter(ImageFilter.GaussianBlur(PPM * 1.2))).astype(float)
    depth = np.clip((depth - 128) * 2, 0, 255) * (np.array(water) > 0)
    r = _ragged(r, 11)
    forest = _ragged(forest, 12)
    out = Image.merge("RGBA", [r.filter(ImageFilter.GaussianBlur(PPM * 0.2)), pave.filter(ImageFilter.GaussianBlur(PPM * 0.15)),
                              forest.filter(ImageFilter.GaussianBlur(PPM * 0.8)), Image.fromarray(depth.astype(np.uint8))])
    out.save(os.path.join(OUT, "ground_mask.png"))


SHADOW_R = {"pine_l": 1.4, "pine_m": 1.2, "pine_s": 1.0, "tree_round": 1.5, "tree_autumn": 1.6, "rock_tall": 1.0,
            "rock_wide": 1.2, "rock_low": 0.9, "rock_small": 0.5, "plant_orange": 0.4, "fence": 0.0, "great_wall": 0.0}


def shadows(items):
    n = int(SIZE * PPM)
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    for kind, x, z, _, sc in items:
        r = SHADOW_R[kind] * sc
        if r > 0:
            cx, cz = (x + r * 0.45) * PPM, (z + r * 0.35) * PPM
            d.ellipse([cx - r * PPM, cz - r * 0.8 * PPM, cx + r * PPM, cz + r * 0.8 * PPM], fill=200)
    for x in np.arange(FENCE_W, SIZE, 0.5):  # bóng rào phía nam / đông của rào
        d.rectangle([x * PPM, FENCE_N * PPM, (x + 0.5) * PPM, (FENCE_N + 0.7) * PPM], fill=150)
    d.rectangle([FENCE_W * PPM, FENCE_N * PPM, (FENCE_W + 0.8) * PPM, SIZE * PPM], fill=150)
    img.filter(ImageFilter.GaussianBlur(PPM * 0.45)).save(os.path.join(OUT, "shadow.png"))


def _ragged(img, seed):
    """Mép vùng tô (đất, nền rừng) răng cưa mềm như nét cọ: nhiễu cộng vào trước khi làm mờ."""
    a = np.array(img.filter(ImageFilter.GaussianBlur(PPM * 1.0))).astype(float)
    r = np.random.default_rng(seed)
    noise = np.array(Image.fromarray((r.random((60, 60)) * 255).astype(np.uint8)).resize(img.size, Image.BICUBIC)).astype(float)
    return Image.fromarray(((a - 128) * 1.2 + (noise - 128) * 0.7 > 0).astype(np.uint8) * 255)


def _periodic_noise(n, r, freqs):
    """Nhiễu lặp liền mép thật: tổng sóng sin tần số nguyên (chu kỳ đúng n điểm ảnh)."""
    y, x = np.mgrid[0:n, 0:n] / n * 2 * np.pi
    f = np.zeros((n, n))
    for kmax, amp in freqs:
        for _ in range(6):
            kx, ky = r.integers(-kmax, kmax + 1, 2)
            f += amp * np.sin(kx * x + ky * y + r.uniform(0, 6.28))
    return (f - f.min()) / np.ptp(f)


def tile(name, base, blotch, specks, seed):
    """Ảnh nền lặp liền mép kiểu vẽ tay: nền + mảng đậm nhạt phân tầng + nét cọ ngắn (vẽ quấn mép)."""
    r = np.random.default_rng(seed)
    n = 512
    f = _periodic_noise(n, r, ((2, 1.0), (5, 0.45), (11, 0.2)))
    f = 0.25 + 0.5 * (np.round(f * 5) / 5)
    col = np.array(base, float)[None, None, :] * (1 - f[..., None]) + np.array(blotch, float)[None, None, :] * f[..., None]
    big = Image.fromarray(np.tile(col.astype(np.uint8), (3, 3, 1)))
    d = ImageDraw.Draw(big)
    for _ in range(1100):
        x, y = r.integers(n, 2 * n, 2)
        c = tuple(specks[r.integers(0, len(specks))])
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                d.line([(x + ox, y + oy), (x + ox + r.integers(-3, 4), y + oy - r.integers(3, 8))], fill=c, width=2)
    big = big.filter(ImageFilter.GaussianBlur(0.8))
    big.crop((n, n, 2 * n, 2 * n)).save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    items = []
    border(items)
    for bl in BLOCKS:
        edge_items(bl, items)
        fill_trees(bl, items)
    river_bank(items)
    scatter(items, unary_union(BLOCKS))
    data = {"size": SIZE, "hero": HERO, "camp": CAMP, "items": items,
            "water": [list(c) for c in RIVER.exterior.coords[:-1]]}
    json.dump(data, open(os.path.join(OUT, "sample.json"), "w"))
    mask(BLOCKS)
    shadows(items)
    tile("grass", (102, 120, 72), (70, 96, 74), [(128, 140, 82), (84, 108, 70), (60, 86, 70)], 1)
    tile("dirt", (150, 136, 98), (126, 112, 80), [(170, 156, 116), (120, 106, 78)], 2)
    tile("pave", (136, 132, 120), (112, 110, 104), [(160, 156, 144), (96, 96, 92)], 3)
    counts = {}
    for it in items:
        counts[it[0]] = counts.get(it[0], 0) + 1
    print(counts)


if __name__ == "__main__":
    main()
