"""D-325: đòn chém kiếm một tay dựng bằng code cho glb_anims.py (`A!=tên`: A cho tư thế đứng — khung đầu; tay phải chém,
tay trái là bản soi gương `A!^`). Người chơi: đòn thư viện (Sword_Inward, SS_Power_Slash) nhìn từ camera trên cao như
xỉa / lảo đảo → chân đứng yên, kiếm giơ cao qua vai phải rồi chém chéo xuống hông trái, thân xoắn theo, rồi về thủ.

Tọa độ thân (lưới afk.ai, cao 1): y lên, z trước mặt, x sang trái nhân vật. Tay: IK hai đoạn (vai → khuỷu → cổ tay) tới
điểm đích + hướng khuỷu; bàn tay xoay để lưỡi kiếm theo hướng đích (kiếm gắn với place_prop --rot 90,0,0: lưỡi +z, mép
lưỡi ±x ở tư thế nghỉ), mép lưỡi đi trước theo mặt phẳng chém. Thân: xoay quanh trục đứng + cúi, chia đều 3 đốt sống.
"""
import numpy as np
import glb_mirror as M
from glb_rig_ops import add_accessor

LENGTH = 0.9  # giây — game co giãn theo nhịp đánh
# (thời điểm 0..1, cổ tay phải, hướng lưỡi, hướng khuỷu, xoay thân°, cúi°); None = theo tư thế đứng gốc
KEYS = [
    (0.0, None, None, (-1.0, -0.6, 0.0), 0, 0),
    (0.3, (-0.24, 0.38, -0.2), (-0.35, 0.05, -0.94), (-1.0, 0.5, 0.1), -50, -10),    # kiếm vắt sau gáy, thân vặn hết
    (0.4, (-0.25, 0.4, -0.18), (-0.45, 0.25, -0.86), (-1.0, 0.5, 0.1), -54, -12),    # nén lực (gần như đứng)
    (0.47, (-0.02, 0.24, 0.33), (0.3, 0.05, 0.95), (-0.5, -1.0, 0.0), 18, 14),       # tay duỗi chém qua trước mặt (trúng)
    (0.54, (0.22, 0.0, 0.14), (0.75, -0.4, -0.52), (-0.1, -1.0, -0.3), 52, 22),      # kéo ra sau hông trái
    (0.74, (0.22, -0.01, 0.12), (0.72, -0.45, -0.52), (-0.1, -1.0, -0.3), 48, 20),   # giữ đà
    (1.0, None, None, (-1.0, -0.6, 0.0), 0, 0),
]
# Tay trái (cầm kiếm kia) hạ xuống hông trái, lưỡi chúc ra sau — không che đòn chém; vào / ra theo LEFT_IN / LEFT_OUT.
LEFT_HOLD = ((0.21, 0.02, -0.06), (0.2, -0.5, -0.85), (1.0, -0.5, -0.3))
LEFT_IN, LEFT_OUT = 0.25, 0.8
SPINE = ("spine_01", "spine_02", "spine_03")
ARM = ("upperarm_r", "lowerarm_r", "hand_r")
ARM_L = ("upperarm_l", "lowerarm_l", "hand_l")
BLADE_REST, EDGE_REST = np.array([0.0, 0.0, 1.0]), np.array([1.0, 0.0, 0.0])


