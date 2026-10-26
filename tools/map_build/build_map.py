#!/usr/bin/env python3
"""Dựng dữ liệu map Clashborn (v3, D-168) từ nguồn vector `map_source.json` (nửa Blue, toạ độ guide).

Ra data/maps/clashborn_map.json: mọi polygon gameplay + vẽ trong toạ độ thế giới, mảnh va chạm,
trường khoảng trống (base64), lane, trụ, trại, bậc thang, bụi cỏ. Cùng polygon dùng cho vẽ, va
chạm và tìm đường nên thứ nhìn thấy đúng là thứ chặn đường (MAP-01).

Chạy: python3 tools/map_build/build_map.py   (cần numpy, opencv-python, scipy, shapely, pillow)
"""
import json, math, os, sys
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "data", "maps", "clashborn_map.json")
sys.path.insert(0, HERE)
from symmetry import Sym  # noqa: E402
import geometry as G, export as X, towers as T, features as F  # noqa: E402

SRC = json.load(open(os.path.join(HERE, "map_source.json")))
SYM = Sym(SRC["frame"])
SCALE = SRC["scale"]
FX0, FY0, FX1, FY1 = SRC["frame"]
CENTER = ((FX0 + FX1) / 2, (FY0 + FY1) / 2)


def W(p):  # guide → thế giới
    return [round((p[0] - FX0) * SCALE, 1), round((p[1] - FY0) * SCALE, 1)]


def semantics(src):
    """Nửa Blue → cả map: lane, điểm sinh, base, fountain, nhà chính, trại, trụ (MAP-04)."""
    s = dict(src)
    s["lanes"] = SYM.lanes(src["lanes"])
    s["fountains"] = [src["fountains"][0], SYM.rot(src["fountains"][0])]
    s["cores"] = [src["cores"][0], SYM.rot(src["cores"][0])]
    spawns = src["lane_spawns"]["0"]
    s["lane_spawns"] = {"0": dict(spawns), "1": {k: SYM.rot(spawns[{"TOP": "BOT", "MID": "MID", "BOT": "TOP"}[k]]) for k in spawns}}
    base0 = src["bases"][0]
    s["bases"] = [base0, {"team": 1, "polygon": [SYM.rot(p) for p in base0["polygon"]]}]
    s["camps"] = SYM.camps(src["camps"])
    s["towers"] = SYM.towers(T.place(src, s["lanes"]))
    return s


def bush_polygons(src):
    """VIS-06: bụi cỏ hình lượn (elip có gợn theo góc, cố định theo vị trí) + bản xoay 180°."""
    out = []
    for b in src["bushes"]:
        k = (b["pos"][0] * 7.0 + b["pos"][1] * 13.0) % 6.28
        a = math.radians(b.get("angle", 0))
        pts = []
        for i in range(24):
            t = 2 * math.pi * i / 24
            wob = 1.0 + 0.16 * math.sin(3 * t + k) + 0.09 * math.sin(5 * t + 2 * k)
            x, y = b["rx"] * wob * math.cos(t), b["ry"] * wob * math.sin(t)
            pts.append((b["pos"][0] + x * math.cos(a) - y * math.sin(a), b["pos"][1] + x * math.sin(a) + y * math.cos(a)))
        out += [pts, [SYM.rot(p) for p in pts]]
    return out


def obstacles(s):
    """Rừng, núi đá, vách / rào (đoạn có độ dày), vòng đá ổ quái, bậc thang; đã cắt khu trống và lấp khe (MAP-03)."""
    frame = box(FX0, FY0, FX1, FY1)
    mid_zone = Point(CENTER).buffer(SRC["mid_clear_world"] / SCALE)  # MAP-05
    river = [Polygon(p).buffer(0) for p in SRC["river"]]
    bank, stairs = G.bank_lines(river, SRC["river_bank"], SYM, mid_zone)
    lines = [(l, SRC["river_bank"]["width"], "rock") for l in bank]
    lines += [(l, w, "rock") for l, w in G.mirrored_lines(SYM, SRC["rock_lines"], SRC["rock_width"])]
    ring_lines, rings, tree_rings, doors = F.camp_alcoves(SRC, SYM, SCALE)
    fence = F.fences(SRC, s, frame)
    lines += [(l, w, "fence") for l, w in fence]
    cut, gates = _clear(s, stairs, doors)
    solid = unary_union([l.buffer(w / 2, **G.FLAT) for l, w, k in lines if k == "rock"] + [l.buffer(w / 2, **G.FLAT) for l, w in ring_lines])
    cliff = solid.difference(cut).difference(mid_zone).union(unary_union([l.buffer(w / 2, **G.FLAT) for l, w in fence]).difference(gates))
    rocks = unary_union(G.mirrored_polys(SYM, SRC["mountains"]) + [G.border_area(SRC["frame"], SRC["border"])]).difference(cut).difference(cliff)
    forest = unary_union(G.mirrored_polys(SYM, SRC["forest"]) + tree_rings).difference(cut).difference(rocks).difference(cliff)
    protect = cut.union(unary_union([Point(x, y).buffer(SRC["river_bank"]["opening_r"] + 2) for x, y, _ in stairs]))
    fill = G.readability(frame, unary_union([forest, rocks, cliff]), protect, s["fountains"][0], SRC["gap_min_world"] / 2 / SCALE)
    forest = unary_union([forest, fill.difference(cliff).difference(rocks)]).intersection(frame)
    print(f"MAP-03: lấp {fill.area:.0f} ô guide khe hẹp / hốc kín")
    layers = {"forest": G.polys_of(forest), "rocks": G.polys_of(rocks.intersection(frame)),
              "cliffs": G.polys_of(cliff.intersection(frame)), "water": river}
    return layers, lines, stairs, rings, (cut, gates)


