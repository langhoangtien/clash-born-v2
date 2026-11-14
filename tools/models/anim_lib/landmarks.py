"""Mốc cơ thể từ hình học lưới dáng chữ A (D-399): đáy, đũng, nách, cổ, đỉnh; đường tâm chân / tay / thân.

Bên trái nhân vật = +x (quy ước afk: foot_l có x > 0). Đơn vị theo lưới; H = chiều cao lưới.
"""
import numpy as np

STEP = 0.005  # bước cắt theo chiều cao, tính theo H
JUMP = 0.06  # tâm vòng nhảy xa hơn mức này (theo H) giữa hai lát liền nhau thì coi là mất dấu


def _covers0(r, H):
    return r["lo"][0] < 0.01 * H and r["hi"][0] > -0.01 * H


def trace(sl, start, side, y0, y1, H):
    """Đi từ điểm `start` theo chiều y tăng, mỗi lát lấy vòng (không vắt qua x = 0, cùng bên) gần tâm trước nhất.
    Trả (ys, tâm) tới khi mất dấu hoặc vòng vắt qua giữa thân (đũng / nách)."""
    ys, cs, prev = [], [], np.asarray(start, float)
    for y in np.arange(y0, y1, STEP * H):
        rings = [r for r in sl.rings(y) if r["n"] >= 4]
        if not rings:
            break
        near = min(rings, key=lambda r: np.linalg.norm((r["c"] - prev)[[0, 2]]))
        jump = np.linalg.norm((near["c"] - prev)[[0, 2]]) > JUMP * H and len(ys) > 0  # lát đầu: điểm mút → tâm vòng
        if jump or _covers0(near, H) or near["c"][0] * side <= 0:
            break
        ys.append(y)
        cs.append(near["c"])
        prev = near["c"]
    return np.array(ys), np.array(cs)


def torso(sl, y0, y1, H):
    """Mỗi lát: vòng hẹp nhất vắt qua x = 0 (bỏ lớp tóc / mũ / áo ngoài) → (ys, tâm, bề ngang)."""
    ys, cs, ws = [], [], []
    for y in np.arange(y0, y1, STEP * H):
        rings = [r for r in sl.rings(y) if r["n"] >= 4 and _covers0(r, H)]
        if rings:
            r = min(rings, key=lambda r: r["hi"][0] - r["lo"][0])
            ys.append(y)
            cs.append(r["c"])
            ws.append(r["hi"][0] - r["lo"][0])
    return np.array(ys), np.array(cs), np.array(ws)


def landmarks(sl):
    v = sl.v
    lo, hi = v.min(0), v.max(0)
    H = hi[1] - lo[1]
    out = {"H": H, "bot": lo[1], "top": hi[1], "leg": {}, "arm": {}, "foot": {}}
    for side, key in ((1, "l"), (-1, "r")):
        sv = v[v[:, 0] * side > 0]
        feet = sv[sv[:, 1] < lo[1] + 0.04 * H]
        out["foot"][key] = {"c": feet.mean(0), "toe": feet[:, 2].max(), "heel": feet[:, 2].min()}
        out["leg"][key] = trace(sl, feet.mean(0), side, lo[1] + 0.01 * H, hi[1], H)
    out["crotch"] = float(np.mean([out["leg"][k][0][-1] for k in "lr"]))
    for side, key in ((1, "l"), (-1, "r")):
        body = v[(v[:, 0] * side > 0) & (v[:, 1] > out["crotch"] - 0.15 * H)]
        tip = body[np.argmax(body[:, 0] * side - 0.2 * body[:, 1])]  # bàn tay: điểm xa nhất ra ngoài, hơi thiên xuống
        out["arm"][key] = (tip,) + trace(sl, tip, side, tip[1] + 0.01 * H, hi[1], H)
    out["armpit"] = float(np.mean([out["arm"][k][1][-1] for k in "lr"]))
    ty, tc, tw = torso(sl, out["crotch"], hi[1], H)
    out["torso"] = (ty, tc)
    up = (ty > out["armpit"]) & (ty < out["armpit"] + 0.6 * (hi[1] - out["armpit"]))
    out["neck"] = float(ty[up][np.argmin(tw[up])]) if up.any() else out["armpit"] + 0.3 * (hi[1] - out["armpit"])
    return out


def curve_at(ys, cs, y):
    """Tâm đường (ys, cs) ở độ cao y; ngoài khoảng thì giữ đầu mút."""
    return np.array([np.interp(y, ys, cs[:, k]) for k in range(3)])
