#!/usr/bin/env python3
"""Build Clashborn map data from the reference guide + hand-authored semantics.

Inputs (this folder):
  reference_guide.png  600x600 painted reference (visual source for terrain shapes)
  map_source.json      towers, lanes, camps, ramps, bases ... (authoritative semantics)

Outputs (project data/maps/):
  clashborn_map.json       every gameplay + render polygon in Godot world units
  (the 8-bit clearance field is embedded in the JSON as base64, row-major)

Run:  python3 tools/map_build/build_map.py   (needs numpy, opencv-python, scipy, shapely, pillow)
The same polygons feed rendering, physics collision and the navigation clearance
field, so what the player sees is exactly what blocks movement.
"""
import base64, json, math, os, sys
from collections import deque
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from shapely.geometry import Polygon, MultiPolygon, LineString, Point, box
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "data", "maps")
SRC = json.load(open(os.path.join(HERE, "map_source.json")))
sys.path.insert(0, HERE)
from symmetry import Sym, place_t1  # noqa: E402
import river_cross  # noqa: E402
SYM = Sym(SRC["frame"]) if SRC.get("symmetry") == "rotate180" else None
if SYM:
    SRC = SYM.source(SRC)

SCALE = SRC["scale"]
FX0, FY0, FX1, FY1 = SRC["frame"]
SIZE_G = FX1 - FX0                      # playable size in guide units
WORLD = SIZE_G * SCALE                  # world units
UP = 4                                  # supersampling for vectorizing / clearance
CLEAR_UNIT = 4.0                        # world units per clearance byte
CLEAR_PX = SCALE                        # world units per clearance pixel (1 guide unit)


def W(p):  # guide -> world
    return [round((p[0] - FX0) * SCALE, 1), round((p[1] - FY0) * SCALE, 1)]


# ---------------------------------------------------------------- raster masks
img = np.array(Image.open(os.path.join(HERE, "reference_guide.png")).convert("RGB")).astype(int)
R, G, B = img[..., 0], img[..., 1], img[..., 2]
H, Wd = R.shape
mx = img.max(axis=2)
yy, xx = np.mgrid[0:H, 0:Wd]
inside = (xx >= FX0) & (xx < FX1) & (yy >= FY0) & (yy < FY1)

black = (mx < 28) & inside
water = (B > G + 25) & (B > 110) & inside
tree = (B - G < 7) & (mx > 40) & (mx < 112) & (G > R + 25) & inside
tree = ndi.binary_fill_holes(ndi.binary_closing(ndi.binary_opening(tree, iterations=1), iterations=2))
# the river is the only large water body; small light-blue loops are outlines of
# high-ground tree clusters, so they become trees
lab, n = ndi.label(water)
sizes = ndi.sum(water, lab, range(1, n + 1))
river = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 300])
tree |= ndi.binary_fill_holes(water & ~river)
water = ndi.binary_fill_holes(river)
if SYM:
    black, water, tree = SYM.mask(black), SYM.mask(water), SYM.mask(tree)
if SRC.get("mid_crossing_clear"):  # MAP-05: bỏ vách lồi sát chỗ mid cắt sông
    _c = [(FX0 + FX1) / 2, (FY0 + FY1) / 2]
    black, _zone = river_cross.apply(SRC["mid_crossing_clear"], xx, yy, _c, SCALE, black)
    SRC["ramps"] = [r for r in SRC["ramps"] if river_cross.keeps_ramp(r, _zone)]

def bush_polygons():
    """M5.1b (D-72): elip bụi cỏ (nửa xanh) + bản xoay 180°, tọa độ guide."""
    out = []
    for b in SRC.get("bushes", []):
        for c in ([b["pos"], SYM.rot(b["pos"])] if SYM else [b["pos"]]):
            a = math.radians(b.get("angle", 0)); pts = []
            for i in range(16):
                t = 2 * math.pi * i / 16
                x, y = b["rx"] * math.cos(t), b["ry"] * math.sin(t)
                pts.append((c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a)))
            out.append(pts)
    return out


