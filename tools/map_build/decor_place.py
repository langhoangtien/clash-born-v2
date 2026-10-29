"""Quy tắc đặt cảnh vật D-178 (dùng bởi decor.py). Toạ độ thế giới px (100 px = 1 m); góc theo Godot:
Basis(UP, góc) — đoạn hướng (dx, dz) có góc = −atan2(dz, dx)."""
import math
import numpy as np
from PIL import Image, ImageFilter
from shapely.geometry import LineString, Point, box
from shapely.ops import unary_union

M = 100.0  # px mỗi mét
# Bán kính bóng vẽ sẵn (m) theo mô hình.
SHADOW_R = {"pine_l": 1.4, "pine_m": 1.2, "pine_s": 1.0, "tree_round": 1.5, "tree_autumn": 1.6, "rock_tall": 1.0,
            "rock_wide": 1.2, "rock_low": 0.9, "rock_small": 0.5, "plant_orange": 0.4, "reeds": 0.35,
            "grass_tuft": 0.2, "boulder_a": 0.8, "boulder_b": 0.55}
TREE_STEP = (1.9 * M, 1.7 * M)   # lưới cây trong bục
TREE_INSET = 1.2 * M
FENCE_STEP = 3.8 * M             # đoạn rào dài 4 m, chồng nhẹ
WALL_STEP = 10.0 * M             # đoạn tường thành 10 m


