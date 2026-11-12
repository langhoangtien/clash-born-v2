#!/usr/bin/env python3
"""D-371: cắt từng tướng khỏi bảng concept (lưới cột × hàng, nền trơn) thành PNG nền trong, bỏ dòng tên ở đáy ô, cắt sát
hình — để đặt thử ở cỡ thật trong trận (kiem_ke_tran.gd --cutouts).

  python3 -I tools/models/preview/cat_concept.py bảng.png thư_mục_ra tên1,tên2,… [--cols 5 --rows 2 --label 0.13]
"""
import argparse, os
import numpy as np
from PIL import Image
from scipy import ndimage


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("out"); ap.add_argument("names")
    ap.add_argument("--cols", type=int, default=5); ap.add_argument("--rows", type=int, default=2)
    ap.add_argument("--label", type=float, default=0.13, help="phần đáy mỗi ô là dòng tên (bỏ)")
    ap.add_argument("--tol", type=float, default=60.0)
    ap.add_argument("--hole", type=float, default=1500.0, help="lỗ nền kín nhỏ hơn (điểm ảnh) thì giữ là hình")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    im = np.asarray(Image.open(a.sheet).convert("RGB")).astype(float)
    h, w = im.shape[:2]
    names = a.names.split(",")
    for k, name in enumerate(names):
        r, c = divmod(k, a.cols)
        cell = im[r * h // a.rows:(r + 1) * h // a.rows, c * w // a.cols:(c + 1) * w // a.cols]
        cell = cell[: int(cell.shape[0] * (1 - a.label))]
        bg = np.median(np.concatenate([cell[:4].reshape(-1, 3), cell[:, :4].reshape(-1, 3), cell[:, -4:].reshape(-1, 3)]), axis=0)
        far = np.abs(cell - bg).sum(axis=2) > a.tol
        lab, n = ndimage.label(ndimage.binary_closing(far, iterations=2))
        keep = lab == (1 + int(np.argmax(ndimage.sum(far, lab, range(1, n + 1)))))  # mảng lớn nhất = nhân vật (+ vũ khí dính)
        full = ndimage.binary_fill_holes(keep)
        keep &= ndimage.binary_dilation(far, iterations=1)
        holes, m = ndimage.label(full & ~keep)  # lỗ lớn = nền kẹt giữa hai chân / tay → bỏ; lỗ nhỏ = mảng giáp xám giống nền → giữ
        sizes = ndimage.sum(np.ones_like(holes), holes, range(1, m + 1))
        keep |= np.isin(holes, 1 + np.nonzero(sizes < a.hole)[0])
        ys, xs = np.nonzero(keep)
        rgba = np.dstack([cell, keep * 255.0]).astype(np.uint8)[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        Image.fromarray(rgba, "RGBA").save(os.path.join(a.out, name + ".png"))
        print(name, rgba.shape[1], "×", rgba.shape[0])


if __name__ == "__main__":
    main()
