#!/usr/bin/env python3
"""D-304: tách tờ 3 góc nhìn (tools/concept_gen.py: trước | ngang | sau trên nền trơn) thành <tên>_front/_side/_back.png
vuông, nhân vật ở giữa — đầu vào cho tools/tripo_gen.py --multiview.

  python3 -I tools/split_turnaround.py <tờ.png> <thư_mục_ra>/<tên>
"""
import sys
from PIL import Image


def columns(im, tol=18):
    """Các khoảng cột có nét vẽ (khác màu nền góc trái trên quá `tol`)."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    bg = rgb.getpixel((2, 2))
    px = rgb.load()
    used = [any(sum(abs(a - b) for a, b in zip(px[x, y], bg)) > tol for y in range(0, h, 2)) for x in range(w)]
    spans, start = [], None
    for x, u in enumerate(used + [False]):
        if u and start is None:
            start = x
        elif not u and start is not None:
            if x - start > w // 40:
                spans.append((start, x))
            start = None
    return spans, bg


def main():
    sheet, base = sys.argv[1], sys.argv[2]
    im = Image.open(sheet).convert("RGB")
    spans, bg = columns(im)
    while len(spans) > 3:  # gộp khe nhỏ (tóc bay, tay tách khỏi thân)
        gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
        i = gaps.index(min(gaps))
        spans[i:i + 2] = [(spans[i][0], spans[i + 1][1])]
    if len(spans) != 3:
        sys.exit(f"cần 3 hình, thấy {len(spans)}")
    h = im.size[1]
    for name, (x0, x1) in zip(("front", "side", "back"), spans):
        crop = im.crop((x0, 0, x1, h))
        side = int(h * 1.0)
        out = Image.new("RGB", (side, side), bg)
        out.paste(crop, ((side - crop.size[0]) // 2, 0))
        out.save(f"{base}_{name}.png")
        print(f"{base}_{name}.png", x0, x1)


if __name__ == "__main__":
    main()
