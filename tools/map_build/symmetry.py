"""Đối xứng xoay 180° quanh tâm khung (D-49): giữ nửa Blue (dưới–trái, y > x trong toạ độ
hướng dẫn), sinh nửa Red bằng phép xoay. Vai trò lane đối xứng: lane an toàn của Blue (BOT)
tương ứng lane an toàn của Red (TOP), lane khó (TOP ↔ BOT), mid ↔ mid.
Toạ độ là toạ độ guide; khung vuông FX0..FX1, tâm C = (FX0+FX1)/2."""
import math
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
    def camps(self, camps):
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
