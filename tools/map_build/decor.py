#!/usr/bin/env python3
"""Cảnh vật 3D + mặt nạ nền đất cho map đã build (D-178) — chỉ VIEW đọc, SIM không dùng.

Đọc data/maps/clashborn_map.json (toạ độ thế giới, 100 px = 1 m) và mạng lối đi (plateau_design.py), ghi
data/maps/clashborn_decor.json:
  items   [mô hình, x, z, góc, cỡ, y (m)] — mô hình trong assets/models/style/
  mask    PNG base64 RGBA: R đất nện (đường rừng, base, sân rìa map), G đất có phiến đá (lane), B nền rừng, A bóng vẽ sẵn (nắng tây
          bắc → bóng lệch đông nam) — D-180: gộp một ảnh để shader mặt đất đọc một lần
  water   PNG base64 L: độ sâu nước (shader nước)
  ground / abyss  tam giác [x1,z1,x2,z2,x3,z3]: mặt đất (khung map trừ rìa MAP-12) / vực ngoài (D-197)
  cliff   vòng mép mặt đất — VIEW dựng vách đổ xuống vực
  mask_origin, mask_px: góc trên trái (px thế giới) và số px thế giới mỗi điểm ảnh mặt nạ

  python3 tools/map_build/decor.py
Quy tắc đặt (D-179, decor_place): vật cao che đất phía bắc sau nó (camera ở nam) — mép bục quay nam là vách đá
cao, quay bắc đá thấp + khóm lá; cây chỉ cao tới mức không che lối phía bắc bục; bờ sông cụm đá lệch cỡ xen lau
sậy, bờ bắc vật thấp. Đá viền nằm hẳn trong vùng chặn.
"""
import base64, io, json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import plateau_design as PD  # noqa: E402
import decor_place as DP  # noqa: E402

DATA = os.path.join(HERE, "..", "..", "data", "maps")
MARGIN = 1600.0   # mặt nạ phủ thêm ngoài khung map (px thế giới)
MASK_PX = 8.0     # px thế giới mỗi điểm ảnh mặt nạ
RIM = 60.0        # D-197: dải đất ngoài mép đi được (px) — lan can đứng trên đó, sau là vách đổ xuống vực
PARAPET_STEP = 190.0  # đoạn lan can 2 m, chồng nhẹ
ABYSS_REACH = 8000.0  # đáy vực phủ ra ngoài khung (px): sâu 18 m nên tia camera chạm đáy rất xa mép


def load():
    m = json.load(open(os.path.join(DATA, "clashborn_map.json")))
    shapes = lambda key: [Polygon(s["outer"], s.get("holes", [])).buffer(0) for s in m["render"][key]]
    return m, shapes("forest"), shapes("rocks"), shapes("water")


def paths_world(m):
    """Mạng lối đi của plateau_design (cả hai nửa) sang toạ độ thế giới: [(LineString, bề rộng px)]."""
    sc, (ox, oy) = m["scale_from_guide"], m["guide_origin"]
    w = lambda p: ((p[0] - ox) * sc, (p[1] - oy) * sc)
    out = []
    for names, width in PD.PATHS:
        pts = [PD.P[n] for n in names]
        out.append((LineString([w(p) for p in pts]), width * sc))
        out.append((LineString([w(PD.rot(p)) for p in pts]), width * sc))
    return out


STONE_SHARE = 0.85  # D-194: phần lane có đá (còn lại đất trơn) — phá nhịp lặp của ảnh dirt_stones
SECTION_M = 6.0     # cỡ đoạn có đá / đất trơn (m, độ nhòe của nhiễu)


def stone_sections(n):
    """D-194: mặt nạ 0/1 nhiễu tần số thấp — đoạn lane có đá (1) xen đoạn đất trơn (0), cỡ vài mét."""
    rng = np.random.default_rng(194)
    cells = max(4, int(n * MASK_PX / (SECTION_M * 100)))  # một ô nhiễu ~ SECTION_M mét, phóng to mềm
    a = np.array(Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)).astype(float)
    return (a > np.percentile(a, (1 - STONE_SHARE) * 100)).astype(float)


