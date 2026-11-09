"""D-310: hình đất cao (base) theo ảnh mẫu người chơi (art_inbox/08_style/ref/highground_ref.png, phương án A "cân bằng –
tự nhiên"). Dùng bởi decor.py. Toạ độ thế giới px (100 px = 1 m).

- Mặt nạ `base` (RG): R đá lát (ảnh flagstones) — nền base là cỏ, đá lát phủ phần lớn, chừa mảng cỏ loang và dải
  cỏ dưới chân tường; lane trong base và sân quanh nhà chính / fountain / trụ trong base lát kín. G rêu: D-313 (người
  chơi: vòng viền quanh công trình xấu → bỏ; quanh trụ có ít rêu xanh) — mảng rêu loang quanh chân mọi trụ.
- Rào base / fountain (MAP-09, MAP-10): D-314 lan can đá `parapet` như rìa map.
"""
import math
import decor_place as DP
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import LineString, Point, Polygon
from shapely.ops import unary_union

M = 100.0
# Bán kính sân lát quanh công trình (px) — theo cỡ mô hình (trụ ~1,4 m, nhà chính ~3 m, fountain ~3 m bề ngang).
PLAZA_R = {"tower": 175.0, "core": 340.0, "fountain": 330.0}
MOSS_R = (35.0, 75.0)  # bán kính đốm rêu quanh chân trụ (px), 5–8 đốm nhỏ lệch tâm mỗi trụ
FRINGE_M = 0.9         # D-311: độ nhòe mép đá lát (m) — shader vẽ dải đất nện ở phần nhòe
PAVE_SHARE = 0.78      # phần nền base lát đá (còn lại mảng cỏ)
PATCH_M = 4.0          # cỡ mảng cỏ / đá (m)
WALL_GRASS = 110.0     # dải cỏ dưới chân tường (px)
PARAPET_STEP = 190.0   # đoạn lan can 2 m, chồng nhẹ (như rìa map, decor.py)


def plazas(m):
    """[(x, y, r)] sân lát quanh mọi trụ, nhà chính, fountain."""
    out = [(*t["pos"], PLAZA_R["tower"]) for t in m["towers"]]
    out += [(*c, PLAZA_R["core"]) for c in m["cores"]]
    out += [(*f, PLAZA_R["fountain"]) for f in m["fountains"]]
    return out


def mask(m, n, T, mask_px, lane_width):
    """Ảnh RG cỡ n×n (lưới mặt nạ decor.py): R đá lát, G rêu quanh trụ."""
    moss = Image.new("L", (n, n), 0)
    dm = ImageDraw.Draw(moss)
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
    bases = unary_union([Polygon(b["polygon"]) for b in m["bases"]])
    for x, y, r in plazas(m):
        if bases.contains(Point(x, y)):  # sân lát chỉ trong base (ngoài base trụ đứng trên đất / cỏ, có rêu)
            dp.ellipse(_box(T, x, y, r), fill=255)
    for t in m["towers"]:
        x, y = t["pos"]
        for _ in range(int(rng.integers(5, 9))):
            a, d = rng.uniform(0, math.tau), rng.uniform(80, 150)
            dm.ellipse(_box(T, x + math.cos(a) * d, y + math.sin(a) * d, rng.uniform(*MOSS_R)), fill=255)
    return pave, moss


def _box(T, x, y, r):
    (x0, y0), (x1, y1) = T([(x - r, y - r), (x + r, y + r)])
    return [x0, y0, x1, y1]


def walls(items, m):
    """D-314: rào base / fountain (MAP-09, MAP-10) = lan can đá của rìa map (`parapet`, Blender — người chơi thấy đá dựng
    Blender sắc nét hơn; bỏ tường + cột Tripo D-310). Đoạn 2 m nối tiếp dọc đường rào."""
    for line in m["render"].get("rock_lines", []):
        if line.get("kind") == "fence":
            DP.along(items, LineString(line["points"]), "parapet", PARAPET_STEP)


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
