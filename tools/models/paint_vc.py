## Tô màu đỉnh cho mô hình Tripo không có texture (D-168 thử): SCALE=k paint_vc.py in.glb out.glb tree|tree_pine|rock|grass|ground [ngưỡng_thân]
import sys; sys.path.insert(0, sys.argv[0].rsplit('/', 1)[0])
import glbio, numpy as np
src, dst, kind = sys.argv[1:4]
p, n, idx = glbio.load(src)
y = (p[:, 1] - p[:, 1].min()) / max(1e-6, np.ptp(p[:, 1]))
up = np.clip(n[:, 1], -1, 1)
def lerp(a, b, t): return np.array(a)[None] * (1 - t[:, None]) + np.array(b)[None] * t[:, None]
def thickness():
    t = idx.reshape(-1, 3); v0, v1, v2 = p[t[:, 0]], p[t[:, 1]], p[t[:, 2]]
    e1, e2 = v1 - v0, v2 - v0
    out = np.full(len(p), 9.0)
    for k in range(len(p)):
        o = p[k] - n[k] * 1e-3; d = -n[k]
        h = np.cross(d, e2); a = (e1 * h).sum(1)
        ok = np.abs(a) > 1e-9; f = np.where(ok, 1 / np.where(ok, a, 1), 0)
        s = o - v0; u = f * (s * h).sum(1); q = np.cross(s, e1); v = f * (q * d).sum(1)
        tt = f * (e2 * q).sum(1)
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (tt > 1e-4)
        if hit.any(): out[k] = tt[hit].min()
    return out
def smooth(vals, it=2):
    t = idx.reshape(-1, 3)
    for _ in range(it):
        acc = np.zeros(len(p)); cnt = np.zeros(len(p))
        for a in range(3):
            for b in range(3):
                np.add.at(acc, t[:, a], vals[t[:, b]]); np.add.at(cnt, t[:, a], 1)
        vals = acc / np.maximum(cnt, 1)
    return vals
light = 0.12 * np.clip(up, 0, 1)  # mặt hướng lên sáng hơn chút
face = np.clip(up * 0.5 + 0.5, 0, 1)  # 0 = mặt dưới, 1 = mặt trên
if kind.startswith('tree'):
    t = np.clip(0.30 * y + 0.70 * face, 0, 1) ** 1.3  # dưới tán tối, ngọn và mặt trên sáng
    leaf = np.where(t[:, None] < 0.5, lerp([0.18, 0.29, 0.09], [0.40, 0.55, 0.17], t * 2),
                    lerp([0.40, 0.55, 0.17], [0.66, 0.78, 0.30], t * 2 - 1))
    bark = lerp([0.27, 0.19, 0.13], [0.45, 0.32, 0.21], y)
    if kind == 'tree_pine':
        r = np.hypot(p[:, 0], p[:, 2])
        w = ((y < 0.10) & (r < 0.06)).astype(float)
    else:
        th = thickness(); w = smooth((th < float(sys.argv[4]) if len(sys.argv) > 4 else th < 0.14).astype(float))
        r = np.hypot(p[:, 0] - p[:, 0].mean(), p[:, 2] - p[:, 2].mean()) / max(1e-6, np.ptp(p[:, 0]))
        w = (((w > 0.5) & (r < 0.22)) | (y < 0.16)).astype(float)  # thân: mảnh và gần trục, hoặc sát gốc (rễ)
    col = leaf * (1 - w[:, None]) + bark * w[:, None]
    col *= (0.75 + 0.25 * np.clip(y * 4, 0, 1))[:, None]  # gốc sẫm lại
elif kind == 'rock':
    col = lerp([0.46, 0.47, 0.46], [0.80, 0.80, 0.77], np.clip(0.35 * y + 0.65 * face, 0, 1))
    moss = np.clip((up - 0.75) * 3, 0, 1) * 0.3
    col = col * (1 - moss[:, None]) + np.array([0.47, 0.55, 0.24])[None] * moss[:, None]
    col *= (0.7 + 0.3 * np.clip(y * 5, 0, 1))[:, None]
elif kind in ('grass', 'ground'):
    col = lerp([0.22, 0.33, 0.10], [0.66, 0.76, 0.32], y ** 0.8)
    if kind == 'ground':
        c = glbio.components(len(p), idx)
        for r in np.unique(c):
            m = c == r
            if np.ptp(p[m, 1]) < 0.15 * np.ptp(p[:, 1]):  # cụm nhỏ sát đất = hoa
                col[m] = lerp([0.95, 0.80, 0.25], [1.0, 0.95, 0.75], y[m] * 3)
col = col ** 2.2  # màu đỉnh glTF là tuyến tính
import os
k = float(os.environ.get('SCALE', '1'))
glbio.save(dst, p * k, n, idx, col, kind)
print(dst, len(idx) // 3, 'tam giác')
