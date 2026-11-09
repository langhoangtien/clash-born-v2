#!/usr/bin/env python3
"""D-312: đưa ảnh đá lát vẽ tay (Codex T12) về **tông đá chung của game** — xám trung tính chỗ sáng, ngả xanh lạnh chỗ
tối, như vách đá ảnh mẫu (art_inbox/08_style/ref/lane_ref.png) và lan can rìa map (người chơi thích màu lạnh này; D-311
tô be ấm bị bỏ). Giữ nét vẽ: chỉ lấy sáng tối, nén tương phản, ánh xạ qua thang màu `RAMP`; mạch có rêu giữ sắc rêu.

  python3 tools/textures/stone_tint.py vào.png ra.png
D-313: ảnh nguồn = art_inbox/15_ground/base_paving.png (Codex T14: phiến lớn mịn như ô A ảnh mẫu).
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

# Thang màu đá (sRGB): tối (mạch) → giữa → sáng. Lấy từ vách đá ảnh mẫu (sáng ~145,142,142; tối ~45,57,72).
RAMP = np.array([[78, 86, 98], [132, 135, 138], [172, 171, 168]]) / 255.0
MOSS = np.array([96, 112, 62]) / 255.0
SMOOTH = 3.0      # px — vân mặt phiến
GRAIN = 1.2       # độ mạnh vân mặt phiến (theo tỉ lệ độ sáng)
TONE = 0.15      # chênh sắc giữa các phiến (trên thang 0…1 của RAMP)
EDGE_DARK = 0.18  # mép phiến tối hơn (bo tròn)
SEAM_DROP = 0.18  # điểm sẫm hơn xung quanh ≥ tỉ lệ này mới là mạch
SPLIT_DROP = 0.03 # ngưỡng tách phiến (mạch nhạt / đứt cũng tính)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def ramp(t):
    t = np.clip(t, 0, 1)[..., None]
    lo = RAMP[0] + (RAMP[1] - RAMP[0]) * np.clip(t * 2, 0, 1)
    return np.where(t < 0.5, lo, RAMP[1] + (RAMP[2] - RAMP[1]) * np.clip(t * 2 - 1, 0, 1))


def flatten(a, sigma=48.0):
    """D-313: bỏ chênh sáng tối tần số thấp — chia cho bản nhòe bao vòng."""
    low = ndimage.gaussian_filter(a, (sigma, sigma, 0), mode="wrap")
    return a / np.maximum(low, 1e-3) * a.reshape(-1, 3).mean(0)


def tint(a):
    """Phiến trơn (như ô A ảnh mẫu): mạch = điểm sẫm hơn hẳn xung quanh (giữ sắc nét); mỗi phiến (vùng liền giữa các
    mạch) một sắc đậm nhạt riêng, mép phiến tối nhẹ (bo tròn), vân mặt phiến chỉ giữ rất nhẹ từ ảnh gốc."""
    a = flatten(a)
    l = a @ LUMA
    around = ndimage.gaussian_filter(l, 8, mode="wrap")
    seam = np.clip((around - l) / (around * SEAM_DROP) - 0.35, 0, 1)
    split = (around - l) / around > SPLIT_DROP  # ngưỡng nhạy hơn chỉ để tách phiến
    closed = ndimage.binary_dilation(np.tile(split, (3, 3)), iterations=4)  # khép chỗ mạch đứt quãng
    tiles = ~closed  # gắn nhãn trên ảnh lát 3×3 rồi lấy ô giữa → phiến cắt mép ảnh nối đúng
    labels, count = ndimage.label(tiles)
    n = l.shape[0]
    # Sắc mỗi phiến theo tâm phiến lấy dư theo cạnh ảnh: các bản sao của cùng một phiến (vắt qua mép) cùng sắc.
    cy, cx = np.array(ndimage.center_of_mass(tiles, labels, range(1, count + 1))).T
    key = (np.round(cx % n / 4) * 1009 + np.round(cy % n / 4)).astype(np.int64)
    tone = np.concatenate([[0.0], ((key * 2654435761) % 1000 / 1000.0 * 2 - 1) * TONE])
    labels = ndimage.grey_dilation(labels, size=(9, 9))[n:2 * n, n:2 * n]  # trả phần đã nới về phiến bên cạnh
    dist = ndimage.distance_transform_edt(tiles)[n:2 * n, n:2 * n]
    print("số phiến (lát 3×3):", count)
    ls = ndimage.gaussian_filter(l, SMOOTH, mode="wrap")
    t = 0.55 + tone[labels] + (ls - ls.mean()) / ls.mean() * GRAIN - EDGE_DARK * np.exp(-dist / 7.0)
    out = ramp(t) * (1 - seam[..., None]) + RAMP[0] * seam[..., None]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = np.clip((g - np.maximum(r, b)) * 12, 0, 1) * seam  # rêu chỉ trong mạch
    return np.clip(out * (1 - green[..., None]) + MOSS[None, None, :] * green[..., None], 0, 1)


def main():
    a = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float) / 255.0
    Image.fromarray((tint(a) * 255).astype(np.uint8)).save(sys.argv[2])
    print("đã ghi", sys.argv[2])


if __name__ == "__main__":
    main()
