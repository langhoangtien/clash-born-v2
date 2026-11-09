"""D-310: hình đất cao (base) theo ảnh mẫu người chơi (art_inbox/08_style/ref/highground_ref.png, phương án A "cân bằng –
tự nhiên"). Dùng bởi decor.py. Toạ độ thế giới px (100 px = 1 m).

- Mặt nạ `base` (RG): R đá lát (ảnh flagstones) — nền base là cỏ, đá lát phủ phần lớn, chừa mảng cỏ loang và dải
  cỏ dưới chân tường; lane trong base và sân quanh công trình lát kín. G viền sân: vòng đá quanh chân trụ, nhà
  chính, fountain (ranh giới công trình / nền) — 255 đá viền sáng, ~110 mạch sẫm hai bên.
- Tường rào base / fountain (MAP-09, MAP-10): đoạn tường đá `base_wall` giữa các cột `base_pillar_<phe>` (đèn vàng +
  cờ màu phe) — cột ở mọi đỉnh đường rào và chia đều đoạn dài.
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

M = 100.0
# Bán kính sân lát quanh công trình (px) — theo cỡ mô hình (trụ ~1,4 m, nhà chính ~3 m, fountain ~3 m bề ngang).
PLAZA_R = {"tower": 175.0, "core": 340.0, "fountain": 330.0}
CURB_W = 40.0          # bề rộng vòng đá viền sân (px); G = 255 đá viền sáng
CURB_EDGE = 10.0       # mạch sẫm hai bên vòng (px); G ≈ 110
PAVE_SHARE = 0.78      # phần nền base lát đá (còn lại mảng cỏ)
PATCH_M = 4.0          # cỡ mảng cỏ / đá (m)
WALL_GRASS = 110.0     # dải cỏ dưới chân tường (px)
EDGE_SKIP = 80.0       # không đặt cột sát khung map (px)
PILLAR_MAX = 620.0     # khoảng cách tối đa giữa hai cột tường (px)
WALL_STEP = 230.0      # đoạn tường base_wall dài 2,5 m (cao 0,9 m) → bước 2,3 m, chồng nhẹ


def team_of(pt, m):
    f = m["fountains"]
    return min((0, 1), key=lambda t: math.dist(pt, f[t]))


def plazas(m):
    """[(x, y, r)] sân lát quanh mọi trụ, nhà chính, fountain."""
    out = [(*t["pos"], PLAZA_R["tower"]) for t in m["towers"]]
    out += [(*c, PLAZA_R["core"]) for c in m["cores"]]
    out += [(*f, PLAZA_R["fountain"]) for f in m["fountains"]]
    return out


def mask(m, n, T, mask_px, lane_width):
    """Ảnh RG cỡ n×n (lưới mặt nạ decor.py): R đá lát, G viền sân."""
    curb = Image.new("L", (n, n), 0)
    dc = ImageDraw.Draw(curb)
    inside = Image.new("L", (n, n), 0)
    di = ImageDraw.Draw(inside)
    for b in m["bases"]:
        di.polygon(T(b["polygon"]), fill=255)
    rng = np.random.default_rng(310)
    cells = max(4, int(n * mask_px / (PATCH_M * M)))
    noise = np.array(Image.fromarray((rng.random((cells, cells)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), float)
    patchy = (noise > np.percentile(noise, (1 - PAVE_SHARE) * 100)).astype(float)
    walls = Image.new("L", (n, n), 0)
    dw = ImageDraw.Draw(walls)
    for line in m["render"].get("rock_lines", []):
        if line.get("kind") == "fence":
            dw.line(T(line["points"]), fill=255, width=int(2 * WALL_GRASS / mask_px), joint="curve")
    a = np.array(inside, float) / 255 * patchy * (1 - np.array(walls, float) / 255)
    pave = Image.fromarray((a * 255).astype(np.uint8))
    for pts in m["lanes"].values():  # lane trong base lát kín (cắt theo base ở dưới)
        lanes = Image.new("L", (n, n), 0)
        ImageDraw.Draw(lanes).line(T(pts), fill=255, width=int((lane_width + 40) / mask_px), joint="curve")
        pave = Image.fromarray(np.maximum(np.array(pave), np.minimum(np.array(lanes), np.array(inside))))
    dp = ImageDraw.Draw(pave)
    for x, y, r in plazas(m):
        (x0, y0), (x1, y1) = T([(x - r, y - r), (x + r, y + r)])
        dp.ellipse([x0, y0, x1, y1], fill=255)
        w = max(1, int(CURB_W / mask_px))
        e = max(1, int(CURB_EDGE / mask_px))
        dc.ellipse([x0 - e, y0 - e, x1 + e, y1 + e], outline=110, width=w + 2 * e)  # mạch sẫm hai bên vòng
        dc.ellipse([x0, y0, x1, y1], outline=255, width=w)
    return pave, curb


def walls(items, m):
    """Tường rào base / fountain: cột ở đỉnh + chia đều đoạn dài, đoạn tường giữa các cột."""
    for line in m["render"].get("rock_lines", []):
        if line.get("kind") != "fence":
            continue
        pts = line["points"]
        team = ("blue", "red")[team_of(pts[len(pts) // 2], m)]
        posts = [tuple(pts[0])]
        for a, b in zip(pts, pts[1:]):
            span = math.dist(a, b)
            k = max(1, math.ceil(span / PILLAR_MAX))
            posts += [(a[0] + (b[0] - a[0]) * i / k, a[1] + (b[1] - a[1]) * i / k) for i in range(1, k + 1)]
        for a, b in zip(posts, posts[1:]):
            _wall_run(items, a, b)
        size = m["world_size"][0]
        for p in posts:
            if min(p[0], p[1], size - p[0], size - p[1]) < EDGE_SKIP:
                continue  # đầu rào chạm khung map: đã là vực / lan can (D-197)
            items.append(["base_pillar_" + team, p[0], p[1], 0.0, 1.0])  # mặt cờ quay về camera (nam)


def _wall_run(items, a, b):
    span = math.dist(a, b)
    k = max(1, math.ceil(span / WALL_STEP))
    ang = -math.atan2(b[1] - a[1], b[0] - a[0])
    for i in range(k):
        t = (i + 0.5) / k
        items.append(["base_wall", a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, ang + (math.pi if i % 2 else 0.0), 1.0])


def tufts(items, m, rng):
    """Khóm cỏ quanh mép sân công trình trong base (che nét tròn đều của vòng viền)."""
    bases = unary_union([Polygon(b["polygon"]) for b in m["bases"]])
    for x, y, r in plazas(m):
        if not bases.contains(Point(x, y)):
            continue
        for _ in range(int(r / 40)):
            a = rng.uniform(0, math.tau)
            d = r + rng.uniform(20, 90)
            items.append(["grass_tuft", x + math.cos(a) * d, y + math.sin(a) * d, rng.uniform(0, 6.28), rng.uniform(0.7, 1.0)])
