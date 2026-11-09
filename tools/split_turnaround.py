#!/usr/bin/env python3
"""D-304: tách tờ 3 góc nhìn (tools/concept_gen.py: trước | ngang | sau trên nền trơn) thành <tên>_front/_side/_back.png
vuông 1024 px, cắt sát hình, cùng cỡ khung cho 3 hướng (D-307), nhân vật ở giữa — đầu vào cho tools/tripo_gen.py --multiview.

  python3 -I tools/split_turnaround.py <tờ.png> <thư_mục_ra>/<tên>
"""
import sys
from PIL import Image, ImageChops


def columns(im, tol=18, min_frac=40):
    """Các khoảng cột có nét vẽ (khác màu nền góc trái trên quá `tol`)."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    bg = rgb.getpixel((2, 2))
    px = rgb.load()
    count = [sum(sum(abs(a - b) for a, b in zip(px[x, y], bg)) > tol for y in range(0, h, 2)) for x in range(w)]
    used = [c > 0 for c in count]
    spans, start = [], None
    for x, u in enumerate(used + [False]):
        if u and start is None:
            start = x
        elif not u and start is not None:
            if x - start > w // min_frac:
                spans.append((start, x))
            start = None
    return spans, bg, count


def _main_blob(crop, bg, tol=18):
    """Chỉ giữ mảng nét lớn nhất (mẩu cánh / đuôi của hình bên cạnh dính vào khung thì xóa thành nền)."""
    import numpy as np
    from scipy import ndimage
    a = np.asarray(crop).astype(int)
    mask = np.abs(a - np.array(bg)).sum(axis=2) > tol
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=2))
    if n <= 1:
        return crop
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep = lab == (1 + int(np.argmax(sizes)))
    a[~keep] = bg
    return Image.fromarray(a.astype("uint8"))


def main():
    sheet, base = sys.argv[1], sys.argv[2]
    im = Image.open(sheet).convert("RGB")
    spans, bg, count = columns(im)
    while len(spans) < 3 and spans:  # hai hình chạm nhau (cánh rồng): cắt hình rộng nhất ở cột ít nét nhất
        i = max(range(len(spans)), key=lambda k: spans[k][1] - spans[k][0])
        x0, x1 = spans[i]
        lo, hi = x0 + (x1 - x0) // 4, x1 - (x1 - x0) // 4
        cut = min(range(lo, hi), key=lambda x: count[x])
        spans[i:i + 1] = [(x0, cut), (cut + 1, x1)]
    while len(spans) > 3:  # gộp khe nhỏ (tóc bay, tay tách khỏi thân)
        gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
        i = gaps.index(min(gaps))
        spans[i:i + 2] = [(spans[i][0], spans[i + 1][1])]
    if len(spans) != 3:
        sys.exit(f"cần 3 hình, thấy {len(spans)}")
    h = im.size[1]
    crops = [_main_blob(im.crop((x0, 0, x1, h)), bg) for x0, x1 in spans]
    boxes = [ImageChops.difference(c, Image.new("RGB", c.size, bg)).convert("L").point(lambda v: 255 if v > 18 else 0).getbbox()
             for c in crops]
    top, bottom = min(b[1] for b in boxes), max(b[3] for b in boxes)
    side = int(max(max(b[2] - b[0] for b in boxes), bottom - top) * 1.12)  # cùng một cỡ khung cho 3 hướng (Tripo multiview)
    for name, c, b, (x0, x1) in zip(("front", "side", "back"), crops, boxes, spans):
        out = Image.new("RGB", (side, side), bg)
        part = c.crop((b[0], top, b[2], bottom))
        out.paste(part, ((side - part.size[0]) // 2, (side - part.size[1]) // 2))
        out.resize((1024, 1024), Image.LANCZOS).save(f"{base}_{name}.png")
        print(f"{base}_{name}.png", x0, x1)


if __name__ == "__main__":
    main()
