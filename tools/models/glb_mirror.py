"""D-323: phản chiếu hoạt ảnh trái ↔ phải cho glb_anims.py (`A^=tên`: cả thân, vd chém tay phải → chém tay trái;
`A%=tên`: đối xứng — nửa trái làm theo nửa phải soi gương, vd rút kiếm sau vai phải → rút hai kiếm hai vai).

Tính trong không gian thế giới nên không phụ thuộc trục riêng của từng xương: tư thế xương b = gương(tư thế xương cặp
của b) · C_b, với C_b chọn sao cho ở tư thế nghỉ ra đúng tư thế nghỉ của b. Mặt gương đi qua giữa hai bàn tay lúc
nghỉ, vuông góc với trục chênh lệch nhiều nhất giữa hai tay. Xương cặp theo hậu tố tên `_l` / `_r`.
"""
import numpy as np
from glb_rig_ops import add_accessor

FPS = 30.0


def _q2m(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def _m2q(m):
    t = np.trace(m)
    if t > 0:
        s = 2 * np.sqrt(t + 1)
        return np.array([(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4])
    i = int(np.argmax(np.diag(m)))
    j, k = (i + 1) % 3, (i + 2) % 3
    s = 2 * np.sqrt(1 + m[i, i] - m[j, j] - m[k, k])
    q = np.zeros(4)
    q[i], q[j], q[k], q[3] = s / 4, (m[j, i] + m[i, j]) / s, (m[k, i] + m[i, k]) / s, (m[k, j] - m[j, k]) / s
    return q


def _trs(t, r, s):
    m = np.eye(4)
    m[:3, :3] = _q2m(np.asarray(r, float)) * np.asarray(s, float)
    m[:3, 3] = t
    return m


def _sample(g, binc, array, anim, times):
    """{(nút, đường): giá trị tại `times`} — nội suy tuyến tính (quaternion cùng bán cầu rồi chuẩn hóa)."""
    out = {}
    for c in anim["channels"]:
        s = anim["samplers"][c["sampler"]]
        t = array(g, binc, s["input"])[:, 0]
        v = array(g, binc, s["output"]).astype(float).copy()
        if v.shape[1] == 4:
            for k in range(1, len(v)):
                if np.dot(v[k], v[k - 1]) < 0:
                    v[k] = -v[k]
        r = np.stack([np.interp(times, t, v[:, i]) for i in range(v.shape[1])], 1)
        if r.shape[1] == 4:
            r /= np.linalg.norm(r, axis=1, keepdims=True)
        out[(c["target"]["node"], c["target"]["path"])] = r
    return out


def _globals(g, parent, order, local):
    """Ma trận thế giới mọi nút (T×4×4) từ ma trận cục bộ, duyệt cha trước con."""
    glob = {}
    for n in order:
        glob[n] = local[n] if parent.get(n) is None else glob[parent[n]] @ local[n]
    return glob


def mirror(g, binc, array, anim, mode):
    """mode "full" (`^`) hoặc "sym" (`%`). Ghi lại kênh xoay + dời của mọi xương bị đổi."""
    nodes = g["nodes"]
    parent = {c: i for i, nd in enumerate(nodes) for c in nd.get("children", [])}
    order = sorted(range(len(nodes)), key=lambda n: _depth(parent, n))
    joints = g["skins"][0]["joints"]
    name = {j: nodes[j].get("name", "") for j in joints}
    by_name = {v: k for k, v in name.items()}
    pair = {j: by_name.get(_swap(name[j]), j) for j in joints}
    length = max(g["accessors"][s["input"]]["max"][0] for s in anim["samplers"])
    times = np.linspace(0, length, max(2, int(round(length * FPS)) + 1))
    vals = _sample(g, binc, array, anim, times)
    local, rest = {}, {}
    for n in range(len(nodes)):
        nd = nodes[n]
        if "matrix" in nd:
            m = np.array(nd["matrix"], float).reshape(4, 4).T
            rest[n], local[n] = m, np.repeat(m[None], len(times), 0)
            continue
        t0, r0, s0 = nd.get("translation", [0, 0, 0]), nd.get("rotation", [0, 0, 0, 1]), nd.get("scale", [1, 1, 1])
        rest[n] = _trs(t0, r0, s0)
        t, r, s = (vals.get((n, p)) for p in ("translation", "rotation", "scale"))
        local[n] = np.stack([_trs(t0 if t is None else t[k], r0 if r is None else r[k], s0 if s is None else s[k])
                             for k in range(len(times))])
    glob, grest = _globals(g, parent, order, local), _globals(g, parent, order, rest)
    S = _reflection(grest[by_name["hand_l"]][:3, 3], grest[by_name["hand_r"]][:3, 3])
    changed = [j for j in joints if mode == "full" or name[j].endswith("_l")]
    new = dict(glob)
    for j in changed:
        src = pair[j]
        C = np.linalg.inv(S @ grest[src] @ S) @ grest[j]
        new[j] = S @ glob[src] @ S @ C
    keep = [c for c in anim["channels"] if c["target"]["node"] not in changed]
    anim["samplers"], anim["channels"] = _rebuild(anim, keep)
    tin = add_accessor(g, binc, times[:, None], "SCALAR", True)
    for j in changed:
        p = parent.get(j)
        loc = new[j] if p is None else np.linalg.inv(new[p]) @ new[j]
        rot = np.array([_m2q(m[:3, :3] / np.linalg.norm(m[:3, :3], axis=0)) for m in loc])
        for k in range(1, len(rot)):
            if np.dot(rot[k], rot[k - 1]) < 0:
                rot[k] = -rot[k]
        for path, v in (("translation", loc[:, :3, 3]), ("rotation", rot)):
            anim["samplers"].append({"input": tin, "output": add_accessor(g, binc, v, {3: "VEC3", 4: "VEC4"}[v.shape[1]]),
                                     "interpolation": "LINEAR"})
            anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": j, "path": path}})


def _depth(parent, n):
    d = 0
    while n in parent:
        n, d = parent[n], d + 1
    return d


def _swap(n):
    return n[:-2] + "_r" if n.endswith("_l") else n[:-2] + "_l" if n.endswith("_r") else n


def _reflection(a, b):
    """Gương 4×4 qua mặt phẳng giữa hai điểm, vuông góc với trục chênh lệch nhiều nhất."""
    axis = int(np.argmax(np.abs(a - b)))
    S = np.eye(4)
    S[axis, axis] = -1
    S[axis, 3] = a[axis] + b[axis]
    return S


def _rebuild(anim, keep):
    samplers = [anim["samplers"][c["sampler"]] for c in keep]
    return samplers, [dict(c, sampler=k) for k, c in enumerate(keep)]