def slash(g, binc, array, anim):
    nodes = g["nodes"]
    parent = {c: i for i, nd in enumerate(nodes) for c in nd.get("children", [])}
    order = sorted(range(len(nodes)), key=lambda n: M._depth(parent, n))
    by = {nd.get("name", ""): i for i, nd in enumerate(nodes)}
    first = M._sample(g, binc, array, anim, np.array([0.0]))
    base = {n: _local(nodes[n], first, n) for n in range(len(nodes))}
    rest = M._globals(g, parent, order, {n: M._trs(nodes[n].get("translation", [0, 0, 0]), nodes[n].get("rotation", [0, 0, 0, 1]),
                                                   nodes[n].get("scale", [1, 1, 1])) for n in range(len(nodes))})
    axes = {h: (rest[by[h]][:3, :3].T @ BLADE_REST, rest[by[h]][:3, :3].T @ EDGE_REST) for h in ("hand_r", "hand_l")}
    lens = {a[0]: tuple(np.linalg.norm(rest[by[b]][:3, 3] - rest[by[a_]][:3, 3]) for a_, b in zip(a, a[1:])) for a in (ARM, ARM_L)}
    g0 = M._globals(g, parent, order, base)
    ready = {h: (g0[by[h]][:3, 3], g0[by[h]][:3, :3] @ axes[h][0]) for h in ("hand_r", "hand_l")}
    n_plane = _unit(np.cross(KEYS[2][2], KEYS[4][2]))
    times = np.linspace(0, LENGTH, int(round(LENGTH * 30)) + 1)
    moved = [by[b] for b in SPINE + ARM + ARM_L]
    frames = {j: [] for j in moved}
    for t in times / LENGTH:
        pos, blade, pole, yaw, pitch = _at(t, *ready["hand_r"])
        loc = dict(base)
        glob = M._globals(g, parent, order, loc)
        rot = _axis([0, 1, 0], np.radians(yaw) / 3) @ _axis([1, 0, 0], np.radians(pitch) / 3)
        for name in SPINE:
            j = by[name]
            gj = glob[parent[j]] @ loc[j]
            gj = _about(gj[:3, 3], rot) @ gj
            loc[j] = np.linalg.inv(glob[parent[j]]) @ gj
            glob = M._globals(g, parent, order, loc)
        _arm(loc, glob, parent, [by[b] for b in ARM], pos, blade, _unit(np.cross(n_plane, blade)), pole,
             lens[ARM[0]], axes["hand_r"])
        glob = M._globals(g, parent, order, loc)
        w = _ramp(t)
        lp, ld = ready["hand_l"]
        hp, hd, hpole = (np.array(v, float) for v in LEFT_HOLD)
        ldir = _slerp(ld, _unit(hd), w)
        _arm(loc, glob, parent, [by[b] for b in ARM_L], lp + (hp - lp) * w, ldir, _unit(np.cross([1.0, 0, 0], ldir)),
             _unit(hpole), lens[ARM_L[0]], axes["hand_l"])
        for j in moved:
            frames[j].append(loc[j])
    _write(g, binc, anim, times, base, frames, [j for j in g["skins"][0]["joints"]])


def _at(t, ready_pos, ready_dir):
    """Đích tại thời điểm t: nội suy êm (smoothstep) giữa hai khóa kề nhau."""
    for a, b in zip(KEYS, KEYS[1:]):
        if a[0] <= t <= b[0]:
            u = (t - a[0]) / (b[0] - a[0])
            u = u * u * (3 - 2 * u)
            pa, pb = (np.array(k[1]) if k[1] is not None else ready_pos for k in (a, b))
            da, db = (_unit(np.array(k[2], float)) if k[2] is not None else ready_dir for k in (a, b))
            return (pa + (pb - pa) * u, _slerp(da, db, u), _unit(np.array(a[3]) * (1 - u) + np.array(b[3]) * u),
                    a[4] + (b[4] - a[4]) * u, a[5] + (b[5] - a[5]) * u)
    return ready_pos, ready_dir, np.array([-1.0, 0, 0]), 0, 0


def _ramp(t):
    """Trọng số tay trái: 0 → 1 trong [0, LEFT_IN], giữ, 1 → 0 trong [LEFT_OUT, 1] (êm)."""
    u = min(t / LEFT_IN, 1.0, (1.0 - t) / (1.0 - LEFT_OUT))
    return u * u * (3 - 2 * u)


