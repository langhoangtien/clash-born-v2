"""D-176: khối bản vẽ → đá (bờ sông) + rừng cây (còn lại), lối rừng rộng hơn, khe xuyên khối rừng lớn.

Toạ độ guide (1 ô = scale đơn vị thế giới). Gọi từ from_sketch.py sau shape_blocks."""
import math
from shapely.geometry import LineString, Point
from shapely.ops import unary_union

BANK_ROCK = 7.0      # dải đá ven sông: phần khối cách nước ≤ chừng này (ô guide) là đá (MAP-07)
FOREST_SHRINK = 6.0  # khối rừng thu thêm mỗi phía (ô guide) — lối rừng rộng hơn đá (MAP-11)
FOREST_ROUND = 3.0   # bo tròn khối rừng sau khi thu (ô guide)
FOREST_MIN_AREA = 40.0  # mảnh rừng nhỏ hơn (ô guide²) thì bỏ
GAP_AREA = 1400.0    # khối rừng lớn hơn (ô guide²) thì cắt khe (MAP-11)
GAP_WIDTH = 10.0     # bề rộng khe (ô guide) = 160 đơn vị
GAP_ANGLES = 36      # số hướng thử khi tìm khe
GAP_STEP = 6.0       # lưới tâm thử khi tìm khe (ô guide)
GAP_SPLIT = 0.2      # khe phải chia khối: phần nhỏ hơn ≥ chừng này diện tích khối
GAP_ROUNDS = 3       # số lượt cắt (phần còn lớn sau một khe thì cắt tiếp)
EDGE = 6.0           # khối cách khung map dưới chừng này (ô guide) là rìa map: không thu
HOOK_R = 26.0        # quanh trại trong bán kính này (ô guide) rừng không thu: giữ hốc trại (MAP-08)
CAMP_GAP_R = 14.0    # khe không đi gần tâm trại hơn chừng này (ô guide): khe vào trại chỉ là thêm cửa


def hooks(camps, r=HOOK_R):
    """Vùng quanh trại bán kính `r` (ô guide)."""
    return unary_union([Point(c).buffer(r) for c in camps])


def split(blocks, water, frame, hook, min_thick):
    """Khối chạm sông: phần ven nước là đá, phần còn lại là rừng. Khối khác: rừng. Rừng thu FOREST_SHRINK,
    trừ khối rìa map (sát khung, để ngoài lane vẫn kín) và phần trong `hook` (hốc trại)."""
    band = water.buffer(BANK_ROCK)
    rocks, forest = [], []
    for g in blocks:
        rock = g.intersection(band) if g.distance(water) < 1.5 else None
        wood = g if g.distance(frame.exterior) < EDGE else g.buffer(-FOREST_SHRINK, join_style="round").union(g.intersection(hook))
        if rock is not None and not rock.is_empty:
            rocks += _polys(rock, 4.0)
            wood = wood.difference(rock)
        wood = wood.buffer(-FOREST_ROUND, join_style="round").buffer(FOREST_ROUND, join_style="round")
        forest += [p for p in _polys(wood, FOREST_MIN_AREA) if 2 * p.area / p.length >= min_thick]
    return rocks, forest


def cut_gaps(forest, rocks, open_area, frame, camp_core):
    """Khối rừng lớn (trừ rìa map): cắt khe thẳng ngắn nhất, hai đầu ra đất trống `open_area` (không đâm
    vào đá, khối khác, ngoài map), không qua lòng trại `camp_core`; phần còn lớn thì cắt tiếp."""
    gaps = []
    for _ in range(GAP_ROUNDS):
        out, cut = [], False
        for i, p in enumerate(forest):
            big = p.area > GAP_AREA and p.distance(frame.exterior) >= EDGE
            slit = _best_slit(p, unary_union(rocks + forest[:i] + forest[i + 1:] + out), open_area, camp_core) if big else None
            if slit is None:
                out.append(p)
                continue
            gaps.append(slit)
            cut = True
            out += _polys(p.difference(slit.buffer(GAP_WIDTH / 2, cap_style="flat")), FOREST_MIN_AREA)
        forest = out
        if not cut:
            break
    return forest, gaps


def _best_slit(p, others, open_area, camp_core):
    """Khe ngắn nhất (thử tâm trên lưới trong khối × GAP_ANGLES hướng) chia khối thành hai phần,
    phần nhỏ ≥ GAP_SPLIT diện tích."""
    best = None
    for c in _centers(p):
        for k in range(GAP_ANGLES):
            part = _chord(p, c, math.pi * k / GAP_ANGLES)
            if part is None or (best is not None and part.length >= best.length):
                continue
            if part.buffer(GAP_WIDTH / 2).intersects(camp_core) or not _opens(part, c, others, open_area):
                continue
            pieces = _polys(p.difference(part.buffer(GAP_WIDTH / 2, cap_style="flat")), 0.0)
            if len(pieces) >= 2 and sorted(q.area for q in pieces)[-2] >= GAP_SPLIT * p.area:
                best = part
    return best


def _centers(p):
    x0, y0, x1, y1 = p.bounds
    pts = [Point(x0 + i * GAP_STEP, y0 + j * GAP_STEP) for i in range(int((x1 - x0) / GAP_STEP) + 1) for j in range(int((y1 - y0) / GAP_STEP) + 1)]
    return [q for q in pts if p.contains(q)]


def _chord(p, c, a):
    """Đoạn của đường qua `c` hướng `a` nằm trong khối, chứa `c`."""
    r = math.hypot(p.bounds[2] - p.bounds[0], p.bounds[3] - p.bounds[1])
    d = (math.cos(a) * r, math.sin(a) * r)
    inside = LineString([(c.x - d[0], c.y - d[1]), (c.x + d[0], c.y + d[1])]).intersection(p)
    part = next((s for s in getattr(inside, "geoms", [inside]) if s.distance(c) < 1e-6), None)
    return part if part is not None and part.geom_type == "LineString" else None


def _opens(part, c, others, open_area):
    """Hai đầu khe ra đất trống (không đâm vào đá / khối khác / ngoài map)."""
    ends = [_step_out(Point(q), c, 3.0) for q in (part.coords[0], part.coords[-1])]
    return all(open_area.contains(q) and others.distance(q) >= GAP_WIDTH / 2 + 1 for q in ends)


def _step_out(end, center, dist):
    dx, dy = end.x - center.x, end.y - center.y
    n = math.hypot(dx, dy) or 1.0
    return Point(end.x + dx / n * dist, end.y + dy / n * dist)


def _polys(g, min_area):
    return [q for q in getattr(g, "geoms", [g]) if q.geom_type == "Polygon" and q.area >= min_area]
