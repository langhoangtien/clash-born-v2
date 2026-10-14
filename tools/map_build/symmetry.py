"""Đối xứng xoay 180° quanh tâm khung (D-49): giữ nửa Blue (dưới–trái, y > x trong toạ độ
hướng dẫn), sinh nửa Red bằng phép xoay. Vai trò lane đối xứng: lane an toàn của Blue (BOT)
tương ứng lane an toàn của Red (TOP), lane khó (TOP ↔ BOT), mid ↔ mid.
Toạ độ là toạ độ ảnh hướng dẫn (guide); khung vuông FX0..FX1, tâm C = (FX0+FX1)/2."""
import math
import numpy as np
from shapely.geometry import LineString

LANE_SWAP = {"TOP": "BOT", "MID": "MID", "BOT": "TOP"}


class Sym:
    def __init__(self, frame):
        self.x0, self.y0, self.x1, self.y1 = frame
        self.sx = self.x0 + self.x1
        self.sy = self.y0 + self.y1

    def rot(self, p):
        return [round(self.sx - p[0], 2), round(self.sy - p[1], 2)]

    def blue_side(self, p):
        return (p[1] - self.y0) > (p[0] - self.x0)

    def on_axis(self, p, tol):
        return abs((p[1] - self.y0) - (p[0] - self.x0)) <= tol

    # ------------------------------------------------------------ raster
    def mask(self, m):
        """Nửa Red (y < x) lấy từ ảnh xoay của nửa Blue; đường chéo giữ nguyên."""
        out = m.copy()
        h, w = m.shape
        yy, xx = np.mgrid[0:h, 0:w]
        red = (yy - self.y0) < (xx - self.x0)
        src_y = np.clip(self.sy - 1 - yy, 0, h - 1)
        src_x = np.clip(self.sx - 1 - xx, 0, w - 1)
        out[red] = m[src_y[red], src_x[red]]
        return out

    # ------------------------------------------------------------ lanes
    def _blue_half(self, pts):
        """Phần polyline từ đầu Blue tới điểm cắt đường chéo đầu tiên."""
        out = [list(pts[0])]
        for a, b in zip(pts, pts[1:]):
            da = (a[1] - self.y0) - (a[0] - self.x0)
            db = (b[1] - self.y0) - (b[0] - self.x0)
            if da > 0 and db <= 0:
                t = da / (da - db)
                out.append([round(a[0] + (b[0] - a[0]) * t, 2), round(a[1] + (b[1] - a[1]) * t, 2)])
                return out
            out.append(list(b))
        raise ValueError("lane không cắt đường chéo")

    def lanes(self, lanes):
        halves = {k: self._blue_half(v) for k, v in lanes.items()}
        out = {}
        for k in lanes:
            other = [self.rot(p) for p in halves[LANE_SWAP[k]]][::-1]
            out[k] = halves[k] + other[1:] if halves[k][-1] == other[0] else halves[k] + other
        return out

    # ------------------------------------------------------------ semantics
    def source(self, src):
        s = dict(src)
        s["lanes"] = self.lanes(src["lanes"])
        s["fountains"] = [src["fountains"][0], self.rot(src["fountains"][0])]
        s["cores"] = [src["cores"][0], self.rot(src["cores"][0])]
        blue_spawns = src["lane_spawns"]["0"]
        s["lane_spawns"] = {"0": dict(blue_spawns),
                            "1": {k: self.rot(blue_spawns[LANE_SWAP[k]]) for k in blue_spawns}}
        base0 = [b for b in src["bases"] if b["team"] == 0][0]
        s["bases"] = [base0, {"team": 1, "polygon": [self.rot(p) for p in base0["polygon"]]}]
        s["ramps"] = self._pairs(src["ramps"], lambda r: self.rot(r[:2]) + r[2:])
        s["clear_circles"] = self._pairs(src["clear_circles"], lambda c: dict(c, pos=self.rot(c["pos"])), key=lambda c: c["pos"])
        s["erase_rects"] = self._pairs(src["erase_rects"], self._rot_rect, key=lambda r: [(r[0] + r[2]) / 2, (r[1] + r[3]) / 2])
        s["camps"] = self._camps(src["camps"])
        return s

    def _pairs(self, items, rotate, key=lambda v: v[:2]):
        kept = [v for v in items if self.blue_side(key(v)) or self.on_axis(key(v), 6)]
        return kept + [rotate(v) for v in kept if not self.on_axis(key(v), 0.5)]

    def _rot_rect(self, r):
        a, b = self.rot(r[:2]), self.rot(r[2:])
        return [min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])]

    def _camps(self, camps):
        out = []
        for c in camps:
            if c["side"] == 0:
                out.append(c)
                out.append(dict(c, id=c["id"].replace("blue", "red"), side=1, pos=self.rot(c["pos"])))
            elif c["side"] == -1:
                out.append(c)
        return out

    def towers(self, blue_towers):
        out = []
        for t in blue_towers:
            out.append(t)
            r = dict(t, id=t["id"].replace("blue", "red"), team=1, pos=self.rot(t["pos"]))
            if t["lane"] in LANE_SWAP:
                r["lane"] = LANE_SWAP[t["lane"]]
                r["id"] = "red_%s_t%d" % (r["lane"].lower(), t["tier"])
            else:
                r["id"] = {"blue_base_guard_left": "red_base_guard_right",
                           "blue_base_guard_right": "red_base_guard_left"}.get(t["id"], r["id"])
            out.append(r)
        return out


def place_t1(sym, lane_pts, meet_distance, lateral, clearance_fn, scale):
    """T1 của Blue: lùi `meet_distance` (đơn vị thế giới) từ điểm gặp của lane về phía Blue,
    lệch ngang `lateral` về phía có khoảng trống lớn hơn."""
    line = LineString(lane_pts)
    meet = line.length / 2.0
    d = meet - meet_distance / scale
    p = line.interpolate(d)
    q = line.interpolate(min(line.length, d + 1.0))
    tx, ty = q.x - p.x, q.y - p.y
    n = math.hypot(tx, ty) or 1.0
    nx, ny = -ty / n, tx / n
    # Thử lệch ngang tăng dần, hai bên; lấy chỗ đầu tiên đủ trống (≥ MIN_CLEAR thế giới).
    MIN_CLEAR = 170.0
    best, best_c = None, -1.0
    for extra in (0, 40, 80, 120):
        off = (lateral + extra) / scale
        for sign in (1, -1):
            cand = [p.x + sign * nx * off, p.y + sign * ny * off]
            c = clearance_fn(cand) * scale
            if c > best_c:
                best, best_c = cand, c
        if best_c >= MIN_CLEAR:
            break
    return [round(best[0], 2), round(best[1], 2)]
