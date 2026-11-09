#!/usr/bin/env python3
"""D-316: ảnh màu công trình (trụ, nhà chính, fountain, đổ nát — Tripo) về tông đá lạnh chung (D-312, người chơi: trụ và
base lạnh hơn cho hợp). Điểm ảnh ít màu (đá kem / xám ấm) ánh xạ độ sáng qua thang đá lạnh; điểm ảnh nhiều màu (viền vàng,
tinh thể / cờ màu phe) giữ nguyên; chuyển dần theo độ rực nên không loang mép.

  python3 tools/textures/cool_structure.py   # đọc art_inbox/16_structures_src/*.jpg (ảnh gốc), ghi assets/models/style/structures/
"""
import glob, os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "art_inbox", "16_structures_src")
DST = os.path.join(HERE, "..", "..", "assets", "models", "style", "structures")
RAMP = np.array([[62, 70, 84], [152, 158, 166], [232, 235, 240]]) / 255.0  # đá lạnh: tối ngả xanh, sáng xám trắng
SAT = (0.14, 0.3)  # độ rực: dưới mốc đầu tô lạnh hẳn, trên mốc sau giữ nguyên
LUMA = np.array([0.2126, 0.7152, 0.0722])


def ramp(t):
    t = np.clip(t, 0, 1)[..., None]
    lo = RAMP[0] + (RAMP[1] - RAMP[0]) * np.clip(t * 2, 0, 1)
    return np.where(t < 0.5, lo, RAMP[1] + (RAMP[2] - RAMP[1]) * np.clip(t * 2 - 1, 0, 1))


def cool(a):
    mx, mn = a.max(-1), a.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    w = 1 - np.clip((sat - SAT[0]) / (SAT[1] - SAT[0]), 0, 1)
    return a * (1 - w[..., None]) + ramp(a @ LUMA) * w[..., None]


def main():
    for f in sorted(glob.glob(os.path.join(SRC, "*.jpg"))):
        a = np.array(Image.open(f).convert("RGB")).astype(float) / 255.0
        Image.fromarray((cool(a) * 255).astype(np.uint8)).save(os.path.join(DST, os.path.basename(f)), quality=90)
        print("→", os.path.basename(f))


if __name__ == "__main__":
    main()
