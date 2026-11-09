#!/usr/bin/env python3
"""D-311: đưa ảnh đá lát vẽ tay (Codex T12) về đá be ấm cùng họ với đá trụ / nhà chính / fountain (người chơi: màu đá
nền, màu trụ phải đồng điệu; ảnh mẫu art_inbox/08_style/ref/highground_ref.png). Giữ nét vẽ: chỉ lấy sáng tối, nén
tương phản (mạch không quá sẫm), tô màu đá `STONE`; điểm ảnh rêu (xanh lá) giữ sắc rêu dịu.

  python3 tools/textures/warm_stone.py vào.png ra.png
"""
import sys
import numpy as np
from PIL import Image

STONE = np.array([156, 140, 114]) / 255.0  # be xám ấm như đá sân ảnh mẫu (~152,135,110) / đá sáng của trụ
MOSS = np.array([112, 118, 70]) / 255.0
CONTRAST = 0.75  # nén sáng tối quanh trung bình (mạch nhạt hơn bản gốc)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def warm(a):
    l = a @ LUMA
    m = l.mean()
    shade = 1 + (l - m) / m * CONTRAST
    out = STONE[None, None, :] * shade[..., None]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = np.clip((g - np.maximum(r, b)) * 12, 0, 1)  # mạch có rêu
    moss = MOSS[None, None, :] * (0.7 + 0.6 * shade[..., None])
    return np.clip(out * (1 - green[..., None]) + moss * green[..., None], 0, 1)


def main():
    a = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float) / 255.0
    Image.fromarray((warm(a) * 255).astype(np.uint8)).save(sys.argv[2])
    print("đã ghi", sys.argv[2])


if __name__ == "__main__":
    main()
