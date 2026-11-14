"""Toán xương cho kho hoạt ảnh afk (D-398): lấy mẫu track glTF, FK, chuyển hoạt ảnh giữa hai bộ xương afk.

Quaternion dạng mảng (…, 4) thứ tự glTF x, y, z, w. Mọi hoạt ảnh lấy mẫu lại trên lưới thời gian đều FPS.
"""
import numpy as np

FPS = 30.0  # afk.ai xuất 30 khung / giây


def qmul(a, b):
    x1, y1, z1, w1 = np.moveaxis(a, -1, 0)
    x2, y2, z2, w2 = np.moveaxis(b, -1, 0)
    return np.stack([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2], -1)


def qinv(q):
    return q * np.array([-1.0, -1.0, -1.0, 1.0])


def qrot(q, v):
    u, w = q[..., :3], q[..., 3:4]
    return 2 * np.sum(u * v, -1, keepdims=True) * u + (w * w - np.sum(u * u, -1, keepdims=True)) * v \
        + 2 * w * np.cross(u, v)


def qnorm(q):
    return q / np.linalg.norm(q, axis=-1, keepdims=True)


def slerp(a, b, t):
    d = np.sum(a * b, -1, keepdims=True)
    b = np.where(d < 0, -b, b)
    d = np.abs(d)
    lin = d > 0.9995
    th = np.arccos(np.clip(d, -1, 1))
    s = np.sin(th) + 1e-12
    out = np.where(lin, a + (b - a) * t, (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / s)
    return qnorm(out)


class Skeleton:
    """Các nút từ gốc cảnh tới mọi khớp skin 0, theo thứ tự cha trước con; giữ TRS nghỉ."""

    def __init__(self, g):
        nodes = g["nodes"]
        self.g = g
        joints = g["skins"][0]["joints"]
        parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
        need = set()
        for j in joints:
            k = j
            while k is not None and k not in need:
                need.add(k)
                k = parent.get(k)
        depth = {}

        def dep(i):
            if i not in depth:
                depth[i] = 0 if i not in parent else dep(parent[i]) + 1
            return depth[i]
        self.order = sorted(need, key=lambda i: (dep(i), i))
        self.index = {n: k for k, n in enumerate(self.order)}
        self.parent = [self.index.get(parent.get(n), -1) for n in self.order]
        self.name = [nodes[n].get("name", str(n)) for n in self.order]
        self.by_name = {nm: k for k, nm in enumerate(self.name)}
        self.rest_t = np.array([nodes[n].get("translation", [0, 0, 0]) for n in self.order], float)
        self.rest_r = np.array([nodes[n].get("rotation", [0, 0, 0, 1]) for n in self.order], float)
        self.rest_s = np.array([nodes[n].get("scale", [1, 1, 1]) for n in self.order], float)
        assert np.allclose(self.rest_s, 1.0, atol=1e-4), "afk không đặt tỉ lệ trên xương; có thì phải tính lại"

    def fk(self, t, r, s=None):
        """t, r: (F, B, 3/4) cục bộ → vị trí, xoay thế giới (F, B, …). Tỉ lệ coi như hằng nghỉ."""
        s = np.broadcast_to(self.rest_s, t.shape) if s is None else s
        wp, wr, ws = np.zeros_like(t), np.zeros_like(r), np.zeros_like(t)
        for k, p in enumerate(self.parent):
            if p < 0:
                wp[:, k], wr[:, k], ws[:, k] = t[:, k], r[:, k], s[:, k]
            else:
                wp[:, k] = wp[:, p] + qrot(wr[:, p], ws[:, p] * t[:, k])
                wr[:, k] = qmul(wr[:, p], r[:, k])
                ws[:, k] = ws[:, p] * s[:, k]
        return wp, wr

    def rest(self, frames=1):
        t = np.repeat(self.rest_t[None], frames, 0)
        r = np.repeat(self.rest_r[None], frames, 0)
        return t, r


def sample(g, arr, anim, skel):
    """arr(i) → mảng accessor i. Hoạt ảnh glTF → (thời gian (F,), t (F,B,3), r (F,B,4)) cục bộ, xương không có track giữ tư thế nghỉ."""
    end = max(float(g["accessors"][s["input"]]["max"][0]) for s in anim["samplers"])
    times = np.arange(0.0, end + 1e-6, 1.0 / FPS)
    if times[-1] < end - 1e-6:
        times = np.append(times, end)
    t, r = skel.rest(len(times))
    t, r = t.copy(), r.copy()
    for c in anim["channels"]:
        node, path = c["target"].get("node"), c["target"]["path"]
        if node not in skel.index or path not in ("translation", "rotation"):
            continue
        smp = anim["samplers"][c["sampler"]]
        ti = np.asarray(arr(smp["input"])).reshape(-1).astype(float)
        vo = np.asarray(arr(smp["output"])).astype(float)
        k = skel.index[node]
        step = smp.get("interpolation", "LINEAR") == "STEP"
        hi = np.clip(np.searchsorted(ti, times, side="right"), 1, max(1, len(ti) - 1))
        lo = hi - 1
        if len(ti) == 1:
            val = np.repeat(vo[:1], len(times), 0)
        else:
            f = np.clip((times - ti[lo]) / np.maximum(ti[hi] - ti[lo], 1e-9), 0, 1)[:, None]
            if step:
                f = (times[:, None] >= ti[hi][:, None]).astype(float)
            if path == "rotation":
                val = slerp(qnorm(vo[lo]), qnorm(vo[hi]), f)
            else:
                val = vo[lo] + (vo[hi] - vo[lo]) * f
        (r if path == "rotation" else t)[:, k] = val
    return times, t, r


def hip_height(skel, hip="pelvis", feet=("foot_l", "foot_r")):
    """Chiều cao hông trên mắt cá ở tư thế nghỉ (đơn vị xương) — thước để co giãn track dời."""
    wp, _ = skel.fk(*skel.rest())
    return float(wp[0, skel.by_name[hip], 1] - min(wp[0, skel.by_name[f], 1] for f in feet))


def retarget(src, dst, t, r, movers=("root", "pelvis"), scale=None):
    """D-398: xoay — giữ nguyên độ lệch THẾ GIỚI so với tư thế nghỉ của từng xương (G_đích = G_nguồn · Rnghỉ_nguồn⁻¹ ·
    Rnghỉ_đích); dời — chỉ các xương `movers`, độ dời thế giới so với nghỉ nhân `scale` (tỉ lệ chiều cao hông)."""
    scale = hip_height(dst) / hip_height(src) if scale is None else scale
    F = len(t)
    swp, swr = src.fk(t, r)
    rwp, rwr = src.fk(*src.rest())
    dwp_rest, dwr_rest = dst.fk(*dst.rest())
    out_t, out_r = dst.rest(F)
    out_t, out_r = out_t.copy(), out_r.copy()
    gw_r = np.zeros_like(out_r)
    gw_p = np.zeros((F, len(dst.order), 3))
    for k, name in enumerate(dst.name):
        p = dst.parent[k]
        sk = src.by_name.get(name)
        if sk is not None:
            g_new = qmul(qmul(swr[:, sk], qinv(rwr[0, sk])[None]), dwr_rest[0, k][None])
        else:
            g_new = qmul(gw_r[:, p], dst.rest_r[k][None]) if p >= 0 else np.repeat(dst.rest_r[k][None], F, 0)
        gw_r[:, k] = qnorm(g_new)
        par_r = gw_r[:, p] if p >= 0 else np.repeat(np.array([[0, 0, 0, 1.0]]), F, 0)
        par_p = gw_p[:, p] if p >= 0 else np.zeros((F, 3))
        out_r[:, k] = qnorm(qmul(qinv(par_r), gw_r[:, k]))
        if sk is not None and name in movers:
            want = dwp_rest[0, k] + (swp[:, sk] - rwp[0, sk]) * scale
            out_t[:, k] = qrot(qinv(par_r), want - par_p)
        gw_p[:, k] = par_p + qrot(par_r, out_t[:, k])
    return out_t, out_r, scale
