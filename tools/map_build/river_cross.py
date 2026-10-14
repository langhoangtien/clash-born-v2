"""Chỗ mid cắt sông (MAP-05, D-52): bỏ các đoạn vách/bậc dốc sát chỗ lane giữa cắt sông
(khu giao tranh), giữ nguyên sông, bờ kè và các dốc còn lại. Bán kính tính bằng world."""
import math


def apply(cfg, xx, yy, center, scale, black):
    """Trả về (black, zone): xóa vách trong vòng `radius` quanh tâm map."""
    r = cfg["radius"] / scale
    zone = (xx - center[0]) ** 2 + (yy - center[1]) ** 2 <= r * r
    return black & ~zone, zone


def keeps_ramp(ramp, zone):
    x, y = int(round(ramp[0])), int(round(ramp[1]))
    return not zone[y, x]
