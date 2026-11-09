#!/usr/bin/env python3
"""D-312: đưa ảnh đá lát vẽ tay (Codex T12) về **tông đá chung của game** — xám trung tính chỗ sáng, ngả xanh lạnh chỗ
tối, như vách đá ảnh mẫu (art_inbox/08_style/ref/lane_ref.png) và lan can rìa map (người chơi thích màu lạnh này; D-311
tô be ấm bị bỏ). Giữ nét vẽ: chỉ lấy sáng tối, nén tương phản, ánh xạ qua thang màu `RAMP`; mạch có rêu giữ sắc rêu.

  python3 tools/textures/stone_tint.py vào.png ra.png
"""
import sys
import numpy as np
from PIL import Image

# Thang màu đá (sRGB): tối (mạch) → giữa → sáng. Lấy từ vách đá ảnh mẫu (sáng ~145,142,142; tối ~45,57,72).
RAMP = np.array([[78, 86, 98], [132, 135, 138], [172, 171, 168]]) / 255.0
MOSS = np.array([96, 112, 62]) / 255.0
CONTRAST = 0.55
LUMA = np.array([0.2126, 0.7152, 0.0722])


def ramp(t):
    t = np.clip(t, 0, 1)[..., None]
    lo = RAMP[0] + (RAMP[1] - RAMP[0]) * np.clip(t * 2, 0, 1)
    return np.where(t < 0.5, lo, RAMP[1] + (RAMP[2] - RAMP[1]) * np.clip(t * 2 - 1, 0, 1))


def tint(a):
    l = a @ LUMA
    t = 0.5 + (l - l.mean()) / (4 * l.std()) * CONTRAST * 2  # ±2 độ lệch chuẩn → 0…1
    out = ramp(t)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = np.clip((g - np.maximum(r, b)) * 12, 0, 1)  # mạch có rêu
    moss = MOSS[None, None, :] * (0.75 + 0.5 * np.clip(t, 0, 1)[..., None])
    return np.clip(out * (1 - green[..., None]) + moss * green[..., None], 0, 1)


def main():
    a = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float) / 255.0
    Image.fromarray((tint(a) * 255).astype(np.uint8)).save(sys.argv[2])
    print("đã ghi", sys.argv[2])


if __name__ == "__main__":
    main()
