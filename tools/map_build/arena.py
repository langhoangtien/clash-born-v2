"""D-308: bãi đấu boss — sân tròn, vòng tường đá (D-313: dựng bằng đá chung của map), chừa
cửa: D-314 chỉ một cửa quay ra sông (hướng điểm sông gần nhất). Toạ độ guide.

map_source `arenas`: [{"camp": id trại, "pos": [x, y], "r": bán kính tim tường, "thick": bề dày tường, "slots": số
đoạn cung một vòng}] — ghi đủ cả hai bãi (không tự xoay). Tường là vật cản (lớp `cliffs`, MAP-01); sân + cửa là khu trống.
"""
import math, random
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union, nearest_points


def specs(src, river):
    out = []
    for a in src.get("arenas", []):
        q = nearest_points(Point(a["pos"]), river)[1]
        gate = math.atan2(q.y - a["pos"][1], q.x - a["pos"][0])
        step = 2 * math.pi / a["slots"]
        gates = {0}  # D-314: chỉ một cửa ra sông (người chơi: chặn lối từ rừng vào)
        walls = [gate + k * step for k in range(a["slots"]) if k not in gates]
        out.append(dict(a, gate=gate, step=step, walls=walls))
    return out


def _sector(c, r, a0, a1, n=12):
    return Polygon([c] + [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)])


def walls(spec, river):
    """Đa giác tường (mỗi đoạn một mảnh vành khuyên), bỏ phần nằm dưới sông."""
    c, r, t, h = spec["pos"], spec["r"], spec["thick"], spec["step"] / 2
    ring = Point(c).buffer(r + t / 2, 64).difference(Point(c).buffer(r - t / 2, 64))
    return [ring.intersection(_sector(c, r * 2, a - h, a + h)).difference(river) for a in spec["walls"]]


def clear(spec, extra=8.0):
    """Khu trống: sân trong tường + cửa sông mở rộng ra ngoài."""
    c, r, t, h = spec["pos"], spec["r"], spec["thick"], spec["step"] / 2
    parts = [Point(c).buffer(r - t / 2, 64)]  # rừng áp sát mặt ngoài tường (dải trống mảnh = khe dễ hiểu nhầm, MAP-03)
    parts.append(_sector(c, r + t + extra, spec["gate"] - h, spec["gate"] + h))  # D-314: một cửa ra sông
    return unary_union(parts)


def export(spec, W, scale):
    """Dữ liệu cho decor.py / VIEW: tâm, bán kính tim tường (thế giới), góc giữa từng đoạn tường và hai cửa."""
    return {"camp": spec["camp"], "pos": W(spec["pos"]), "r": round(spec["r"] * scale, 1),
            "thick": round(spec["thick"] * scale, 1), "step": round(spec["step"], 5),
            "walls": [round(a, 5) for a in spec["walls"]], "gates": [round(spec["gate"], 5)]}


# D-313: vòng tường dựng bằng đá chung của map (bộ style_kit: rock_tall / rock_wide / rock_low / boulder — cùng vân
# rock_face, cùng tông lạnh D-312), không còn mô hình Tripo riêng (arena_*). D-314: cao nhất ở điểm đối diện cửa sông,
# thấp dần về hai bên cửa; cung quay về camera (nam, +z) hạ bớt cho khỏi che boss. Hàng đá cao phía sau (trong vùng chặn).
ROCK_GAP = 80.0     # khoảng cách hai tảng dọc tim tường (px)
BACK_OUT = 115.0    # hàng đá sau cách tim tường (px)
SOUTH_CAP = 0.45    # cung phía nam hạ chiều cao tối đa 45%


def _put(items, kind, cx, cz, ang, dist, face, scale):
    """Vật tại góc `ang`, cách tâm `dist`; `face`: góc Godot Basis(UP, góc)."""
    items.append((kind, cx + math.cos(ang) * dist, cz + math.sin(ang) * dist, face, scale))


def _level(ang, a):
    """0 ở mép cửa → 1 ở điểm đối diện cửa; hạ ở cung phía nam."""
    h = a["step"] / 2
    gd = min(abs(math.remainder(ang - g, math.tau)) for g in a["gates"]) - h
    return max(0.0, min(1.0, gd / (math.pi - h))) ** 0.8 * (1 - SOUTH_CAP * max(0.0, math.sin(ang)))


def _rock(level, rng):
    if level > 0.62:
        return "rock_tall", 0.8 + 0.45 * level
    if level > 0.3:
        return rng.choice(("rock_wide", "rock_tall")), 0.65 + 0.3 * level
    return rng.choice(("rock_low", "boulder_a", "boulder_b")), 0.55 + 0.35 * level


def decor_items(items, m, solid):
    """Đá vòng tường + hàng đá sau + cỏ / đá vụn chân tường. `solid`: vùng chặn (hàng sau chỉ đặt trong đó)."""
    for n, a in enumerate(m.get("arenas", [])):
        rng = random.Random(308 + n)
        cx, cz = a["pos"]
        r, h = a["r"], a["step"] / 2
        for ang in a["walls"]:
            k = max(2, round(2 * h * r / ROCK_GAP))
            for i in range(k):
                t = ang - h + 2 * h * (i + 0.5) / k + rng.uniform(-0.02, 0.02)
                level = _level(t, a)
                kind, sc = _rock(level, rng)
                d = r + rng.uniform(-12, 12)
                if not solid.contains(Point(cx + math.cos(t) * d, cz + math.sin(t) * d)):
                    continue  # đoạn tường bị sông cắt: không vật cản thì không đặt đá (D-179, D-198)
                _put(items, kind, cx, cz, t, d, rng.uniform(0, 6.28), sc * rng.uniform(0.92, 1.08))
                if level > 0.45 and math.sin(t) < 0.35 and i % 2 == 0:
                    bx, bz = cx + math.cos(t) * (r + BACK_OUT), cz + math.sin(t) * (r + BACK_OUT)
                    if solid.contains(Point(bx, bz)):
                        items.append(("rock_tall", bx, bz, rng.uniform(0, 6.28), 1.0 + 0.45 * level))
        for _ in range(16):  # cỏ, dương xỉ, đá vụn sát chân tường trong sân
            ang = rng.uniform(0, 6.283)
            kind = rng.choice(("grass_tuft", "grass_tuft", "plant_green", "rock_small"))
            _put(items, kind, cx, cz, ang, r - rng.uniform(70, 130), rng.uniform(0, 6.28), rng.uniform(0.7, 1.0))


KEEP_INSIDE = ()  # cỏ / hoa nhỏ được mọc trong sân


def clear_items(items, m):
    """Bỏ vật của decor (cây, đá, lau sậy…) trong sân, trên dải tường và chỗ hàng đá sau — chỗ đó chỉ còn đồ bãi đấu."""
    out = []
    for it in items:
        inside = any(math.dist(a["pos"], (it[1], it[2])) < a["r"] + BACK_OUT + 90 for a in m.get("arenas", []))
        if not inside or it[0] in KEEP_INSIDE:
            out.append(it)
    items[:] = out
