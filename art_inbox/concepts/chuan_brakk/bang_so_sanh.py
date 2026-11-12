#!/usr/bin/env python3
"""D-364: bảng so sánh concept — mỗi ảnh cắt sát phần hình (bỏ nền trắng), đưa về cùng chiều cao khung, xếp cạnh nhau
có nhãn. Phong Tiễn: Brakk (mẫu) | Phong Tiễn hiện tại | PA1 | PA2 | PA3.
  python3 art_inbox/concepts/chuan_brakk/bang_so_sanh.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..")
H = 900
PAD = 40
FONT = os.path.join(ROOT, "assets", "fonts", "Carlito-Bold.ttf")


def trim(path, box=None):
    src = Image.open(path).convert("RGBA")
    im = Image.new("RGB", src.size, "white")
    im.paste(src, (0, 0), src)  # nền trong suốt → trắng
    if box:
        im = im.crop(box)
    a = np.array(im).astype(int)
    ys, xs = np.nonzero((a < 238).any(axis=2))
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def board(cells, dst):
    ims = [(lab, im.resize((round(im.width * H / im.height), H), Image.LANCZOS)) for lab, im in cells]
    out = Image.new("RGB", (sum(i.width for _, i in ims) + PAD * (len(ims) + 1), H + PAD * 2 + 60), "white")
    d = ImageDraw.Draw(out)
    f = ImageFont.truetype(FONT, 40)
    x = PAD
    for lab, im in ims:
        out.paste(im, (x, PAD))
        w = d.textlength(lab, font=f)
        d.text((x + (im.width - w) / 2, H + PAD + 10), lab, fill=(40, 44, 42), font=f)
        x += im.width + PAD
    out.save(dst)
    print(dst, out.size)


sheet = Image.open(os.path.join(ROOT, "art_inbox", "03_heroes", "brakk_sheet.png"))
board([("Brakk (chuẩn)", trim(os.path.join(ROOT, "art_inbox", "03_heroes", "brakk_sheet.png"), (0, 0, sheet.width // 2, sheet.height))),
       ("Phong Tiễn hiện tại", trim(os.path.join(ROOT, "art_inbox", "concepts", "body", "phong_tien_body.png"))),
       ("PA1 · tỉ lệ Brakk", trim(os.path.join(HERE, "phong_tien", "pa1.png"))),
       ("PA2 · cao hơn, ~4 đầu", trim(os.path.join(HERE, "phong_tien", "pa2.png"))),
       ("PA3 · giáp nhẹ kiểu Brakk", trim(os.path.join(HERE, "phong_tien", "pa3.png")))],
      os.path.join(HERE, "phong_tien", "bang_so_sanh.png"))
