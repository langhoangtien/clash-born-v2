"""Quy tắc đặt cảnh vật D-178 (dùng bởi decor.py). Toạ độ thế giới px (100 px = 1 m); góc theo Godot:
Basis(UP, góc) — đoạn hướng (dx, dz) có góc = −atan2(dz, dx)."""
import math
import numpy as np
from PIL import Image, ImageFilter
from shapely.geometry import LineString, Point, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

M = 100.0  # px mỗi mét
# Bán kính bóng vẽ sẵn (m) theo mô hình.
SHADOW_R = {"pine_l": 1.4, "pine_m": 1.2, "pine_s": 1.0, "tree_round": 1.5, "tree_autumn": 1.6, "rock_tall": 1.0,
            "rock_wide": 1.2, "rock_low": 0.9, "rock_small": 0.5, "plant_orange": 0.4, "reeds": 0.35,
            "grass_tuft": 0.2, "plant_green": 0.4, "log": 0.5, "stump": 0.4, "totem": 0.45, "crystals": 0.6, "campfire": 0.5, "boulder_a": 0.8, "boulder_b": 0.55}
TREE_STEP = (1.6 * M, 1.45 * M) # lưới cây trong bục (D-179: dày hơn — bục nhìn kín)
TREE_INSET = 0.95 * M            # sau hàng đá viền (bề sâu ~1,1 m), tán cây chồng lên đỉnh đá


