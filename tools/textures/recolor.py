#!/usr/bin/env python3
"""Đưa ảnh nền vẽ tay (Codex) về bảng màu chung của game (D-191, D-193): giữ nét và sáng tối — giảm độ rực, nhân
từng kênh để màu trung bình phần đất (điểm ảnh rực nhất) bằng màu đất nện `DIRT` của đường rừng; rồi điểm ảnh
càng ít màu (đá) càng kéo về xám đá `STONE` (chuyển dần theo độ rực, không cắt cứng nên không loang mép) để đá
tách khỏi đất.

  python3 tools/textures/recolor.py vào.png ra.png
"""
import sys
import numpy as np
from PIL import Image

DIRT = np.array([174, 140, 92]) / 255.0    # = dirt_color #AE8C5C (units_3d.json), đất nện đường rừng
STONE = np.array([158, 151, 137]) / 255.0  # xám đá ấm (cùng họ đá rừng / rào, D-186), không ngả lạnh cạnh đất vàng
LUMA = np.array([0.2126, 0.7152, 0.0722])


SATURATION = 0.7   # giữ 70% độ rực
STONE_DARKEN = 0.97  # đá tối hơn đất chút ít cho tách nền


def recolor(a):
    rgb = a[..., :3]
    l = (rgb @ LUMA)[..., None]
    out = l + (rgb - l) * SATURATION
    sat = (rgb.max(-1) - rgb.min(-1)) / np.maximum(rgb.max(-1), 1e-4)
    dirt = out[sat > np.percentile(sat, 60)].mean(0)  # phần đất: 40% điểm ảnh rực nhất
    out = out * (DIRT / dirt)[None, None, :]
    lo, hi = np.percentile(sat, 15), np.percentile(sat, 55)
    stone = (1 - np.clip((sat - lo) / max(hi - lo, 1e-4), 0, 1)) ** 1.5  # 1 = chắc là đá
    l = (out @ LUMA)[..., None]
    grey = STONE[None, None, :] * l / float(STONE @ LUMA) * STONE_DARKEN
    return np.clip(out * (1 - stone[..., None]) + grey * stone[..., None], 0, 1)


def main():
    a = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float) / 255.0
    Image.fromarray((recolor(a) * 255).astype(np.uint8)).save(sys.argv[2])
    print("đã ghi", sys.argv[2])


if __name__ == "__main__":
    main()
