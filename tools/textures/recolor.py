#!/usr/bin/env python3
"""Đưa ảnh nền vẽ tay (Codex) về bảng màu chung của game (D-191): giữ nét và sáng tối, chỉnh màu toàn ảnh —
giảm độ rực (đá vốn ít màu nên về xám), rồi nhân từng kênh để màu trung bình của phần đất (điểm ảnh rực nhất)
bằng màu đất nện `DIRT` của đường rừng. Không tách vùng nên không loang mép.

  python3 tools/textures/recolor.py vào.png ra.png
"""
import sys
import numpy as np
from PIL import Image

DIRT = np.array([174, 140, 92]) / 255.0    # = dirt_color #AE8C5C (units_3d.json), đất nện đường rừng
LUMA = np.array([0.2126, 0.7152, 0.0722])


SATURATION = 0.7   # giữ 70% độ rực


def recolor(a):
    rgb = a[..., :3]
    l = (rgb @ LUMA)[..., None]
    out = l + (rgb - l) * SATURATION
    sat = (rgb.max(-1) - rgb.min(-1)) / np.maximum(rgb.max(-1), 1e-4)
    dirt = out[sat > np.percentile(sat, 60)].mean(0)  # phần đất: 40% điểm ảnh rực nhất
    return np.clip(out * (DIRT / dirt)[None, None, :], 0, 1)


def main():
    a = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float) / 255.0
    Image.fromarray((recolor(a) * 255).astype(np.uint8)).save(sys.argv[2])
    print("đã ghi", sys.argv[2])


if __name__ == "__main__":
    main()
