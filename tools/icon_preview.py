#!/usr/bin/env python3
"""Xem icon ở ĐÚNG cỡ hiển thị trong game (D-129) — duyệt icon phải nhìn ảnh này, không nhìn ảnh 256 px.

  python3 tools/icon_preview.py [thư_mục_icon] [tên_ảnh_ra.png]
  mặc định: art_inbox/04_icons → art_inbox/04_icons/_preview.png

Mỗi icon hiện ở: 48 px (thanh hiệu ứng / ô đồ nhỏ), 64 px (thẻ shop trên điện thoại),
84 px (nút chiêu), cả bản làm tối như món chưa đủ tiền; nền giống bảng shop trong game.
"""
import os, sys
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "art_inbox", "04_icons")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(SRC, "_preview.png")
BG = (33, 38, 51)
SIZES = [48, 64, 84]
CELL_W = sum(SIZES) + 64 + 6 * 10
CELL_H = 84 + 28
COLS = 3


def dim(im):
    r, g, b, a = im.split()
    f = lambda v: int(v * 0.62)
    return Image.merge("RGBA", (r.point(f), g.point(f), b.point(lambda v: int(v * 0.66)), a))


def main():
    names = sorted(n for n in os.listdir(SRC) if n.endswith(".png") and not n.startswith("_"))
    rows = (len(names) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * CELL_W + 10, rows * CELL_H + 10), BG)
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = Image.open(os.path.join(SRC, n)).convert("RGBA")
        x, y = 10 + (i % COLS) * CELL_W, 10 + (i // COLS) * CELL_H
        for s in SIZES:
            if n.startswith("item_"):  # D-130: thẻ vuông bo góc như shop trong game
                d.rounded_rectangle((x - 3, y + 84 - s - 3, x + s + 3, y + 87), radius=6, fill=(22, 29, 45), outline=(82, 102, 140))
            sheet.paste(im.resize((s, s), Image.LANCZOS), (x, y + 84 - s), im.resize((s, s), Image.LANCZOS))
            x += s + 10
        small = dim(im.resize((64, 64), Image.LANCZOS))
        sheet.paste(small, (x, y + 20), small)
        d.text((10 + (i % COLS) * CELL_W, y + 88), n[:-4], fill=(220, 220, 220))
    sheet.save(OUT)
    print("đã lưu", OUT, len(names), "icon")


if __name__ == "__main__":
    main()
