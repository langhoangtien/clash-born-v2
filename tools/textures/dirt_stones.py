#!/usr/bin/env python3
"""Ảnh nền "đường đất có phiến đá" (D-190) lặp liền mép, nhìn thẳng từ trên, kiểu vẽ tay theo ảnh mẫu người chơi:
đất nện vàng nâu loang, phiến đá xám ấm đa giác theo cụm (mép trên-trái sáng, dưới-phải tối, vân mờ, vài vết
nứt), khe đất sẫm quanh phiến, sỏi nhỏ. Mọi nét vẽ lặp quanh mép (toroidal) nên ghép liền.

  python3 tools/textures/dirt_stones.py [ra.png]   (mặc định assets/textures/style/dirt_stones.png)
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

N = 1024          # cạnh ảnh (px) — phủ dirt_m mét trong game
SEED = 190
DIRT = (176, 142, 94)
DIRT_DARK = (146, 114, 72)
DIRT_LIGHT = (196, 164, 114)
STONES = [(150, 146, 136), (138, 134, 125), (160, 155, 143), (128, 125, 118)]
GROOVE = (112, 88, 58)


def tile_noise(rng, cells, blur):
    """Nhiễu lặp liền mép: lưới ngẫu nhiên phóng to, làm mờ theo kiểu bọc mép."""
    small = rng.random((cells, cells))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
    big = Image.new("L", (N * 3, N * 3))
    for i in range(3):
        for j in range(3):
            big.paste(img, (i * N, j * N))
    big = big.filter(ImageFilter.GaussianBlur(blur))
    return np.array(big.crop((N, N, 2 * N, 2 * N))).astype(float) / 255.0


def wrapped(draw_fn):
    """Vẽ một hình ở 9 vị trí lệch ±N để lặp liền mép."""
    for dx in (-N, 0, N):
        for dy in (-N, 0, N):
            draw_fn(dx, dy)


def layout(rng):
    """Cụm phiến ghép (D-190): mỗi cụm là một mảng tròn méo; hạt Voronoi trong cụm với khoảng cách theo cỡ phiến
    (vài phiến rất to, nhiều phiến vừa, mảnh nhỏ) → ô Voronoi thu vào thành phiến, khe hẹp như đá lát vỡ.
    Trả về [(đa giác, bán kính cỡ)] (toạ độ có thể vượt mép, vẽ bọc mép)."""
    from scipy.spatial import Voronoi
    from shapely.geometry import Polygon, Point
    from shapely.ops import unary_union
    blobs = []
    for _ in range(5):
        cx, cy, r = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(120, 220)
        parts = [Point(cx + rng.uniform(-0.5, 0.5) * r, cy + rng.uniform(-0.5, 0.5) * r).buffer(r * rng.uniform(0.45, 0.7)) for _ in range(4)]
        blobs.append(unary_union(parts))
    seeds = []
    for blob in blobs:
        x0, y0, x1, y1 = blob.bounds
        for _ in range(400):
            t = rng.random()
            r = rng.uniform(110, 160) if t < 0.3 else (rng.uniform(60, 95) if t < 0.8 else rng.uniform(25, 40))
            p = (rng.uniform(x0, x1), rng.uniform(y0, y1))
            if blob.contains(Point(p)) and all(math.hypot(p[0] - q[0], p[1] - q[1]) > (r + q[2]) * 0.78 for q in seeds):
                seeds.append((p[0], p[1], r))
    pts = [(x + dx, y + dy) for x, y, _ in seeds for dx in (-N, 0, N) for dy in (-N, 0, N)]
    vor = Voronoi(pts)
    out = []
    for k, (x, y, r) in enumerate(seeds):
        region = vor.regions[vor.point_region[k * 9 + 4]]  # bản giữa (dx = dy = 0)
        if -1 in region or not region:
            continue
        clip = Polygon([(x + math.cos(a) * r * 1.15, y + math.sin(a) * r * 1.0) for a in
                        [rng.uniform(0, 0.9) + i * 2 * math.pi / 6 for i in range(6)]])  # góc cạnh, không tròn
        cell = Polygon([vor.vertices[i] for i in region]).intersection(clip)
        cell = cell.buffer(-6, join_style=2)  # khe giữa các phiến
        if cell.is_empty or cell.geom_type != "Polygon" or cell.area < 150:
            continue
        cell = cell.simplify(2.5)
        out.append(([(px + rng.uniform(-2, 2), py + rng.uniform(-2, 2)) for px, py in list(cell.exterior.coords)[:-1]], r))
    return out


def paint_ground(rng, nrng):
    big = tile_noise(nrng, 6, 40)
    mid = tile_noise(nrng, 24, 10)
    fine = tile_noise(nrng, 160, 1.2)
    t = np.clip((big - 0.5) * 1.1 + (mid - 0.5) * 0.9 + 0.5, 0, 1)
    base = np.array(DIRT_DARK) * (1 - t[..., None]) + np.array(DIRT_LIGHT) * t[..., None]
    base *= (0.94 + (fine[..., None] - 0.5) * 0.18)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))


def paint_stones(img, rng, nrng):
    d = ImageDraw.Draw(img)
    shapes = [(pts, r, rng.choice(STONES)) for pts, r in layout(rng)]
    groove = Image.new("L", (N, N), 0)
    dg = ImageDraw.Draw(groove)
    for pts, r, _ in shapes:
        wrapped(lambda dx, dy: dg.polygon([(x + dx, y + dy) for x, y in _grow(pts, 1.0 + 7 / r)], fill=255))
    groove = groove.filter(ImageFilter.GaussianBlur(3))
    img.paste(Image.new("RGB", (N, N), GROOVE), mask=groove.point(lambda v: int(v * 0.75)))
    vein = tile_noise(nrng, 14, 7)
    for pts, r, col in shapes:
        _stone(img, d, pts, r, col, rng, vein)
    for _ in range(140):  # sỏi nhỏ
        x, y, s = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(2.5, 6)
        c = rng.choice(STONES)
        wrapped(lambda dx, dy: d.ellipse([x + dx - s, y + dy - s * 0.8, x + dx + s, y + dy + s * 0.8], fill=c, outline=GROOVE))


def _grow(pts, k):
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts]


def _stone(img, d, pts, r, col, rng, vein):
    """Một phiến: mặt màu col, vân mờ, mép trên-trái sáng / dưới-phải tối (nắng tây bắc), 0–2 vết nứt."""
    mask = Image.new("L", (N, N), 0)
    dm = ImageDraw.Draw(mask)
    wrapped(lambda dx, dy: dm.polygon([(x + dx, y + dy) for x, y in pts], fill=255))
    face = np.array(col, float)[None, None, :] * (0.95 + (vein[..., None] - 0.5) * 0.22)
    tone = rng.uniform(0.94, 1.06)
    img.paste(Image.fromarray(np.clip(face * tone, 0, 255).astype(np.uint8)), mask=mask)
    w = max(2, int(r * 0.06))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        nx, ny = b[1] - a[1], -(b[0] - a[0])  # pháp tuyến ra ngoài (đa giác ngược kim đồng hồ trên ảnh)
        lit = (-nx - ny) / (math.hypot(nx, ny) or 1)
        c = tuple(int(v * (1.18 if lit > 0.3 else (0.7 if lit < -0.3 else 0.95))) for v in col)
        wrapped(lambda dx, dy: d.line([(a[0] + dx, a[1] + dy), (b[0] + dx, b[1] + dy)], fill=c, width=w))
    if r > 60 and rng.random() < 0.4:  # vết nứt thẳng ngắn trên phiến to
        i = rng.randrange(len(pts))
        a, b = pts[i], pts[(i + len(pts) // 2) % len(pts)]
        t0, t1 = rng.uniform(0.0, 0.2), rng.uniform(0.45, 0.7)
        dark = tuple(int(v * 0.78) for v in col)
        line = [(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t) for t in (t0, t1)]
        wrapped(lambda dx, dy: d.line([(x + dx, y + dy) for x, y in line], fill=dark, width=2))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "style", "dirt_stones.png")
    rng = random.Random(SEED)
    nrng = np.random.default_rng(SEED)
    img = paint_ground(rng, nrng)
    paint_stones(img, rng, nrng)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    img.save(out)
    print("đã ghi", out)


if __name__ == "__main__":
    main()
