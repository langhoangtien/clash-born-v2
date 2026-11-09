"""D-317 (người chơi chọn sau rà map D-314): (1) khoảng rừng trống rộng, trơ → rải cụm trang trí thấp (hoa dại, nấm, gốc
cây, khúc gỗ đổ, cỏ, đá nhỏ) — chỉ hình, không chặn, không lên lối đi; (2) mỗi loại trại một bộ đồ riêng để nhận ra:
sói (small) xương + gỗ đổ, trại lớn (large) cụm pha lê, gấu + pháp sư (medium) lửa trại + totem + nấm, tê giác (beast)
gốc cây + xương + gỗ. Vật cao (totem, pha lê) chỉ đặt trong vùng chặn sát hốc trại (D-179: trông chặn thì phải chặn).
Dùng bởi decor.py. Toạ độ thế giới px (100 px = 1 m)."""
import math
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

# Đồ trong sân trại (thấp, không chặn): (mô hình, số lượng, cỡ) theo loại trại.
CAMP_LOW = {
    "small": [("bones", 2, 1.5), ("log", 1, 1.3)],
    "large": [("rock_small", 2, 1.0), ("stump", 1, 1.3)],
    "medium": [("campfire", 1, 1.4), ("bones", 1, 1.3)],
    "beast": [("stump", 2, 1.4), ("bones", 1, 1.6), ("log", 1, 1.4)],
}
# D-319: nấm (người chơi: to, màu nổi) — một cụm nhỏ sát vách hốc trại pháp sư, không rải ở khoảng trống.
MUSHROOM = ("mushrooms", 0.9)
# Đồ cao, đặt trong vùng chặn quanh hốc: (mô hình, số lượng, cỡ).
CAMP_TALL = {"large": [("crystals", 2, 1.4)], "medium": [("totem", 1, 1.2)], "beast": [], "small": []}
LOW_RING = (190.0, 290.0)    # bán kính đặt đồ thấp quanh tâm trại (quái đứng ở giữa)
TALL_RING = (250.0, 360.0)   # dò chỗ đặt đồ cao (phải nằm trong vùng chặn)
OPEN_SPACING = 520.0         # khoảng cách lưới dò khoảng trống
PATH_KEEP = 160.0           # cách tim lối rừng ≥ (px): đường đi chính trống
SOLID_KEEP = 120.0          # cách vật cản ≥ (px)
OPEN_KINDS = [("flowers", 0.36), ("grass_tuft", 0.26), ("stump", 0.12), ("log", 0.1),
              ("rock_small", 0.08), ("plant_green", 0.08)]


def camps(items, m, solid, rng):
    inner = solid.buffer(-25)
    for c in m["camps"]:
        kind = c["kind"]
        if kind not in CAMP_LOW:
            continue  # bãi boss có đồ riêng (arena.py)
        cx, cy = c["pos"]
        for model, n, sc in CAMP_LOW[kind]:
            for _ in range(n):
                a, d = rng.uniform(0, math.tau), rng.uniform(*LOW_RING)
                p = Point(cx + math.cos(a) * d, cy + math.sin(a) * d)
                if not solid.contains(p):
                    items.append([model, p.x, p.y, rng.uniform(0, math.tau), sc * rng.uniform(0.9, 1.1)])
        if kind == "medium":
            _near_wall(items, (cx, cy), solid, MUSHROOM, rng)
        for model, n, sc in CAMP_TALL[kind]:
            placed, start = 0, rng.uniform(0, math.tau)
            for k in range(24):
                if placed >= n:
                    break
                a = start + k * math.tau / 24
                d = rng.uniform(*TALL_RING)
                p = Point(cx + math.cos(a) * d, cy + math.sin(a) * d)
                if inner.contains(p):  # chân vật nằm trong vùng chặn, sát mép hốc
                    items.append([model, p.x, p.y, rng.uniform(0, math.tau), sc * rng.uniform(0.9, 1.1)])
                    placed += 1


def _near_wall(items, c, solid, prop, rng):
    """Một vật ngay chân vách hốc trại: dò 24 hướng, lấy chỗ trống đầu tiên cách vùng chặn < 0,9 m."""
    start = rng.uniform(0, math.tau)
    for k in range(24):
        a = start + k * math.tau / 24
        for d in (300.0, 260.0, 220.0):
            p = Point(c[0] + math.cos(a) * d, c[1] + math.sin(a) * d)
            if not solid.contains(p) and solid.distance(p) < 90.0:
                items.append([prop[0], p.x, p.y, rng.uniform(0, math.tau), prop[1]])
                return


def open_areas(items, m, solid, wet, paths, rng):
    """Khoảng rừng trống thực chất là các lối rừng rộng 4–8 m giao nhau: rải cụm ở phần lối cách tim lối ≥ PATH_KEEP
    (đường đi chính vẫn trống) và cách vật cản ≥ SOLID_KEEP; tránh nước, lane, trại, base, trụ."""
    lw = m["lane_width"]
    busy = unary_union([wet.buffer(100)] + [LineString(p).buffer(lw / 2 + 60) for p in m["lanes"].values()]
                       + [Point(c["pos"]).buffer(450) for c in m["camps"]] + [Polygon(b["polygon"]) for b in m["bases"]]
                       + [Point(t["pos"]).buffer(300) for t in m["towers"]] + [solid.buffer(SOLID_KEEP)])
    centre = unary_union([line for line, _ in paths]).buffer(PATH_KEEP)
    size = m["world_size"][0]
    y = OPEN_SPACING / 2
    while y < size:
        x = OPEN_SPACING / 2
        while x < size:
            p = Point(x + rng.uniform(-150, 150), y + rng.uniform(-150, 150))
            if not busy.contains(p) and not centre.contains(p):
                _cluster(items, p, rng)
            x += OPEN_SPACING
        y += OPEN_SPACING


def _cluster(items, p, rng):
    for _ in range(rng.randint(2, 4)):
        model = _pick(rng)
        items.append([model, p.x + rng.uniform(-110, 110), p.y + rng.uniform(-110, 110), rng.uniform(0, math.tau), rng.uniform(1.1, 1.5)])


def _pick(rng):
    r = rng.random()
    for model, share in OPEN_KINDS:
        if r < share:
            return model
        r -= share
    return OPEN_KINDS[0][0]
