"""Hình bản đồ v3 (D-168) từ nguồn vector map_source.json, toạ độ guide (1 ô = `scale` đơn vị thế giới).

Nguồn ghi nửa Blue (y > x); hàm `expand` sinh nửa Red bằng xoay 180° (MAP-04). Vật cản gồm:
  forest      khối rừng (vẽ cây)
  rocks       khối đá (vẽ cụm đá — nhẹ hơn cây)
  rock_lines  vách đá: đoạn thẳng nối nhau, cùng độ dày (vẽ mảnh vách đá nối tiếp)
  alcoves     hốc đá quanh trại rừng: cung vách mở về phía `open`
  river_bank  vách kín hai bờ sông, chừa lối xuống (`openings`, vẽ bậc thang)
  border      viền ngoài map (rừng, mép trong có vách đá)
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


# ------------------------------------------------------------------ hốc đá trại rừng
def alcove_line(pos, cfg, defaults):
    """Cung vách quanh trại: tâm `pos`, bán kính r, mở `span_open` độ về hướng `open` (độ, 0 = +x, y xuống)."""
    r = cfg.get("r", defaults["r"])
    gap = math.radians(cfg.get("gap", defaults["gap"]))
    a0 = math.radians(cfg["open"]) + gap / 2
    a1 = a0 + 2 * math.pi - gap
    n = 14
    pts = [(pos[0] + r * math.cos(a0 + (a1 - a0) * k / n), pos[1] + r * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]
    return LineString(pts)


# ------------------------------------------------------------------ bờ sông
def bank_lines(river, cfg, sym, mid_zone):
    """Vách hai bờ: đường bao sông nới `offset`, bỏ đoạn ở lối xuống (nửa Blue + bản xoay) và khu mid."""
    ring = unary_union([p.buffer(cfg["offset"], join_style="mitre").exterior for p in river])
    holes = []
    stairs = []
    for o in cfg["openings"]:
        for c in (o, sym.rot(o[:2]) + o[2:]):
            q = nearest_points(ring, Point(c[0], c[1]))[0]
            r = c[2] if len(c) > 2 else cfg["opening_r"]
            holes.append(Point(q.x, q.y).buffer(r))
            stairs.append((q.x, q.y, _tangent(ring, q)))
    cut = unary_union(holes + [mid_zone])
    lines = lines_of(ring.difference(cut).simplify(cfg.get("simplify", 1.0)))
    return lines, stairs


def _tangent(ring, q):
    rings = getattr(ring, "geoms", [ring])
    best = min(rings, key=lambda r: r.distance(q))
    d = best.project(q)
    a = best.interpolate(max(0.0, d - 1.0))
    b = best.interpolate(min(best.length, d + 1.0))
    return math.atan2(b.y - a.y, b.x - a.x)


# ------------------------------------------------------------------ viền map
def border_area(frame, b):
    fx0, fy0, fx1, fy1 = frame
    return box(fx0, fy0, fx1, fy1).difference(box(b["left"], b["top"], b["right"], b["bottom"]))


def border_line(b):
    return LineString([(b["left"], b["top"]), (b["right"], b["top"]), (b["right"], b["bottom"]),
                       (b["left"], b["bottom"]), (b["left"], b["top"])])


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
