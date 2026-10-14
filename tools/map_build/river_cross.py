"""Khúc sông giữa map (MAP-05): dựng lại sông quanh chỗ lane giữa cắt qua thành một dải
trơn, đối xứng xoay 180°, không có vách/bậc thang lồi ra khu giao tranh.
Toạ độ: t dọc đường chéo (hướng (1,1)), n vuông góc (hướng (1,-1)), đơn vị world, gốc ở tâm."""
import math
import numpy as np


def apply(cfg, xx, yy, center, scale, water, black, tree):
    """Trả về (water, black, tree, zone) đã sửa; zone là mặt nạ vùng bị dựng lại."""
    cx, cy = center
    dx, dy = (xx - cx) * scale, (yy - cy) * scale
    t = (dx + dy) / math.sqrt(2.0)
    n = (dx - dy) / math.sqrt(2.0)
    T = cfg["half_len"]
    u = np.clip(np.abs(t) / T, 0.0, 1.0)
    off = cfg["offset_end"] * np.clip(t / T, -1.0, 1.0)
    half = cfg["half_width"] + (cfg["half_width_end"] - cfg["half_width"]) * u * u
    inside = np.abs(t) <= T
    band = inside & (np.abs(n - off) <= half)
    zone = inside & (np.abs(n - off) <= half + cfg["clear"])
    water = (water & ~inside) | band
    black = black & ~zone
    tree = tree & ~band
    return water, black, tree, zone


def keeps_ramp(ramp, zone):
    x, y = int(round(ramp[0])), int(round(ramp[1]))
    return not zone[y, x]