def mask_images(m, forest, rocks, water, edge):
    size = m["world_size"][0]
    n = int((size + 2 * MARGIN) / MASK_PX)
    T = lambda pts: [((x + MARGIN) / MASK_PX, (y + MARGIN) / MASK_PX) for x, y in pts]
    chan = lambda: (Image.new("L", (n, n), 0),)
    dirt, = chan(); pave, = chan(); floor, = chan(); wet, = chan()
    dd, dp, df, dw = (ImageDraw.Draw(i) for i in (dirt, pave, floor, wet))
    for line, width in paths_world(m):
        dd.line(T(line.coords), fill=255, width=int(width * 0.42 / MASK_PX), joint="curve")
    for c in m["camps"]:
        x, y = c["pos"]
        dd.ellipse(T([(x - 280, y - 240), (x + 280, y + 240)]), fill=255)
    for pts in m["lanes"].values():
        dd.line(T(pts), fill=255, width=int((m["lane_width"] + 140) / MASK_PX), joint="curve")
        dp.line(T(pts), fill=255, width=int((m["lane_width"] - 20) / MASK_PX), joint="curve")
    pave = Image.fromarray((np.array(pave) * stone_sections(n)).astype(np.uint8))  # D-194: đoạn có đá / đất trơn
    dp = ImageDraw.Draw(pave)
    for b in m["bases"]:  # D-192: nền base (đất cao) là đất nện trơn, không đá — kể cả đoạn lane đi qua
        dp.polygon(T(b["polygon"]), fill=0)
        dd.polygon(T(b["polygon"]), fill=255)
    for g in edge:
        dd.polygon(T(g.exterior.coords), fill=255)
    for g in forest:
        df.polygon(T(g.buffer(60).exterior.coords), fill=255)
    for g in water:
        dw.polygon(T(g.exterior.coords), fill=255)
    depth = np.array(wet.filter(ImageFilter.GaussianBlur(160 / MASK_PX))).astype(float)
    depth = (np.clip((depth - 128) * 2, 0, 255) * (np.array(wet) > 0)).astype(np.uint8)
    return [DP.ragged(dirt, 3, 5), DP.ragged(pave, 1.6, 2), DP.ragged(floor, 6, 7)], Image.fromarray(depth), n


def shadow_image(items, n, water, edge):
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    T = lambda x, y: ((x + MARGIN) / MASK_PX, (y + MARGIN) / MASK_PX)
    for kind, x, z, _, sc, *_ in items:
        r = DP.SHADOW_R.get(kind, 0.0) * 100 * sc
        if r > 0:
            cx, cy = T(x + r * 0.45, z + r * 0.35)
            d.ellipse([cx - r / MASK_PX, cy - r * 0.8 / MASK_PX, cx + r / MASK_PX, cy + r * 0.8 / MASK_PX], fill=200)
    for g in water:
        bank = g.buffer(130).difference(g)
        for p in getattr(bank, "geoms", [bank]):
            d.polygon([T(x, y) for x, y in p.exterior.coords], fill=110)
    for g in edge:  # bóng rào đổ vào trong map
        ring = g.buffer(70).difference(g)
        for p in getattr(ring, "geoms", [ring]):
            d.polygon([T(x, y) for x, y in p.exterior.coords], fill=120)
    return img.filter(ImageFilter.GaussianBlur(45 / MASK_PX))


def abyss_data(m, edge):
    """D-197: vực ngoài rìa map. land = khung map trừ rìa (MAP-12) nới RIM; mặt đất 3D chỉ phủ land (tam giác),
    vực = vùng mặt nạ còn lại; vách = mép land; lan can dọc mép đi được (giữa dải RIM)."""
    from shapely import constrained_delaunay_triangles
    from shapely.geometry.polygon import orient
    size = m["world_size"][0]
    land = box(0, 0, size, size).difference(unary_union(edge))
    land_vis = orient(land.buffer(RIM, join_style="mitre").buffer(0), 1.0)
    outer = box(-ABYSS_REACH, -ABYSS_REACH, size + ABYSS_REACH, size + ABYSS_REACH)
    tris = lambda g: [[round(c, 1) for xy in list(t.exterior.coords)[:3] for c in xy] for t in constrained_delaunay_triangles(g).geoms]
    rings = [land_vis.exterior] + list(land_vis.interiors) if land_vis.geom_type == "Polygon" else [p.exterior for p in land_vis.geoms]
    rail = land.buffer(RIM * 0.5, join_style="mitre")
    return {"ground": tris(land_vis), "abyss": tris(outer.difference(land_vis)),
            "cliff": [[[round(x, 1), round(z, 1)] for x, z in r.coords[:-1]] for r in rings]}, rail


def b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


def main():
    m, forest, rocks, water = load()
    rng = random.Random(178)
    size = m["world_size"][0]
    wet = unary_union(water)
    edge = [g for g in rocks if g.distance(wet) > 200]
    bank = [g for g in rocks if g.distance(wet) <= 200]
    items = []
    DP.plateaus(items, forest, rng)
    DP.river(items, water, bank, rng)
    DP.base_fences(items, m["render"].get("rock_lines", []))
    DP.scatter(items, m, forest, wet, rng)
    abyss, rail = abyss_data(m, edge)
    for r in [rail.exterior] + list(rail.interiors):
        DP.along(items, r, "parapet", PARAPET_STEP)
    rgb, depth, n = mask_images(m, forest, rocks, water, edge)
    mask = Image.merge("RGBA", rgb + [shadow_image(items, n, water, edge)])
    data = {"items": [[k, round(x, 1), round(z, 1), round(a, 3), round(s, 3)] + ([round(y[0], 3)] if y else []) for k, x, z, a, s, *y in items],
            "mask": b64(mask), "water": b64(depth),
            **abyss,
            "mask_origin": [-MARGIN, -MARGIN], "mask_px": MASK_PX}
    json.dump(data, open(os.path.join(DATA, "clashborn_decor.json"), "w"), separators=(",", ":"))
    counts = {}
    for it in items:
        counts[it[0]] = counts.get(it[0], 0) + 1
    print(f"{len(items)} vật: {counts}")


if __name__ == "__main__":
    main()
