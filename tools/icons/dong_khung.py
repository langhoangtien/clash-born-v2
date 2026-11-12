#!/usr/bin/env python3
"""D-362: đóng khung icon theo chuẩn khung (D-361 PA1, người chơi duyệt A5) — khung vẽ bằng code đè lên phần hình của
ảnh gốc chưa khung, ghi thẳng vào assets/art (HUD không vẽ khung lúc chạy).
  Ảnh gốc: art_inbox/icons/goc/<id>.png — lần chạy đầu chép từ assets/art; về sau luôn đóng khung từ đây, nên đổi
  quy tắc rồi chạy lại là đóng lại được, không chồng khung.
  Quy tắc: ô vuông, hình tròn bán kính 125 / 128; khung dày 11; nội tại viền bạc, Q / W viền vàng, R viền vàng đôi;
  trạng thái (ảnh 64) = hình trên đĩa tối, viền mảnh đỏ (hiệu ứng tag debuff hoặc không tag) / lục (tag buff);
  chân dung = bán thân trên đĩa tối viền vàng. Icon đồ không đổi.

  python3 tools/icons/dong_khung.py [--before=<thư mục>]   (--before: ghi bảng ảnh trước / sau để duyệt)
"""
import glob, os, re, shutil, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
ART = os.path.join(ROOT, "assets", "art")
GOC = os.path.join(ROOT, "art_inbox", "icons", "goc")
EFFECTS = os.path.join(ROOT, "content", "effects")
HEROES = os.path.join(ROOT, "content", "heroes")
SS = 4                    # vẽ to gấp 4 rồi thu nhỏ cho mịn
SIZE = 256
R_OUT = 125               # bán kính ngoài của khung trong ô 256
OLD_RING = 13             # độ dày viền vẽ sẵn trong icon hiện có (đo: 11–12 px + nét tối)
RING = 11
GOLD = ((236, 190, 96), (150, 100, 40))
SILVER = ((196, 204, 218), (112, 120, 138))
RED = ((226, 104, 92), (150, 52, 48))
GREEN = ((120, 204, 132), (48, 122, 70))
DARK = (22, 26, 38)
TILE = (58, 62, 60)
SLOTS = ["innate", "q", "w", "r"]


def load(name):
    """Ảnh gốc chưa khung, phóng về ô 256."""
    return Image.open(os.path.join(GOC, name + ".png")).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)


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


def skill(name):
    im = load(name)
    cx, cy, r = disc_of(im)
    slot = name.rsplit("_", 1)[1]
    return framed(im, r - OLD_RING, cx, cy, R_OUT, RING, SILVER if slot == "innate" else GOLD, slot == "r")


def status(name, harmful):
    im = load(name)
    a = np.array(im)[:, :, 3] > 128
    ys, xs = np.nonzero(a)
    r = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2
    return framed(im, r, (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, R_OUT, RING - 4, RED if harmful else GREEN, fill=DARK)


def portrait(name):
    im = load(name)
    n = SIZE * SS
    canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    inner = (R_OUT - RING) * SS
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).ellipse((n / 2 - inner, n / 2 - inner, n / 2 + inner, n / 2 + inner), fill=255)
    canvas.paste(Image.new("RGBA", (n, n), DARK + (255,)), (0, 0), mask)
    big = im.resize((n, n), Image.LANCZOS)
    big.putalpha(Image.composite(big.getchannel("A"), Image.new("L", (n, n), 0), mask))
    canvas.alpha_composite(big)
    ring(canvas, R_OUT, RING, GOLD)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def targets():
    """[(id, cách đóng khung)] — chiêu tướng, trạng thái (ảnh 64 × 64), chân dung; lấy từ content."""
    heroes = sorted(os.path.basename(f)[:-5] for f in glob.glob(os.path.join(HEROES, "*.tres")))
    out = [("%s_%s" % (h, s), skill) for h in heroes for s in SLOTS]
    out += [(h + "_portrait", portrait) for h in heroes]
    tags = {}
    for f in glob.glob(os.path.join(EFFECTS, "*.tres")):
        txt = open(f, encoding="utf-8").read()
        art = re.search(r'^art_id = &"(\w+)"$', txt, re.M)
        if art:
            tags.setdefault(art.group(1), set()).update(re.findall(r'&"(buff|debuff)"', txt))
    for f in sorted(glob.glob(os.path.join(ART, "*.png"))):
        name = os.path.basename(f)[:-4]
        src = os.path.join(GOC, name + ".png")
        size = Image.open(src if os.path.exists(src) else f).size
        if size == (64, 64) and name in tags:
            harmful = "buff" not in tags[name]  # không tag (lốc xoáy): coi là khống chế
            out.append((name, lambda n, h=harmful: status(n, h)))
    return out


def sheet(cells, cols, cell, dst):
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGB", (cols * cell, rows * cell), TILE)
    for i, im in enumerate(cells):
        im = im.resize((cell - 12, cell - 12), Image.LANCZOS)
        out.paste(im, ((i % cols) * cell + 6, (i // cols) * cell + 6), im)
    out.save(dst, quality=88)


def main():
    os.makedirs(GOC, exist_ok=True)
    before = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--before=")), "")
    done = []
    for name, make in targets():
        src = os.path.join(GOC, name + ".png")
        dst = os.path.join(ART, name + ".png")
        if not os.path.exists(src):
            shutil.copyfile(dst, src)  # lần đầu: giữ ảnh chưa khung
        size = Image.open(src).size
        make(name).resize(size, Image.LANCZOS).save(dst)
        done.append(name)
    if before:
        os.makedirs(before, exist_ok=True)
        for kind, names in [("chieu", [n for n in done if n.split("_")[-1] in SLOTS and not n.endswith("_portrait")]), ("chan_dung", [n for n in done if n.endswith("_portrait")]),
                            ("trang_thai", [n for n in done if Image.open(os.path.join(ART, n + ".png")).size == (64, 64)])]:
            cols = 8 if kind == "chieu" else (5 if kind == "chan_dung" else 8)
            for tag, folder in [("truoc", GOC), ("sau", ART)]:
                sheet([Image.open(os.path.join(folder, n + ".png")).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS) for n in names], cols, 128, os.path.join(before, "%s_%s.png" % (kind, tag)))
    print("dong_khung: %d icon" % len(done))


if __name__ == "__main__":
    main()