def _arm(loc, glob, parent, arm, target, blade, edge, pole, lens, local_axes):
    ua, la, hd = arm
    s = glob[ua][:3, 3]
    l1, l2 = lens
    d = np.clip(np.linalg.norm(target - s), abs(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
    to = _unit(target - s)
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    side = _unit(pole - np.dot(pole, to) * to)
    elbow = s + l1 * (cos_a * to + np.sqrt(max(0.0, 1 - cos_a * cos_a)) * side)
    wrist = s + to * d
    gu = _aim(glob[parent[ua]] @ loc[ua], elbow)
    loc[ua] = np.linalg.inv(glob[parent[ua]]) @ gu
    gl = _aim(gu @ loc[la], wrist)
    loc[la] = np.linalg.inv(gu) @ gl
    gh = gl @ loc[hd]
    bl, el = local_axes
    want = np.stack([blade, _unit(edge - np.dot(edge, blade) * blade)], 1)
    have = np.stack([bl, _unit(el - np.dot(el, bl) * bl)], 1)
    rw = np.column_stack([want, np.cross(want[:, 0], want[:, 1])])
    rh = np.column_stack([have, np.cross(have[:, 0], have[:, 1])])
    gh[:3, :3] = rw @ rh.T * np.linalg.norm(gh[:3, :3], axis=0)
    loc[hd] = np.linalg.inv(gl) @ gh


def _aim(gm, point):
    """Xoay ít nhất quanh đầu xương để trục y của xương chỉ tới `point`."""
    y = _unit(gm[:3, 1])
    want = _unit(point - gm[:3, 3])
    ax = np.cross(y, want)
    ang = np.arctan2(np.linalg.norm(ax), np.dot(y, want))
    if np.linalg.norm(ax) < 1e-9:
        return gm
    return _about(gm[:3, 3], _axis(ax, ang)) @ gm


def _write(g, binc, anim, times, base, frames, joints):
    anim["channels"], anim["samplers"] = [], []
    tin = add_accessor(g, binc, times[:, None], "SCALAR", True)
    t2 = add_accessor(g, binc, np.array([[0.0], [times[-1]]]), "SCALAR", True)
    for j in joints:
        mats = frames.get(j, [base[j], base[j]])
        rot = np.array([M._m2q(m[:3, :3] / np.linalg.norm(m[:3, :3], axis=0)) for m in mats])
        for k in range(1, len(rot)):
            if np.dot(rot[k], rot[k - 1]) < 0:
                rot[k] = -rot[k]
        for path, v in (("translation", np.array([m[:3, 3] for m in mats])), ("rotation", rot)):
            anim["samplers"].append({"input": tin if j in frames else t2, "interpolation": "LINEAR",
                                     "output": add_accessor(g, binc, v, {3: "VEC3", 4: "VEC4"}[v.shape[1]])})
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": j, "path": path}})


def _local(nd, vals, n):
    if "matrix" in nd:
        return np.array(nd["matrix"], float).reshape(4, 4).T
    t, r, s = (vals.get((n, p)) for p in ("translation", "rotation", "scale"))
    return M._trs(nd.get("translation", [0, 0, 0]) if t is None else t[0], nd.get("rotation", [0, 0, 0, 1]) if r is None else r[0],
                  nd.get("scale", [1, 1, 1]) if s is None else s[0])


def _axis(ax, ang):
    x, y, z = _unit(np.asarray(ax, float))
    c, s = np.cos(ang), np.sin(ang)
    k = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return np.eye(3) + s * k + (1 - c) * (k @ k)


def _about(p, r):
    m = np.eye(4)
    m[:3, :3] = r
    m[:3, 3] = p - r @ p
    return m


def _slerp(a, b, u):
    ang = np.arccos(np.clip(np.dot(a, b), -1, 1))
    if ang < 1e-6:
        return a
    return _unit((np.sin((1 - u) * ang) * a + np.sin(u * ang) * b) / np.sin(ang))


def _unit(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-12)
