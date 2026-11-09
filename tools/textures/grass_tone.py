#!/usr/bin/env python3
"""D-313: cỏ vẽ tay Codex (T14, art_inbox/15_ground/grass.png) → ảnh cỏ của game: giảm độ rực, hạ sáng nhẹ, tăng tương
phản nét cọ — cỏ ảnh gốc hơi gắt và phẳng khi phủ diện rộng trong game.

  python3 tools/textures/grass_tone.py vào.png ra.png
"""
import sys
import numpy as np
from PIL import Image

SATURATION = 0.82
BRIGHTNESS = 0.9
DETAIL = 1.35  # nhân chênh sáng tối quanh trung bình
LUMA = np.array([0.2126, 0.7152, 0.0722])


def main():
    a = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float) / 255.0
    l = (a @ LUMA)[..., None]
    a = l + (a - l) * SATURATION
    a = (a - a.mean((0, 1))) * DETAIL + a.mean((0, 1))
    Image.fromarray((np.clip(a * BRIGHTNESS, 0, 1) * 255).astype(np.uint8)).save(sys.argv[2])
    print("đã ghi", sys.argv[2])


if __name__ == "__main__":
    main()
