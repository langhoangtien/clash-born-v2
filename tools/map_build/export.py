"""Xuất map (D-168): mảnh va chạm không lỗ, trường khoảng trống (MAP-01), kiểm tra đi được, JSON, ảnh xem trước."""
import base64, json
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from shapely.geometry import Polygon, box

UP = 4             # siêu mẫu khi raster (ô guide → UP điểm ảnh)
CLEAR_UNIT = 4.0   # đơn vị thế giới mỗi byte khoảng trống
HERO_R = 32 + 8    # bán kính hero + lề, khi kiểm tra đi được


def split_holes(poly, depth=0):
    """Mảnh va chạm không có lỗ: cắt dọc qua từng lỗ cho tới khi hết."""
    if poly.is_empty:
        return []
    if poly.geom_type == "MultiPolygon":
        return [q for g in poly.geoms for q in split_holes(g, depth)]
    if not poly.interiors or depth > 12:
        return [poly]
    hx = Polygon(poly.interiors[0]).representative_point().x
    minx, miny, maxx, maxy = poly.bounds
    out = []
    for part in (poly.intersection(box(minx - 1, miny - 1, hx, maxy + 1)), poly.intersection(box(hx, miny - 1, maxx + 1, maxy + 1))):
        for g in getattr(part, "geoms", [part]):
            if g.geom_type == "Polygon" and g.area > 0.5:
                out.extend(split_holes(g, depth + 1))
    return out


def collision_pieces(blocked):
    out = []
    for g in getattr(blocked, "geoms", [blocked]):
        for piece in split_holes(g.buffer(0)):
            piece = piece.simplify(0.25, preserve_topology=True)
            if piece.area > 0.8 and piece.geom_type == "Polygon":
                out.append(piece)
    return out


def clearance(collision, frame, scale):
    """Khoảng cách tới vật cản gần nhất, min theo từng ô guide (thận trọng), đơn vị CLEAR_UNIT."""
    fx0, fy0, fx1, fy1 = frame
    n = fx1 - fx0
    occ = np.zeros((n * UP, n * UP), np.uint8)
    for p in collision:
        cv2.fillPoly(occ, [np.round((np.array(p.exterior.coords) - [fx0, fy0]) * UP - 0.5).astype(np.int32)], 1)
    occ[0, :] = occ[-1, :] = occ[:, 0] = occ[:, -1] = 1
    dist = ndi.distance_transform_edt(occ == 0) * (scale / UP)
    pooled = dist.reshape(n, UP, n, UP).min(axis=(1, 3))
    return np.clip(np.floor(pooled / CLEAR_UNIT), 0, 255).astype(np.uint8)


def validate(clear, src, W, scale):
    """Lỗi nếu điểm quan trọng không tới được từ fountain Blue (MAP-02) hoặc quá chật."""
    n = clear.shape[0]
    walk = clear.astype(float) * CLEAR_UNIT >= HERO_R
    gy, gx = np.mgrid[0:n, 0:n]
    for t in src["towers"]:
        wx, wy = W(t["pos"])
        walk &= ((gx + 0.5 - wx / scale) ** 2 + (gy + 0.5 - wy / scale) ** 2) >= ((52 + HERO_R) / scale) ** 2
    errors = []
    fx, fy = (int(v / scale) for v in W(src["fountains"][0]))
    if not walk[fy, fx]:
        return ["Blue fountain is not walkable for a hero"], walk
    lab = ndi.label(walk)[0]
    reach = lab == lab[fy, fx]

    def near(p, rad):
        wx, wy = W(p)
        cx, cy, r = wx / scale, wy / scale, rad / scale
        return reach[int(max(0, cy - r)):int(min(n, cy + r + 1)), int(max(0, cx - r)):int(min(n, cx + r + 1))].any()

    checks = [("red fountain", src["fountains"][1], 40)]
    checks += [(f"lane {k} waypoint {i}", p, 40) for k, l in src["lanes"].items() for i, p in enumerate(l)]
    checks += [(f"lane spawn {t}/{k}", p, 40) for t in ("0", "1") for k, p in src["lane_spawns"][t].items()]
    checks += [(f"tower {t['id']} approach", t["pos"], 252) for t in src["towers"]]
    checks += [(f"camp {c['id']}", c["pos"], 60) for c in src["camps"]]
    checks += [(f"core {i} approach", p, 265) for i, p in enumerate(src["cores"])]
    checks += [(f"ramp {i}", (r[0], r[1]), 60) for i, r in enumerate(src["stairs"])]
    errors += ["Unreachable: " + name for name, p, rad in checks if not near(p, rad)]
    for k, l in src["lanes"].items():
        for i, p in enumerate(l):
            wx, wy = W(p)
            if clear[int(wy / scale), int(wx / scale)] * CLEAR_UNIT < 40:
                errors.append(f"Lane {k} waypoint {i} too tight")
    for i, p in enumerate(src["fountains"]):
        wx, wy = W(p)
        if clear[int(wy / scale), int(wx / scale)] * CLEAR_UNIT < 200:
            errors.append(f"Fountain {i} too tight")
    return errors, walk & ~reach


