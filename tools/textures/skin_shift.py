#!/usr/bin/env python3
"""D-322: bản ảnh màu đổi sắc da (Gorran Cuồng Hóa: da xanh lá → đỏ). Điểm ảnh có sắc độ trong `--hue` (độ) và đủ đậm
đổi sang sắc `--to` (giữ độ sáng, nhân độ đậm `--sat`); chuyển dần ở mép dải sắc độ nên không loang.

  python3 tools/textures/skin_shift.py vào.jpg ra.jpg [--hue 50-150] [--to 4] [--sat 1.15]
"""
import argparse
import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--hue", default="50-150")
    ap.add_argument("--to", type=float, default=4.0)
    ap.add_argument("--sat", type=float, default=1.15)
    a = ap.parse_args()
    lo, hi = (float(x) for x in a.hue.split("-"))
    hsv = np.array(Image.open(a.src).convert("RGB").convert("HSV")).astype(float)
    h = hsv[..., 0] * 360 / 255
    edge = 6.0
    w = np.clip((h - lo) / edge, 0, 1) * np.clip((hi - h) / edge, 0, 1) * np.clip((hsv[..., 1] - 50) / 40, 0, 1)
    hsv[..., 0] = hsv[..., 0] * (1 - w) + (a.to * 255 / 360) * w
    hsv[..., 1] = np.clip(hsv[..., 1] * (1 + (a.sat - 1) * w), 0, 255)
    Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB").save(a.dst, quality=90)
    print("→", a.dst, f"đổi {(w > 0.5).mean():.0%} điểm ảnh")


if __name__ == "__main__":
    main()