def disk(cx, cy, r):
    return (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r

# ramp orientation: principal direction of the cliff line around the ramp
black_original = black.copy()
ramp_angles = []
for ramp in SRC["ramps"]:
    r = ramp[2] if len(ramp) > 2 else SRC["ramp_radius"]
    ring = black_original & disk(ramp[0], ramp[1], r + 7) & ~disk(ramp[0], ramp[1], r + 1)
    ys_, xs_ = np.nonzero(ring)
    if len(xs_) >= 4:
        pts = np.stack([xs_ - ramp[0], ys_ - ramp[1]], axis=1).astype(float)
        w, v = np.linalg.eigh(pts.T @ pts)
        d = v[:, np.argmax(w)]
        ramp_angles.append(math.atan2(d[1], d[0]))
    else:
        ramp_angles.append(0.0)
# ramps open the cliff lines
for ramp in SRC["ramps"]:
    black &= ~disk(ramp[0], ramp[1], ramp[2] if len(ramp) > 2 else SRC["ramp_radius"])
for x0, y0, x1, y1 in SRC["erase_rects"]:
    black &= ~((xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1))
lab, n = ndi.label(black, structure=np.ones((3, 3)))
sizes = ndi.sum(black, lab, range(1, n + 1))
cliffs = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 6])
cliffs = ndi.binary_dilation(cliffs, iterations=1) & inside

# ---------------------------------------------------------------- towers (D-49)
if SYM:
    _blocked = (tree | black | ~inside)
    _dist = ndi.distance_transform_edt(~_blocked)
    def _clear(p):
        x, y = int(p[0]), int(p[1])
        return _dist[y, x] if 0 <= x < Wd and 0 <= y < H else 0.0
    layout = SRC["tower_layout"]
    blue = [dict(t) for t in SRC["towers"] if t["team"] == 0]
    for t in blue:
        if t["tier"] == 1:
            t["pos"] = place_t1(SYM, SRC["lanes"][t["lane"]], layout[t["lane"]], layout["lateral"], _clear, SCALE)
    SRC["towers"] = SYM.towers(blue)

# polygons of semantic areas in guide space
base_polys = [Polygon(b["polygon"]) for b in SRC["bases"]]
lane_lines = {k: LineString(v) for k, v in SRC["lanes"].items()}

def raster(geom, res=1):
    m = np.zeros((H * res, Wd * res), np.uint8)
    geoms = getattr(geom, "geoms", [geom])
    for g in geoms:
        if g.is_empty:
            continue
        if g.geom_type == "Polygon":
            cv2.fillPoly(m, [np.round(np.array(g.exterior.coords) * res - 0.5).astype(np.int32)], 1)
            for hole in g.interiors:
                cv2.fillPoly(m, [np.round(np.array(hole.coords) * res - 0.5).astype(np.int32)], 0)
    return m.astype(bool)

lane_corridor = raster(unary_union([l.buffer(SRC["lane_half_width"] + 1) for l in lane_lines.values()]))
bases = raster(unary_union(base_polys))

# trees: never inside bases (open Dota-style base), never on lanes or key points
tree &= ~bases & ~lane_corridor
keep_clear = [(c["pos"], c["r"]) for c in SRC["clear_circles"]]
keep_clear += [(t["pos"], SRC.get("tower_clear_radius", 6)) for t in SRC["towers"]]
keep_clear += [(c["pos"], 8) for c in SRC["camps"]]
for team in ("0", "1"):
    keep_clear += [(p, 7) for p in SRC["lane_spawns"][team].values()]
for (cx, cy), r in keep_clear:
    tree &= ~disk(cx, cy, r)
for c in SRC["clear_circles"]:
    cliffs &= ~disk(c["pos"][0], c["pos"][1], c["r"])
for t in SRC["towers"]:  # D-49: quanh trụ không có vách (MAP-04)
    cliffs &= ~disk(t["pos"][0], t["pos"][1], SRC.get("tower_clear_radius", 6))

bf = SRC["border_forest"]
border = inside & ((xx < bf["left"]) | (yy < bf["top"]) | (xx > bf["right"]) | (yy > bf["bottom"]))
border &= ~bases & ~lane_corridor
forest = tree | border
lab, n = ndi.label(forest)
sizes = ndi.sum(forest, lab, range(1, n + 1))
forest = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 20])

if SYM:
    forest, cliffs = SYM.mask(forest), SYM.mask(cliffs)

# ---------------------------------------------------------------- readability (D-43)
# Không để khe trông như đi được mà hero không lọt: chỗ trống hẹp hơn gap_min_world
# bị lấp thành rừng; vùng trống không nối với phần map chính (hốc kín) cũng lấp.
GAP_MIN = SRC.get("gap_min_world", 112)
gap_r = int(math.ceil(GAP_MIN / 2 / SCALE))
protect = bases | lane_corridor
for (cx, cy), r in keep_clear:
    protect |= disk(cx, cy, r)