def poly_world(p, W):
    return [W(q) for q in list(p.exterior.coords)[:-1]]


def render_polys(polys, W):
    out = []
    for g in polys:
        e = {"outer": poly_world(g, W)}
        if g.interiors:
            e["holes"] = [[W(q) for q in list(h.coords)[:-1]] for h in g.interiors]
        out.append(e)
    return out


def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))


def clearance_block(clear, scale):
    n = clear.shape[0]
    return {"width": n, "height": n, "pixel_world": scale, "unit_world": CLEAR_UNIT,
            "bytes_base64": base64.b64encode(clear.tobytes()).decode("ascii")}


def preview(path, frame, layers, src, bushes, bad):
    """Ảnh xem trước 2 px / ô guide: nước, lane, rừng, đá, vách, bụi, bậc, trụ, trại; hồng = chỗ đi được nhưng không tới được."""
    fx0, fy0, fx1, fy1 = frame
    S = 2
    im = Image.new("RGB", ((fx1 - fx0) * S, (fy1 - fy0) * S), (98, 128, 61))
    d = ImageDraw.Draw(im, "RGBA")
    gp = lambda pts: [((x - fx0) * S, (y - fy0) * S) for x, y in pts]
    for b in src["bases"]:
        d.polygon(gp(b["polygon"]), fill=(80, 140, 255, 50) if b["team"] == 0 else (255, 90, 90, 50))
    for p in layers["water"]:
        d.polygon(gp(p.exterior.coords), fill=(47, 150, 170))
    for l in src["lanes"].values():
        d.line(gp(l), fill=(215, 186, 132), width=src["lane_half_width"] * 2 * S, joint="curve")
    for key, col in (("forest", (38, 78, 34)), ("rocks", (120, 125, 140)), ("cliffs", (40, 44, 58))):
        for p in layers[key]:
            d.polygon(gp(p.exterior.coords), fill=col)
            for h in p.interiors:
                d.polygon(gp(h.coords), fill=(98, 128, 61))
    for poly in bushes:
        d.polygon(gp(poly), fill=(140, 200, 60, 200), outline=(220, 255, 120))
    for x, y, a in src["stairs"]:
        d.ellipse(((x - fx0) * S - 6, (y - fy0) * S - 6, (x - fx0) * S + 6, (y - fy0) * S + 6), fill=(230, 230, 230))
    for t in src["towers"]:
        x, y = (t["pos"][0] - fx0) * S, (t["pos"][1] - fy0) * S
        d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(60, 140, 255) if t["team"] == 0 else (255, 80, 80), outline=(0, 0, 0))
    for c in src["camps"]:
        x, y = (c["pos"][0] - fx0) * S, (c["pos"][1] - fy0) * S
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 220, 0), outline=(0, 0, 0))
    ov = np.zeros(bad.shape + (4,), np.uint8)
    ov[bad] = (255, 0, 255, 170)
    o = Image.fromarray(ov, "RGBA").resize(im.size, Image.NEAREST)
    im.paste(o, (0, 0), o)
    im.save(path)
