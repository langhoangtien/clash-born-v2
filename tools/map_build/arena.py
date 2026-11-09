"""D-308: bãi đấu boss — sân tròn, vòng tường đá ghép từ các đoạn cung giống hệt nhau (mô hình arena_wall_arc), chừa
cửa: một cửa quay ra sông (hướng điểm sông gần nhất), một cửa đối diện. Toạ độ guide.

map_source `arenas`: [{"camp": id trại, "pos": [x, y], "r": bán kính tim tường, "thick": bề dày tường, "slots": số
đoạn cung một vòng}] — ghi đủ cả hai bãi (không tự xoay). Tường là vật cản (lớp `cliffs`, MAP-01); sân + cửa là khu trống.
"""
import math
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union, nearest_points


def specs(src, river):
    out = []
    for a in src.get("arenas", []):
        q = nearest_points(Point(a["pos"]), river)[1]
        gate = math.atan2(q.y - a["pos"][1], q.x - a["pos"][0])
        step = 2 * math.pi / a["slots"]
        gates = {0, a["slots"] // 2}  # cửa sông + cửa đối diện
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
    """Khu trống: sân trong tường + hai cửa mở rộng ra ngoài."""
    c, r, t, h = spec["pos"], spec["r"], spec["thick"], spec["step"] / 2
    parts = [Point(c).buffer(r - t / 2, 64)]  # rừng áp sát mặt ngoài tường (dải trống mảnh = khe dễ hiểu nhầm, MAP-03)
    for a in (spec["gate"], spec["gate"] + math.pi):
        parts.append(_sector(c, r + t + extra, a - h, a + h))
    return unary_union(parts)


def export(spec, W, scale):
    """Dữ liệu cho decor.py / VIEW: tâm, bán kính tim tường (thế giới), góc giữa từng đoạn tường và hai cửa."""
    return {"camp": spec["camp"], "pos": W(spec["pos"]), "r": round(spec["r"] * scale, 1),
            "thick": round(spec["thick"] * scale, 1), "step": round(spec["step"], 5),
            "walls": [round(a, 5) for a in spec["walls"]], "gates": [round(spec["gate"], 5), round(spec["gate"] + math.pi, 5)]}


# Cỡ mô hình (m) — assets/models/style/arena_*.glb: đoạn tường đã uốn đúng mét (bend_arc.py), vật khác chuẩn hoá cạnh
# lớn nhất = 1 nên nhân cỡ ở đây.
RUNE_SCALE, ARCH_SCALE, BANNER_SCALE = 1.5, 2.8, 2.4


def decor_items(items, m):
    """D-308: đặt mô hình bãi đấu vào danh sách vật của decor.py ([loại, x, z, góc, cỡ]; góc Godot Basis(UP, góc))."""
    for a in m.get("arenas", []):
        cx, cz = a["pos"]
        r, t, h = a["r"], a["thick"], a["step"] / 2
        # tâm hộp bao đoạn cung (MultiMesh đặt gốc mô hình ở giữa hộp bao): giữa r_trong·cos(h) và r_ngoài
        mid = ((r - t / 2) * math.cos(h) + (r + t / 2)) / 2
        for ang in a["walls"]:
            dx, dz = math.cos(ang), math.sin(ang)
            items.append(("arena_wall_arc", cx + dx * mid, cz + dz * mid, -math.atan2(dz, dx), 1.0))
        river_gate, far_gate = a["gates"]
        for side in (-1, 1):  # trụ rune hai bên cửa sông, mặt khắc quay ra ngoài
            ang = river_gate + side * (h + 0.1)
            dx, dz = math.cos(ang), math.sin(ang)
            items.append(("arena_rune_stone", cx + dx * (r + t), cz + dz * (r + t), math.atan2(dx, dz), RUNE_SCALE))
        dx, dz = math.cos(far_gate), math.sin(far_gate)  # cổng vòm đổ ở cửa phía rừng
        items.append(("arena_arch", cx + dx * r, cz + dz * r, math.atan2(dx, dz), ARCH_SCALE))
        for k in (2, 6):  # cột cờ sát tường trong sân, mặt cờ quay vào giữa
            ang = river_gate + k * a["step"] + h * 0.6
            dx, dz = math.cos(ang), math.sin(ang)
            items.append(("arena_banner", cx + dx * (r - t), cz + dz * (r - t), math.atan2(-dx, -dz), BANNER_SCALE))


KEEP_INSIDE = ("grass_tuft", "plant_orange")  # cỏ / hoa nhỏ được mọc trong sân


def clear_items(items, m):
    """Bỏ vật của decor (cây, đá, lau sậy…) trong sân và trên dải tường — chỗ đó chỉ còn đồ bãi đấu."""
    out = []
    for it in items:
        inside = any(math.dist(a["pos"], (it[1], it[2])) < a["r"] + a["thick"] / 2 + 40 for a in m.get("arenas", []))
        if not inside or it[0] in KEEP_INSIDE:
            out.append(it)
    items[:] = out