for ramp in SRC["ramps"]:
    protect |= disk(ramp[0], ramp[1], ramp[2] if len(ramp) > 2 else SRC["ramp_radius"])
gap_disk = disk(gap_r, gap_r, gap_r)[: 2 * gap_r + 1, : 2 * gap_r + 1]
open_area = inside & ~forest & ~cliffs
opened = ndi.binary_opening(open_area, structure=gap_disk)
narrow = open_area & ~opened & ~protect
forest |= narrow
open_area = inside & ~forest & ~cliffs
lab, n = ndi.label(open_area)
fx, fy = SRC["fountains"][0]
pockets = open_area & (lab != lab[int(fy), int(fx)]) & ~protect
forest |= pockets
print(f"readability: filled {int(narrow.sum())} narrow-gap px and {int(pockets.sum())} closed-pocket px (guide units)")

# ---------------------------------------------------------------- vectorize
def vectorize(mask, simplify=0.45, min_area=6.0, smooth=True):
    big = cv2.resize(mask.astype(np.float32), (Wd * UP, H * UP), interpolation=cv2.INTER_LINEAR if smooth else cv2.INTER_NEAREST)
    if smooth:
        big = cv2.GaussianBlur(big, (0, 0), UP * 0.55)
    bm = (big > 0.5).astype(np.uint8)
    contours, hier = cv2.findContours(bm, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    polys = []
    if hier is None:
        return polys
    hier = hier[0]
    for i, c in enumerate(contours):
        if hier[i][3] != -1:
            continue
        ext = c[:, 0, :].astype(float) / UP + 0.5 / UP
        holes = []
        j = hier[i][2]
        while j != -1:
            hc = contours[j][:, 0, :].astype(float) / UP + 0.5 / UP
            if len(hc) >= 4:
                holes.append(hc)
            j = hier[j][0]
        if len(ext) < 4:
            continue
        p = Polygon(ext, holes).buffer(0)
        if p.area < min_area:
            continue
        p = p.simplify(simplify, preserve_topology=True)
        polys.extend(getattr(p, "geoms", [p]))
    return [p for p in polys if p.area >= min_area]

forest_polys = vectorize(forest, simplify=0.5, min_area=8)
cliff_polys = vectorize(cliffs, simplify=0.45, min_area=3, smooth=True)
water_polys = vectorize(water, simplify=0.6, min_area=10)

frame_poly = box(FX0, FY0, FX1, FY1)
blocked = unary_union(forest_polys + cliff_polys).intersection(frame_poly)

# collision pieces must not have holes: split recursively through each hole
def split_holes(poly, depth=0):
    if poly.is_empty:
        return []
    if poly.geom_type == "MultiPolygon":
        return [q for g in poly.geoms for q in split_holes(g, depth)]
    if not poly.interiors or depth > 12:
        return [poly]
    hx, hy = Polygon(poly.interiors[0]).representative_point().coords[0]
    minx, miny, maxx, maxy = poly.bounds
    left = poly.intersection(box(minx - 1, miny - 1, hx, maxy + 1))
    right = poly.intersection(box(hx, miny - 1, maxx + 1, maxy + 1))
    out = []
    for part in (left, right):
        for g in getattr(part, "geoms", [part]):
            if g.geom_type == "Polygon" and g.area > 0.5:
                out.extend(split_holes(g, depth + 1))
    return out

collision = []
for g in getattr(blocked, "geoms", [blocked]):
    for piece in split_holes(g.buffer(0)):
        piece = piece.simplify(0.25, preserve_topology=True)
        if piece.area > 0.8 and piece.geom_type == "Polygon":
            collision.append(piece)

# ---------------------------------------------------------------- clearance field
RES = UP
occ = np.zeros((H * RES, Wd * RES), np.uint8)
for p in collision:
    cv2.fillPoly(occ, [np.round(np.array(p.exterior.coords) * RES - 0.5).astype(np.int32)], 1)
occ[~cv2.resize(inside.astype(np.uint8), (Wd * RES, H * RES), interpolation=cv2.INTER_NEAREST).astype(bool)] = 1
dist_px = ndi.distance_transform_edt(occ == 0)            # in fine pixels
dist_world = dist_px * (SCALE / RES)
# crop to frame and min-pool to 1 guide unit per pixel (conservative)
fine = dist_world[FY0 * RES:FY1 * RES, FX0 * RES:FX1 * RES]
pooled = fine.reshape(SIZE_G, RES, SIZE_G, RES).min(axis=(1, 3))
clear_u8 = np.clip(np.floor(pooled / CLEAR_UNIT), 0, 255).astype(np.uint8)

# ---------------------------------------------------------------- validation
def clearance_at_world(wx, wy):
    gx, gy = int(wx / CLEAR_PX), int(wy / CLEAR_PX)
    if gx < 0 or gy < 0 or gx >= SIZE_G or gy >= SIZE_G:
        return 0
    return clear_u8[gy, gx] * CLEAR_UNIT

errors = []
HERO_R = 32 + 8
walk = (clear_u8.astype(float) * CLEAR_UNIT) >= HERO_R
# tower bodies are solid for navigation
for t in SRC["towers"]:
    wx, wy = W(t["pos"])
    r = (52 + HERO_R) / CLEAR_PX
    walk &= ~(((np.mgrid[0:SIZE_G, 0:SIZE_G][1] + 0.5 - wx / CLEAR_PX) ** 2 + (np.mgrid[0:SIZE_G, 0:SIZE_G][0] + 0.5 - wy / CLEAR_PX) ** 2) < r * r)
start = tuple(int(v / CLEAR_PX) for v in W(SRC["fountains"][0]))[::-1]
if not walk[start]:
    errors.append("Blue fountain is not walkable for a hero")
seen = ndi.label(walk)[0]
comp = seen[start]
reach = seen == comp

def reachable_near(gp, radius_world):
    wx, wy = W(gp)
    cx, cy = wx / CLEAR_PX, wy / CLEAR_PX
    r = radius_world / CLEAR_PX
    y0, y1 = int(max(0, cy - r)), int(min(SIZE_G, cy + r + 1))
    x0, x1 = int(max(0, cx - r)), int(min(SIZE_G, cx + r + 1))
    sub = reach[y0:y1, x0:x1]
    return sub.any()

checks = [("red fountain", SRC["fountains"][1], 40)]
for k, line in SRC["lanes"].items():
    for i, p in enumerate(line):
        checks.append((f"lane {k} waypoint {i}", p, 40))
for team in ("0", "1"):
    for lane, p in SRC["lane_spawns"][team].items():
        checks.append((f"lane spawn {team}/{lane}", p, 40))
for t in SRC["towers"]:
    checks.append((f"tower {t['id']} approach", t["pos"], 52 + 200))
for c in SRC["camps"]:
    checks.append((f"camp {c['id']}", c["pos"], 60))
for team, p in enumerate(SRC["cores"]):
    checks.append((f"core {team} approach", p, 65 + 200))
for name, p, rad in checks:
    if not reachable_near(p, rad):
        errors.append("Unreachable: " + name)
for name in ("TOP", "MID", "BOT"):
    for i, p in enumerate(SRC["lanes"][name]):
        wx, wy = W(p)
        if clearance_at_world(wx, wy) < 40:
            errors.append(f"Lane {name} waypoint {i} clearance {clearance_at_world(wx, wy):.0f} < 40")
for team, p in enumerate(SRC["fountains"]):
    wx, wy = W(p)
    if clearance_at_world(wx, wy) < 200:
        errors.append(f"Fountain {team} clearance {clearance_at_world(wx, wy):.0f} < 200")

# ---------------------------------------------------------------- export JSON
def poly_world(p):
    pts = list(p.exterior.coords)[:-1]
    return [[round((x - FX0) * SCALE, 1), round((y - FY0) * SCALE, 1)] for x, y in pts]

def render_polys(polys):
    out = []
    for p in polys:
        for g in getattr(p, "geoms", [p]):
            if g.geom_type != "Polygon":
                continue
            entry = {"outer": poly_world(g)}
            if g.interiors:
                entry["holes"] = [[[round((x - FX0) * SCALE, 1), round((y - FY0) * SCALE, 1)] for x, y in list(h.coords)[:-1]] for h in g.interiors]
            out.append(entry)
    return out

tower_ids = {t["id"] for t in SRC["towers"]}
def prereq(t):
    side = "blue" if t["team"] == 0 else "red"
    if t["tier"] in (2, 3):
        return {"all": [f"{side}_{t['lane'].lower()}_t{t['tier'] - 1}"], "any": []}
    if t["tier"] == 4:
        return {"all": [], "any": [f"{side}_{lane}_t3" for lane in ("top", "mid", "bot")]}
    return {"all": [], "any": []}

data = {
    "version": 2,
    "generated_by": "tools/map_build/build_map.py",
    "scale_from_guide": SCALE,
    "guide_origin": [FX0, FY0],
    "world_size": [WORLD, WORLD],
    "lane_width": SRC["lane_half_width"] * 2 * SCALE,
    "nav_cell": SRC["nav_cell"],
    "clearance": {"width": SIZE_G, "height": SIZE_G, "pixel_world": CLEAR_PX, "unit_world": CLEAR_UNIT,
                  "bytes_base64": base64.b64encode(clear_u8.tobytes()).decode("ascii")},
    "fountains": [W(p) for p in SRC["fountains"]],
    "cores": [W(p) for p in SRC["cores"]],
    "lanes": {k: [W(p) for p in v] for k, v in SRC["lanes"].items()},
    "lane_spawns": {t: {lane: W(p) for lane, p in v.items()} for t, v in SRC["lane_spawns"].items()},
    "towers": [dict(id=t["id"], team=t["team"], lane=t["lane"], tier=t["tier"], pos=W(t["pos"]), requires=prereq(t)) for t in SRC["towers"]],
    "camps": [dict(id=c["id"], side=c["side"], kind=c["kind"], pos=W(c["pos"])) for c in SRC["camps"]],
    "bases": [dict(team=b["team"], polygon=[W(p) for p in b["polygon"]]) for b in SRC["bases"]],
    "ramps": [{"pos": W(p), "angle": round(a, 4)} for p, a in zip(SRC["ramps"], ramp_angles)],
    "bushes": [[W(p) for p in poly] for poly in bush_polygons()],
    "landmarks": [{"name": l["name"], "pos": W(l["pos"])} for l in SRC.get("landmarks", [])]
                 + ([{"name": l["name"] + "'", "pos": W(SYM.rot(l["pos"]))} for l in SRC.get("landmarks", [])] if SYM else []),
    "render": {
        "forest": render_polys(forest_polys),
        "cliffs": render_polys(cliff_polys),
        "water": render_polys(water_polys),
    },
    "collision": [poly_world(p) for p in collision],
}
with open(os.path.join(OUT_DIR, "clashborn_map.json"), "w") as f:
    json.dump(data, f, separators=(",", ":"))

# ---------------------------------------------------------------- preview
S = 2
prev = Image.new("RGB", (SIZE_G * S, SIZE_G * S), (61, 107, 94))
d = ImageDraw.Draw(prev, "RGBA")
def gp(pts):
    return [((x - FX0) * S, (y - FY0) * S) for x, y in pts]
for b in base_polys:
    d.polygon(gp(b.exterior.coords), fill=(80, 140, 255, 40))
for p in water_polys:
    d.polygon(gp(p.exterior.coords), fill=(47, 134, 184))
for l in lane_lines.values():
    d.line(gp(l.coords), fill=(185, 167, 127), width=SRC["lane_half_width"] * 2 * S, joint="curve")
for p in forest_polys:
    d.polygon(gp(p.exterior.coords), fill=(31, 74, 58), outline=(16, 40, 30))
for p in cliff_polys:
    d.polygon(gp(p.exterior.coords), fill=(20, 26, 30))
for poly in bush_polygons():
    d.polygon(gp(poly), fill=(120, 200, 60, 170), outline=(220, 255, 120))
for r in SRC["ramps"]:
    x, y = (r[0] - FX0) * S, (r[1] - FY0) * S
    d.ellipse((x - 5, y - 5, x + 5, y + 5), outline=(255, 255, 255, 180))
for t in SRC["towers"]:
    x, y = (t["pos"][0] - FX0) * S, (t["pos"][1] - FY0) * S
    col = (60, 140, 255) if t["team"] == 0 else (255, 80, 80)
    d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=col, outline=(0, 0, 0))
for c in SRC["camps"]:
    x, y = (c["pos"][0] - FX0) * S, (c["pos"][1] - FY0) * S
    d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(255, 220, 0))
unreach = (~reach) & walk
ov = np.zeros((SIZE_G, SIZE_G, 4), np.uint8)
ov[unreach] = (255, 0, 255, 160)
prev.paste(Image.fromarray(ov, "RGBA").resize((SIZE_G * S, SIZE_G * S), Image.NEAREST), (0, 0), Image.fromarray(ov, "RGBA").resize((SIZE_G * S, SIZE_G * S), Image.NEAREST))
prev.save(os.path.join(HERE, "preview.png"))

print(f"world {WORLD}x{WORLD}; forest {len(forest_polys)} cliffs {len(cliff_polys)} water {len(water_polys)} collision {len(collision)}")
print(f"walkable-for-hero reachable fraction {reach.sum() / max(1, walk.sum()):.3f}")
if errors:
    print("VALIDATION ERRORS:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("validation OK")
