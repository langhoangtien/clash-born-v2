#!/usr/bin/env python3
"""D-361 (bản thử, không sửa assets/): ráp bảng "trước → sau" cho chuẩn khung icon — khung vẽ bằng code đè lên phần hình
của icon hiện có (không vẽ lại hình). Hai phương án khung:
  pa1 — khung dày kiểu đời mới (viền 11 / bán kính 125), R viền đôi;
  pa2 — viền mảnh kiểu đời cũ (viền 6 / 125), hình lấp nhiều hơn.
Cả hai: hình tròn lấp 98% ô 256, nội tại viền bạc, chủ động viền vàng, trạng thái = hình trên đĩa tối + viền mảnh
đỏ (bất lợi) / lục (có lợi); chân dung = bán thân trong đĩa tối viền vàng.

  python3 tools/icons/khung_thu.py   → art_inbox/kiem_ke/thu_icon/
"""
import os
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
ART = os.path.join(ROOT, "assets", "art")
OUT = os.path.join(ROOT, "art_inbox", "kiem_ke", "thu_icon")
SS = 4                    # vẽ to gấp 4 rồi thu nhỏ cho mịn
SIZE = 256
R_OUT = 125               # bán kính ngoài của khung trong ô 256
OLD_RING = 13             # độ dày viền vẽ sẵn trong icon hiện có (đo: 11–12 px + nét tối)
RING = {"pa1": 11, "pa2": 6}
GOLD = ((236, 190, 96), (150, 100, 40))
SILVER = ((196, 204, 218), (112, 120, 138))
RED = ((226, 104, 92), (150, 52, 48))
GREEN = ((120, 204, 132), (48, 122, 70))
DARK = (22, 26, 38)
TILE = (58, 62, 60)
SKILLS = [("brakk", "innate"), ("brakk", "q"), ("brakk", "w"), ("brakk", "r"), ("phong_tien", "innate"), ("phong_tien", "q"), ("phong_tien", "w"), ("phong_tien", "r")]
STATUS = [("stun", RED), ("hex", RED), ("silence", RED), ("magic_immune", GREEN)]
PORTRAITS = ["duy_anh", "brakk", "gorran", "myra", "vexa", "noctis", "phong_tien", "huyet_cu_nhan", "thach_giap", "tho_san"]


def load(name):
    return Image.open(os.path.join(ART, name + ".png")).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)


def disc_of(im):
    """Tâm và bán kính ngoài của hình tròn trong icon (theo alpha)."""
    a = np.array(im)[:, :, 3] > 128
    ys, xs = np.nonzero(a)
    return (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, (xs.max() - xs.min() + ys.max() - ys.min()) / 4


def ring(canvas, r_out, width, colors, double=False):
    """Vành khuyên chuyển sắc sáng (trên-trái) → tối (dưới-phải), nét tối hai mép; `double`: thêm vành mảnh bên trong."""
    n = SIZE * SS
    yy, xx = np.mgrid[0:n, 0:n]
    c = n / 2
    d = np.hypot(xx - c, yy - c) / SS
    t = np.clip(((xx - c) + (yy - c)) / (2 * r_out * SS) * 0.9 + 0.5, 0, 1)[..., None]
    col = np.array(colors[0]) * (1 - t) + np.array(colors[1]) * t
    layer = np.zeros((n, n, 4), np.uint8)
    edge = np.array(DARK)
    bands = [(r_out - width, r_out)] + ([(r_out - width - 5, r_out - width - 2.5)] if double else [])
    for lo, hi in bands:
        m = (d >= lo) & (d <= hi)
        layer[m, :3] = col[m]
        layer[m, 3] = 255
        for e in (lo, hi):
            me = np.abs(d - e) <= 0.8
            layer[me, :3] = edge
            layer[me, 3] = 255
    canvas.alpha_composite(Image.fromarray(layer))


def framed(art, art_r, cx, cy, r_out, width, colors, double=False, fill=None):
    """Đặt phần hình (đĩa bán kính art_r quanh cx, cy của `art`) vào khung mới; `fill`: nền đĩa tối, hình thu vào giữa."""
    n = SIZE * SS
    canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    inner = (r_out - width) * SS
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).ellipse((n / 2 - inner, n / 2 - inner, n / 2 + inner, n / 2 + inner), fill=255)
    if fill is not None:
        canvas.paste(Image.new("RGBA", (n, n), fill + (255,)), (0, 0), mask)
    k = inner / art_r * (0.68 if fill is not None else 1.0)
    big = art.resize((round(SIZE * k), round(SIZE * k)), Image.LANCZOS)
    pos = (round(n / 2 - cx * k), round(n / 2 - cy * k))
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    layer.paste(big, pos)
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", (n, n), 0), mask))
    canvas.alpha_composite(layer)
    ring(canvas, r_out, width, colors, double)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def skill(hero, slot, pa):
    im = load("%s_%s" % (hero, slot))
    cx, cy, r = disc_of(im)
    colors = SILVER if slot == "innate" else GOLD
    return framed(im, r - OLD_RING, cx, cy, R_OUT, RING[pa], colors, slot == "r" and pa == "pa1")


def status(name, colors, pa):
    im = load(name)
    a = np.array(im)[:, :, 3] > 128
    ys, xs = np.nonzero(a)
    r = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2
    return framed(im, r, (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, R_OUT, max(4, RING[pa] - 4), colors, fill=DARK)


def portrait(name, pa):
    im = load(name + "_portrait")
    n = SIZE * SS
    canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    inner = (R_OUT - RING[pa]) * SS
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).ellipse((n / 2 - inner, n / 2 - inner, n / 2 + inner, n / 2 + inner), fill=255)
    canvas.paste(Image.new("RGBA", (n, n), DARK + (255,)), (0, 0), mask)
    big = im.resize((n, n), Image.LANCZOS)
    big.putalpha(Image.composite(big.getchannel("A"), Image.new("L", (n, n), 0), mask))
    canvas.alpha_composite(big)
    ring(canvas, R_OUT, RING[pa], GOLD)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def sheet(cells, cols, cell, dst):
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGB", (cols * cell, rows * cell), TILE)
    for i, im in enumerate(cells):
        im = im.resize((cell - 12, cell - 12), Image.LANCZOS)
        out.paste(im, ((i % cols) * cell + 6, (i // cols) * cell + 6), im)
    out.save(dst, quality=88)


def main():
    os.makedirs(OUT, exist_ok=True)
    before = [load("%s_%s" % s) for s in SKILLS[:4]] + [load(n) for n, _ in STATUS[:2]] + [load("%s_%s" % s) for s in SKILLS[4:]] + [load(n) for n, _ in STATUS[2:]]
    sheet(before, 6, 160, os.path.join(OUT, "icon_truoc.png"))
    sheet([load(p + "_portrait") for p in PORTRAITS], 5, 160, os.path.join(OUT, "chan_dung_truoc.png"))
    for pa in RING:
        cells = [skill(h, s, pa) for h, s in SKILLS[:4]] + [status(n, c, pa) for n, c in STATUS[:2]]
        cells += [skill(h, s, pa) for h, s in SKILLS[4:]] + [status(n, c, pa) for n, c in STATUS[2:]]
        sheet(cells, 6, 160, os.path.join(OUT, "icon_%s.png" % pa))
        sheet([portrait(p, pa) for p in PORTRAITS], 5, 160, os.path.join(OUT, "chan_dung_%s.png" % pa))
    print("khung_thu:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