def ragged(img, blur_m, seed, mask_px=8.0):
    """Mép vùng tô răng cưa mềm như nét cọ: làm mờ, cộng nhiễu, cắt ngưỡng, làm mờ nhẹ lại."""
    a = np.array(img.filter(ImageFilter.GaussianBlur(blur_m * M / mask_px * 0.5))).astype(float)
    r = np.random.default_rng(seed)
    cells = max(4, img.size[0] // int(1.5 * M / mask_px))
    noise = np.array(Image.fromarray((r.random((cells, cells)) * 255).astype(np.uint8)).resize(img.size, Image.BICUBIC)).astype(float)
    hard = Image.fromarray((((a - 128) * 1.2 + (noise - 128) * 0.7) > 0).astype(np.uint8) * 255)
    return hard.filter(ImageFilter.GaussianBlur(0.25 * M / mask_px))


def _outward(seg, poly):
    """Pháp tuyến đơn vị của đoạn `seg` (a, b) hướng ra ngoài polygon."""
    (ax, az), (bx, bz) = seg
    n = math.hypot(bx - ax, bz - az) or 1.0
    nx, nz = (bz - az) / n, -(bx - ax) / n
    mid = ((ax + bx) / 2 + nx * 5, (az + bz) / 2 + nz * 5)
    return (-nx, -nz) if poly.contains(Point(mid)) else (nx, nz)


def plateaus(items, forest, rng):
    """Mỗi bục: tường đá liền dọc mép (bắc cao, nam thấp + khóm lá), cây trong bục (bắc cao, nam thấp)."""
    for poly in forest:
        for ring in [poly.exterior] + list(poly.interiors):
            coords = list(ring.coords)
            for a, b in zip(coords, coords[1:]):
                _edge_run(items, (a, b), _outward((a, b), poly), rng)
        _trees(items, poly, rng)


def _edge_run(items, seg, out, rng):
    (ax, az), (bx, bz) = seg
    length = math.hypot(bx - ax, bz - az)
    north, south = out[1] < -0.35, out[1] > 0.2  # mép hơi quay về nam (phía camera) đã tính là nam
    ang = -math.atan2(bz - az, bx - ax)
    d = 0.0
    while d < length:
        t = d / max(length, 1e-6)
        x, z = ax + (bx - ax) * t, az + (bz - az) * t
        if south:
            kind, step = rng.choice([("rock_low", 1.5), ("rock_low", 1.5), ("plant_orange", 1.0)])
        else:
            kind, step = rng.choice([("rock_tall", 1.3), ("rock_wide", 1.8)] if north else [("rock_wide", 1.8), ("rock_low", 1.5)])
        if rng.random() > 0.08:
            items.append([kind, x, z, ang + rng.uniform(-0.12, 0.12), rng.uniform(0.9, 1.15)])
        d += step * M * rng.uniform(0.85, 1.0)


def _trees(items, poly, rng):
    inner = poly.buffer(-TREE_INSET)
    if inner.is_empty:
        return
    x0, z0, x1, z1 = inner.bounds
    z = z0
    while z < z1:
        x = x0 + rng.uniform(0, TREE_STEP[0] * 0.5)
        while x < x1:
            p = Point(x + rng.uniform(-50, 50), z + rng.uniform(-50, 50))
            if inner.contains(p):
                t = (p.y - z0) / max(1.0, z1 - z0)  # 0 bắc → 1 nam
                kind = "pine_l" if t < 0.35 else ("pine_m" if t < 0.7 else "pine_s")
                if rng.random() < 0.14:
                    kind = rng.choice(["tree_round", "tree_autumn"])
                items.append([kind, p.x, p.y, rng.uniform(0, 6.28), rng.uniform(0.85, 1.1)])
            x += TREE_STEP[0]
        z += TREE_STEP[1]


def river(items, water, bank, rng):
    """Bờ sông: chỗ có đá bờ → cụm đá lệch cỡ / đá cuội (lún nửa ra phía nước); chỗ hở (lối xuống sông) →
    lau sậy + khóm cỏ; lá súng chỗ nước nông. Bờ nam (gần camera) chỉ vật thấp."""
    rocky = unary_union(bank).buffer(60) if bank else None
    for g in water:
        edge = g.exterior
        d = 0.0
        while d < edge.length - 100:
            p, q = edge.interpolate(d), edge.interpolate(d + 50)
            n = math.hypot(q.x - p.x, q.y - p.y) or 1.0
            tx, tz = (q.x - p.x) / n, (q.y - p.y) / n
            nx, nz = -tz, tx
            if g.contains(Point(p.x + nx * 60, p.y + nz * 60)):
                nx, nz = -nx, -nz
            frame = (tx, tz, nx, nz, nz > 0.4)
            d += _cluster(items, p, frame, rng) if rocky is not None and rocky.contains(p) else _reeds(items, p, frame, rng)
        for _ in range(int(edge.length / 900)):
            c = edge.interpolate(rng.uniform(0, edge.length))
            for _ in range(rng.randint(2, 4)):
                pt = Point(c.x + rng.uniform(-150, 150), c.y + rng.uniform(-150, 150))
                if g.buffer(-50).contains(pt):
                    items.append(["lily", pt.x, pt.y, rng.uniform(0, 6.28), rng.uniform(0.6, 1.1), 0.03])


def _cluster(items, p, frame, rng):
    tx, tz, nx, nz, south = frame
    k = rng.randint(2, 4)
    kinds = ["boulder_a", "boulder_b", "rock_small"] if south else ["boulder_a", "boulder_b", "boulder_a", "rock_low", "rock_wide"]
    for i in range(k):
        off = rng.uniform(-0.9, 0.7) * M
        x, z = p.x + tx * i * 110 + nx * off, p.y + tz * i * 110 + nz * off
        sink = -rng.uniform(0.25, 0.6) if off < -30 else 0.0
        items.append([rng.choice(kinds), x, z, -math.atan2(tz, tx) + rng.uniform(-0.4, 0.4), rng.uniform(0.55, 1.05), sink])
    return k * 110 + rng.uniform(40, 140)


def _reeds(items, p, frame, rng):
    tx, tz, nx, nz, south = frame
    span = rng.uniform(200, 360)
    for _ in range(rng.randint(3, 6)):
        a, o = rng.uniform(0, span), rng.uniform(-90, 10)
        items.append(["reeds", p.x + tx * a + nx * o, p.y + tz * a + nz * o, rng.uniform(0, 6.28), rng.uniform(0.7, 1.1)])
    for _ in range(rng.randint(1, 2)):
        a, o = rng.uniform(0, span), rng.uniform(50, 160)
        items.append([rng.choice(["grass_tuft", "grass_tuft", "plant_orange"]), p.x + tx * a + nx * o, p.y + tz * a + nz * o, rng.uniform(0, 6.28), rng.uniform(0.8, 1.1)])
    return span


def border(items, edge, size, rng):
    """MAP-12: rào đá đỉnh phẳng dọc mép rìa map (bỏ đoạn trùng khung), tường thành ngoài khung: bắc / tây / đông
    cao, nam thấp (camera ở nam)."""
    frame = box(0, 0, size, size).exterior
    for g in edge:
        coords = list(g.exterior.coords)
        for a, b in zip(coords, coords[1:]):
            seg = LineString([a, b])
            if seg.length < 40 or frame.distance(seg.interpolate(0.5, normalized=True)) < 40:
                continue
            _along(items, seg, "fence", FENCE_STEP)
    for x in np.arange(-WALL_STEP, size + 2 * WALL_STEP, WALL_STEP):
        items.append(["great_wall", x, -350.0, 0.0, 1.0])
        items.append(["wall_low", x, size + 150.0, 0.0, 1.0])
    for z in np.arange(-WALL_STEP, size + 2 * WALL_STEP, WALL_STEP):
        items.append(["great_wall", -350.0, z, math.pi / 2, 1.0])
        items.append(["great_wall", size + 350.0, z, math.pi / 2, 1.0])


def base_fences(items, rock_lines):
    """MAP-09 / MAP-10: rào base / fountain bằng đoạn rào đá cùng kiểu rìa map."""
    for line in rock_lines:
        if line.get("kind") == "fence":
            _along(items, LineString(line["points"]), "fence", FENCE_STEP)


def _along(items, line, kind, step):
    coords = list(line.coords)
    for a, b in zip(coords, coords[1:]):
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, math.ceil(length / step))
        ang = -math.atan2(b[1] - a[1], b[0] - a[0])
        for i in range(n):
            t = (i + 0.5) / n
            items.append([kind, a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, ang, 1.0])


def scatter(items, m, forest, wet, rng):
    """Khóm lá cam, khóm cỏ, đá nhỏ rải sát mép bục và mép lane (không trên lane, không trong nước / bục)."""
    size = m["world_size"][0]
    solid = unary_union(forest).buffer(30)
    lanes = unary_union([LineString(p).buffer(m["lane_width"] / 2 + 30) for p in m["lanes"].values()])
    lane_edge = lanes.buffer(150)
    near = solid.buffer(250)
    for _ in range(int(size * size / 160000)):
        p = Point(rng.uniform(0, size), rng.uniform(0, size))
        if solid.contains(p) or lanes.contains(p) or wet.buffer(60).contains(p):
            continue
        if (near.contains(p) or lane_edge.contains(p)) and rng.random() < 0.5:
            items.append([rng.choice(["plant_orange", "grass_tuft", "grass_tuft", "rock_small"]), p.x, p.y, rng.uniform(0, 6.28), rng.uniform(0.7, 1.0)])