def _clear(s, stairs, doors):
    """Khu phải trống (lane, base, trụ, trại, điểm sinh, fountain, lối sông) và cổng rào (lane, điểm sinh)."""
    extra = [(p, 20) for p in s["fountains"]] + [(p, 12) for p in s["cores"]]
    spawns = [(p, 7) for t in ("0", "1") for p in s["lane_spawns"][t].values()]
    extra += spawns + [((x, y), SRC["river_bank"]["opening_r"]) for x, y, _ in stairs]
    extra += [(c["pos"], c["r"]) for c in SRC.get("clear_circles", [])] + doors
    cut = G.clear_zone(SRC, s["lanes"], s["bases"], s["towers"], s["camps"], extra)
    gates = unary_union([LineString(l).buffer(SRC["lane_half_width"] + 1, **G.ROUND) for l in s["lanes"].values()]
                        + [Point(p).buffer(r) for p, r in spawns] + [Point(t["pos"]).buffer(SRC["tower_clear_radius"]) for t in s["towers"]])
    return cut, gates


def rock_line_data(lines, cuts, frame):
    """Đường vách / rào cho VIEW (D-168, D-169): từng đoạn còn lại sau khi cắt khu trống, kèm độ dày và loại."""
    cut, gates = cuts
    out = []
    for l, w, kind in lines:
        for part in G.lines_of(l.difference(gates if kind == "fence" else cut).intersection(frame)):
            out.append({"points": [W(p) for p in part.coords], "width": w * SCALE, "kind": kind})
    return out


def main():
    s = semantics(SRC)
    layers, lines, stairs, rings, cuts = obstacles(s)
    s["stairs"] = stairs
    blocked = unary_union(layers["forest"] + layers["rocks"] + layers["cliffs"])
    collision = X.collision_pieces(blocked)
    clear = X.clearance(collision, SRC["frame"], SCALE)
    errors, bad = X.validate(clear, s, W, SCALE)
    bushes = bush_polygons(SRC)
    data = {
        "version": 3, "generated_by": "tools/map_build/build_map.py", "scale_from_guide": SCALE,
        "guide_origin": [FX0, FY0], "world_size": [(FX1 - FX0) * SCALE] * 2,
        "lane_width": SRC["lane_half_width"] * 2 * SCALE, "nav_cell": SRC["nav_cell"],
        "clearance": X.clearance_block(clear, SCALE),
        "fountains": [W(p) for p in s["fountains"]], "cores": [W(p) for p in s["cores"]],
        "lanes": {k: [W(p) for p in v] for k, v in s["lanes"].items()},
        "lane_spawns": {t: {k: W(p) for k, p in v.items()} for t, v in s["lane_spawns"].items()},
        "towers": [dict(id=t["id"], team=t["team"], lane=t["lane"], tier=t["tier"], pos=W(t["pos"]), requires=_prereq(t)) for t in s["towers"]],
        "camps": [dict(id=c["id"], side=c["side"], kind=c["kind"], pos=W(c["pos"])) for c in s["camps"]],
        "bases": [dict(team=b["team"], polygon=[W(p) for p in b["polygon"]]) for b in s["bases"]],
        "ramps": [{"pos": W((x, y)), "angle": round(a, 4)} for x, y, a in stairs],
        "bushes": [[W(p) for p in poly] for poly in bushes],
        "shops": _named(SRC["shops"]), "landmarks": _named(SRC.get("landmarks", [])),
        "render": {k: X.render_polys(v, W) for k, v in layers.items()} | {"rock_lines": rock_line_data(lines, cuts, box(FX0, FY0, FX1, FY1)),
                                                                     "rings": [{"pos": W(r["pos"]), "open": round(math.radians(r["open"]), 4), "model": r["model"], "scale": SRC["ring"]["scale"]} for r in rings]},
        "collision": [X.poly_world(p, W) for p in collision],
    }
    X.write_json(OUT, data)
    X.preview(os.path.join(HERE, "preview.png"), SRC["frame"], layers, s, bushes, bad)
    print(f"forest {len(layers['forest'])} rocks {len(layers['rocks'])} cliffs {len(layers['cliffs'])} stairs {len(stairs)} collision {len(collision)}")
    if errors:
        print("VALIDATION ERRORS:\n  - " + "\n  - ".join(errors))
        sys.exit(1)
    print("validation OK")


def _named(items):
    return [{"name": l["name"], "pos": W(l["pos"])} for l in items] + [{"name": l["name"] + "'", "pos": W(SYM.rot(l["pos"]))} for l in items]


def _prereq(t):
    side = "blue" if t["team"] == 0 else "red"
    if t["tier"] in (2, 3):
        return {"all": [f"{side}_{t['lane'].lower()}_t{t['tier'] - 1}"], "any": []}
    if t["tier"] == 4:
        return {"all": [], "any": [f"{side}_{lane}_t3" for lane in ("top", "mid", "bot")]}
    return {"all": [], "any": []}


if __name__ == "__main__":
    main()