def ragged(img, blur_m, seed, mask_px=8.0):
    """Mép vùng tô răng cưa mềm như nét cọ: làm mờ, cộng nhiễu, cắt ngưỡng, làm mờ nhẹ lại."""
    a = np.array(img.filter(ImageFilter.GaussianBlur(blur_m * M / mask_px * 0.5))).astype(float)
    r = np.random.default_rng(seed)
    cells = max(4, img.size[0] // int(1.5 * M / mask_px))
    noise = np.array(Image.fromarray((r.random((cells, cells)) * 255).astype(np.uint8)).resize(img.size, Image.BICUBIC)).astype(float)
    hard = Image.fromarray((((a - 128) * 1.2 + (noise - 128) * 0.7) > 0).astype(np.uint8) * 255)
    return hard.filter(ImageFilter.GaussianBlur(0.25 * M / mask_px))


def plateaus(items, forest, rng):
    """Mỗi bục (D-179): tường đá liền dọc mép, mặt ngoài đá trùng mép vùng chặn (nhìn là chặn thì đúng là chặn,
    không hở khe). Camera ở nam nhìn chếch xuống: vật cao h che h·CAM_SPILL mét đất phía bắc sau nó, nên đá và
    cây chỉ cao tới mức không che lối đi phía bắc bục (mép nam bục dày thành vách cao, mép bắc đá thấp)."""
    for poly in forest:
        poly = orient(poly, 1.0)  # vòng ngoài ngược kim, lỗ xuôi kim: trong bục luôn ở bên trái chiều đi
        for ring in [poly.exterior] + list(poly.interiors):
            _edge_run(items, ring, poly, rng)
        _trees(items, poly, rng)


# Bề sâu / chiều cao đá viền (m, theo style_kit.slab): tâm đá lùi vào trong bục nửa bề sâu.
ROCK_DEPTH = {"rock_tall": 1.1, "rock_wide": 1.2, "rock_low": 1.1}
ROCK_H = {"rock_tall": 2.4, "rock_wide": 1.8, "rock_low": 1.1}
ROCK_STEP = {"rock_tall": 1.2, "rock_wide": 1.7, "rock_low": 1.4}
TANGENT = 40.0  # px: lấy hướng mép từ hai điểm cách nhau chừng này (mép build_map gồm nhiều đoạn ngắn)


def _edge_run(items, ring, poly, rng):
    """Rải đá đều theo độ dài cả vòng mép (không theo từng đoạn — đoạn ngắn làm đá dồn cục). Đá cao nhất vừa
    khoảng trống phía bắc (như cây): mép nam bục dày thành vách cao, mép bắc / vách mảnh đá thấp."""
    d = rng.uniform(0, 60)
    while d < ring.length:
        p, q = ring.interpolate(d - TANGENT / 2), ring.interpolate(d + TANGENT / 2)
        n = math.hypot(q.x - p.x, q.y - p.y) or 1.0
        tx, tz = (q.x - p.x) / n, (q.y - p.y) / n
        out = (tz, -tx)  # bên phải chiều đi = ngoài bục
        c = ring.interpolate(d)
        sc = rng.uniform(0.95, 1.15)
        kind = "rock_low"
        for back in (0.6 * M * sc, 0.3 * M * sc):
            at = Point(c.x - out[0] * back, c.y - out[1] * back)
            if poly.contains(at):  # bục mảnh / mũi nhọn: lùi ít hơn, vẫn phải trong bục
                kind = _rock_kind(_north_room(poly, at), sc, rng)
                items.append([kind, at.x, at.y, -math.atan2(tz, tx) + rng.uniform(-0.08, 0.08), sc])
                if out[1] < -0.35 and rng.random() < 0.3:  # khóm lá cam trước đá thấp mép bắc (trong bục)
                    items.append(["plant_orange", at.x - out[0] * 90, at.y - out[1] * 90, rng.uniform(0, 6.28), rng.uniform(0.9, 1.1)])
                break
        d += ROCK_STEP[kind] * M * rng.uniform(0.8, 0.92)


def _rock_kind(room, sc, rng):
    fit = lambda k: ROCK_H[k] * sc * CAM_SPILL <= room / M + TREE_SPILL
    if fit("rock_tall"):
        return rng.choice(["rock_tall", "rock_wide"])
    if fit("rock_wide"):
        return rng.choice(["rock_wide", "rock_low"])
    return "rock_low"


# Chiều cao cây (m, style_kit) — cây cao h·cỡ chỉ đặt khi cách mép bắc ≥ h·cỡ·CAM_SPILL − TREE_SPILL.
TREE_H = {"pine_l": 5.6, "pine_m": 4.4, "tree_autumn": 3.6, "pine_s": 3.2, "tree_round": 3.2}
CAM_SPILL = 0.97   # camera chúc ~46°: vật cao 1 m che ~0,97 m đất sau nó
TREE_SPILL = 1.0   # cho tán che lấn ra ngoài bục tối đa 1 m (chưa tới đầu tướng)


def _trees(items, poly, rng):
    inner = poly.buffer(-TREE_INSET)
    if inner.is_empty:
        inner = poly.buffer(-TREE_INSET * 0.5)  # bục mảnh: vẫn có cây giữa, không trống như lối đi
    if inner.is_empty:
        return
    x0, z0, x1, z1 = inner.bounds
    z = z0
    while z < z1:
        x = x0 + rng.uniform(0, TREE_STEP[0] * 0.5)
        while x < x1:
            p = Point(x + rng.uniform(-50, 50), z + rng.uniform(-50, 50))
            if inner.contains(p):
                _tree(items, p, _north_room(poly, p), rng)
            x += TREE_STEP[0]
        z += TREE_STEP[1]


def _tree(items, p, room, rng):
    """Cây cao nhất vừa chỗ (ưu tiên thông, thỉnh thoảng cây tán tròn); không vừa thì khóm lá thấp."""
    sc = rng.uniform(0.85, 1.1)
    fits = [k for k, h in TREE_H.items() if h * sc * CAM_SPILL <= room / M + TREE_SPILL]
    if not fits:
        if rng.random() < 0.5:
            items.append(["plant_orange", p.x, p.y, rng.uniform(0, 6.28), rng.uniform(0.9, 1.1)])
        return
    kind = fits[0]
    if rng.random() < 0.14 and any(k.startswith("tree") for k in fits):
        kind = rng.choice([k for k in fits if k.startswith("tree")])
    items.append([kind, p.x, p.y, rng.uniform(0, 6.28), sc])


def _north_room(poly, p):
    """Khoảng (px) từ p đi thẳng về bắc (−z) tới mép bục."""
    hit = LineString([(p.x, p.y), (p.x, p.y - 3000)]).intersection(poly.boundary)
    pts = [hit] if hit.geom_type == "Point" else list(getattr(hit, "geoms", []))
    return min((p.y - q.y for q in pts if q.geom_type == "Point"), default=0.0)


def river(items, water, bank, rng):
    """Bờ sông (D-198): đá CHỈ đặt trong đúng vùng chặn bờ sông (bank_rocks); mép nước không có đá chặn (lối xuống
    sông) → lau sậy + khóm cỏ; lá súng chỗ nước nông. Lỗi chơi thử D-197: đá rải theo mép nước nằm cả chỗ đi
    được, còn chỗ chặn thì trống."""
    rocky = unary_union(bank).buffer(40) if bank else Point(-1e9, -1e9).buffer(1)
    bank_rocks(items, bank, rng)
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
            d += 120 if rocky.contains(p) else _reeds(items, p, (tx, tz, nx, nz, nz < -0.4), rng)
        for _ in range(int(edge.length / 900)):
            c = edge.interpolate(rng.uniform(0, edge.length))
            for _ in range(rng.randint(2, 4)):
                pt = Point(c.x + rng.uniform(-150, 150), c.y + rng.uniform(-150, 150))
                if g.buffer(-50).contains(pt):
                    items.append(["lily", pt.x, pt.y, rng.uniform(0, 6.28), rng.uniform(0.6, 1.1), 0.03])


# D-198: đá lấp vùng chặn bờ sông — lưới lệch BANK_STEP px, chỉ điểm nằm sâu trong vùng chặn; cỡ nhỏ để không
# tràn ra chỗ đi được (bán kính mô hình × cỡ ≲ khoảng cách tới mép vùng chặn + BANK_SPILL).
BANK_STEP = 80.0
BANK_SPILL = 25.0
BANK_KINDS = [("boulder_b", 70.0), ("boulder_a", 100.0), ("rock_low", 75.0), ("rock_small", 40.0)]  # (mô hình, bán kính px ở cỡ 1)


def bank_rocks(items, bank, rng):
    for g in bank:
        x0, z0, x1, z1 = g.bounds
        z, row = z0, 0
        while z < z1:
            x = x0 + (BANK_STEP * 0.5 if row % 2 else 0.0)
            while x < x1:
                p = Point(x + rng.uniform(-15, 15), z + rng.uniform(-15, 15))
                room = g.exterior.distance(p) if g.contains(p) else -1.0
                if room > 12:
                    kind, r = rng.choice(BANK_KINDS)
                    sc = min(rng.uniform(0.75, 1.1), (room + BANK_SPILL) / r)
                    if sc > 0.3:
                        items.append([kind, p.x, p.y, rng.uniform(0, 6.28), sc, -0.05])
                x += BANK_STEP
            z += BANK_STEP * 0.87
            row += 1


def _reeds(items, p, frame, rng):
    tx, tz, nx, nz, _low = frame
    span = rng.uniform(200, 360)
    for _ in range(rng.randint(3, 6)):
        a, o = rng.uniform(0, span), rng.uniform(-90, 10)
        items.append(["reeds", p.x + tx * a + nx * o, p.y + tz * a + nz * o, rng.uniform(0, 6.28), rng.uniform(0.7, 1.1)])
    for _ in range(rng.randint(1, 2)):
        a, o = rng.uniform(0, span), rng.uniform(50, 160)
        items.append([rng.choice(["grass_tuft", "grass_tuft", "plant_orange"]), p.x + tx * a + nx * o, p.y + tz * a + nz * o, rng.uniform(0, 6.28), rng.uniform(0.8, 1.1)])
    return span


def along(items, line, kind, step):
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
