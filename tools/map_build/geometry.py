"""Hình bản đồ v3 (D-168) từ nguồn vector map_source.json, toạ độ guide (1 ô = `scale` đơn vị thế giới).

Nguồn ghi nửa Blue (y > x); build sinh nửa Red bằng xoay 180° (MAP-04). Vật cản gồm:
  forest      khối rừng (vẽ cây)
  mountains   khối núi đá (vẽ tảng đá lớn — nhẹ hơn cây); cả viền ngoài map là núi đá
  rock_lines  vách đá: đoạn thẳng nối nhau, cùng độ dày (vẽ mảnh vách nối tiếp)
  từ bản vẽ (D-171, D-176, from_sketch.py): mountains là đá bờ sông (MAP-07), forest là rừng cây (MAP-11),
  hốc bãi quái là khối đá hoặc rừng (MAP-08)
  fences      rào đá quanh base (chỉ hở ở 3 lane, MAP-09) và quanh fountain (một cổng, MAP-10)
Rồi cắt chỗ phải trống (lane, base, trụ, trại, điểm sinh, fountain, khu mid cắt sông MAP-05) và
lấp khe hẹp / hốc kín (MAP-03)."""
import math
from shapely.geometry import Polygon, LineString, Point, MultiLineString, box
from shapely.ops import unary_union, nearest_points

ROUND = dict(cap_style="round", join_style="round")
FLAT = dict(cap_style="flat", join_style="mitre", mitre_limit=2.0)


def rot(sym, pts):
    return [sym.rot(p) for p in pts]


def polys_of(g):
    if g.is_empty:
        return []
    return [p for p in getattr(g, "geoms", [g]) if p.geom_type == "Polygon" and p.area > 0.5]


def lines_of(g):
    if g.is_empty:
        return []
    return [l for l in getattr(g, "geoms", [g]) if l.geom_type == "LineString" and l.length > 0.5]


# ------------------------------------------------------------------ đối xứng
def mirrored_polys(sym, items):
    out = []
    for pts in items:
        out.append(Polygon(pts).buffer(0))
        out.append(Polygon(rot(sym, pts)).buffer(0))
    return out


def mirrored_lines(sym, items, default_width):
    out = []
    for it in items:
        w = it.get("width", default_width)
        out.append((LineString(it["points"]), w))
        out.append((LineString(rot(sym, it["points"])), w))
    return out


# ------------------------------------------------------------------ cung / vòng
def arc_line(pos, r, open_deg, gap_deg, n=24):
    """Cung tròn tâm `pos` bán kính r, hở `gap_deg` độ ở hướng `open_deg` (độ, 0 = +x, y hướng xuống)."""
    gap = math.radians(gap_deg)
    a0 = math.radians(open_deg) + gap / 2
    a1 = a0 + 2 * math.pi - gap
    return LineString([(pos[0] + r * math.cos(a0 + (a1 - a0) * k / n), pos[1] + r * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)])


def base_fence(base_poly, frame_poly, inset):
    """Rào quanh base: mép polygon base (lùi vào `inset`), bỏ phần chạy dọc mép khung map, đầu rào nối tới mép khung."""
    ring = base_poly.buffer(-inset, join_style="mitre").exterior
    return [to_frame(l, frame_poly, inset + 1.5) for l in lines_of(ring.difference(frame_poly.exterior.buffer(inset + 1.0)))]


def to_frame(line, frame_poly, reach):
    """Đầu đường cách mép khung không quá `reach` thì kéo thẳng ra tới mép (không để khe hẹp sát mép map, MAP-03)."""
    pts = list(line.coords)
    for end, prev in ((0, 1), (-1, -2)):
        p, q = Point(pts[end]), Point(pts[prev])
        if frame_poly.exterior.distance(p) <= reach:
            dx, dy = p.x - q.x, p.y - q.y
            n = math.hypot(dx, dy) or 1.0
            far = Point(p.x + dx / n * (reach + 2), p.y + dy / n * (reach + 2))
            hit = LineString([p, far]).intersection(frame_poly.exterior)
            if not hit.is_empty:
                h = hit if hit.geom_type == "Point" else nearest_points(hit, p)[0]
                pts[end] = (h.x, h.y)
    return LineString(pts)


# ------------------------------------------------------------------ viền map
def border_area(frame, b):
    fx0, fy0, fx1, fy1 = frame
    return box(fx0, fy0, fx1, fy1).difference(box(b["left"], b["top"], b["right"], b["bottom"]))


# ------------------------------------------------------------------ khu phải trống
def clear_zone(src, lanes, bases, towers, camps, extra_circles):
    parts = [LineString(l).buffer(src["lane_half_width"] + 1, **ROUND) for l in lanes.values()]
    parts += [Polygon(b["polygon"]) for b in bases]
    parts += [Point(t["pos"]).buffer(src["tower_clear_radius"]) for t in towers]
    parts += [Point(c["pos"]).buffer(src["camp_clear_radius"]) for c in camps]
    parts += [Point(p).buffer(r) for p, r in extra_circles]
    return unary_union(parts)


# ------------------------------------------------------------------ MAP-03
def readability(frame_poly, blocked, protect, fountain, gap_r):
    """Khe trống hẹp hơn 2·gap_r (trừ chỗ bảo vệ) và hốc kín không nối fountain → trả về phần lấp."""
    open_area = frame_poly.difference(blocked)
    opened = open_area.buffer(-gap_r, **ROUND).buffer(gap_r, **ROUND)
    narrow = open_area.difference(opened).difference(protect)
    narrow = unary_union([p for p in polys_of(narrow) if p.area > 1.0])
    open_area = frame_poly.difference(blocked.union(narrow))
    pockets = [p for p in polys_of(open_area)
               if not p.buffer(0.01).contains(Point(fountain)) and not p.intersects(protect)]
    return unary_union([narrow] + pockets)
