#!/usr/bin/env python3
"""Chuyển hoạt ảnh Mixamo sang bộ xương afk.ai (D-242) — khi cả hai cùng bọc MỘT lưới (cùng thân Tripo, cùng tư thế
gốc, chỉ có thể lệch tịnh tiến). Mỗi khung: xương afk được đặt sao cho ma trận da (thế giới × bind nghịch) bằng ma
trận da của xương Mixamo tương ứng → vùng lưới của nó biến dạng y như bên Mixamo. Xương không có cặp (ngón tay, đầu
mút) giữ tư thế gốc. Hoạt ảnh mới thêm vào file afk, tên `MX <tên>`; sau đó build_units dùng như hoạt ảnh afk.

  python3 -I tools/models/retarget.py afk.glb mixamo.glb ra.glb "tên Mixamo" …
"""
import argparse, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as A  # noqa: E402
import glb_rig_ops as R  # noqa: E402

MAP = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck",
       "head": "Head", "thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
       "thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase"}
for side, s in (("l", "Left"), ("r", "Right")):
    MAP.update({f"clavicle_{side}": f"{s}Shoulder", f"upperarm_{side}": f"{s}Arm", f"lowerarm_{side}": f"{s}ForeArm",
                f"hand_{side}": f"{s}Hand"})
FPS = 30.0


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_quat(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
    else:
        i = int(np.argmax(np.diag(m)))
        j, k = (i + 1) % 3, (i + 2) % 3
        s = np.sqrt(1.0 + m[i, i] - m[j, j] - m[k, k]) * 2
        q = [0.0] * 4
        q[i] = 0.25 * s
        q[j] = (m[j, i] + m[i, j]) / s
        q[k] = (m[k, i] + m[i, k]) / s
        q[3] = (m[k, j] - m[j, k]) / s
    return np.array(q) / np.linalg.norm(q)


class Rig:
    def __init__(self, path):
        self.g, self.b = A.read(path)
        g = self.g
        self.parent = {c: i for i, n in enumerate(g["nodes"]) for c in n.get("children", [])}
        sk = g["skins"][0]
        self.joints = sk["joints"]
        ibm = A.array(g, self.b, sk["inverseBindMatrices"]).copy()  # bản sao: dst.b sắp nối thêm
        self.ibm = {j: m.reshape(4, 4).T for j, m in zip(self.joints, ibm)}
        self.index = {g["nodes"][j]["name"].split(":")[-1]: j for j in self.joints}

    def rest(self, i):
        n = self.g["nodes"][i]
        return n.get("translation", [0, 0, 0]), n.get("rotation", [0, 0, 0, 1]), n.get("scale", [1, 1, 1])

    def sampler(self, name):
        an = next(a for a in self.g["animations"] if a["name"] == name)
        out = {}
        for c in an["channels"]:
            s = an["samplers"][c["sampler"]]
            out[(c["target"]["node"], c["target"]["path"])] = (A.array(self.g, self.b, s["input"])[:, 0].copy(),
                                                                A.array(self.g, self.b, s["output"]).copy())
        length = max(float(v[0][-1]) for v in out.values())
        return out, length

    def world(self, ch, t):
        cache = {}

        def local(i):
            tr, rot, sc = self.rest(i)
            vals = {}
            for path in ("translation", "rotation", "scale"):
                if (i, path) in ch:
                    ti, v = ch[(i, path)]
                    vals[path] = np.array([np.interp(t, ti, v[:, k]) for k in range(v.shape[1])])
            rot = vals.get("rotation", np.array(rot, float))
            m = np.eye(4)
            m[:3, :3] = quat_mat(rot / np.linalg.norm(rot)) @ np.diag(vals.get("scale", sc))
            m[:3, 3] = vals.get("translation", tr)
            return m

        def w(i):
            if i not in cache:
                cache[i] = (w(self.parent[i]) if i in self.parent else np.eye(4)) @ local(i)
            return cache[i]
        return w


def bind_offset(dst, src):
    """Tịnh tiến từ không gian bind lưới afk sang lưới Mixamo (cùng thân Tripo, Mixamo đặt chân ở 0)."""
    def pos(rig):
        p = rig.g["meshes"][0]["primitives"][0]
        return A.array(rig.g, rig.b, p["attributes"]["POSITION"]).astype(float)
    a, m = pos(dst), pos(src)
    d = m[:3] - a[:3]
    assert np.allclose(d, d[0], atol=2e-3), "hai lưới không cùng thân (khác thứ tự đỉnh / tư thế)"
    return d[0]


def retarget(dst, src, name, offset):
    ch, length = src.sampler(name)
    times = np.arange(0.0, length + 1e-6, 1.0 / FPS)
    D, Dinv = np.eye(4), np.eye(4)
    D[:3, 3], Dinv[:3, 3] = offset, -offset
    order = [j for j in dst.joints]  # skin joints: cha trước con (afk)
    mapped = [j for j in order if dst.g["nodes"][j]["name"] in MAP]
    tracks = {j: ([], []) for j in mapped}
    for t in times:
        sw = src.world(ch, t)
        dw = {}

        def world_dst(j):
            if j in dw:
                return dw[j]
            name_j = dst.g["nodes"][j]["name"]
            if name_j in MAP:
                m = src.index[MAP[name_j]]
                dw[j] = Dinv @ sw(m) @ src.ibm[m] @ D @ np.linalg.inv(dst.ibm[j])
            else:
                tr, rot, sc = dst.rest(j)
                loc = np.eye(4)
                loc[:3, :3] = quat_mat(rot) @ np.diag(sc)
                loc[:3, 3] = tr
                dw[j] = (world_dst(dst.parent[j]) if dst.parent.get(j) in dst.joints else
                         _static_world(dst, dst.parent[j]) if j in dst.parent else np.eye(4)) @ loc
            return dw[j]
        for j in mapped:
            p = dst.parent[j]
            pw = world_dst(p) if p in dst.joints else _static_world(dst, p)
            loc = np.linalg.inv(pw) @ world_dst(j)
            u, _, vt = np.linalg.svd(loc[:3, :3])
            tracks[j][0].append(loc[:3, 3])
            tracks[j][1].append(mat_quat(u @ vt))
    an = {"name": "MX " + name, "channels": [], "samplers": []}
    g, b = dst.g, dst.b
    tin = R.add_accessor(g, b, times[:, None], "SCALAR", True)
    for j in mapped:
        q = np.array(tracks[j][1])
        for k in range(1, len(q)):  # giữ cùng bán cầu để nội suy không quay vòng
            if np.dot(q[k], q[k - 1]) < 0:
                q[k] = -q[k]
        for path, v, kind in (("translation", np.array(tracks[j][0]), "VEC3"), ("rotation", q, "VEC4")):
            an["samplers"].append({"input": tin, "output": R.add_accessor(g, b, v, kind), "interpolation": "LINEAR"})
            an["channels"].append({"sampler": len(an["samplers"]) - 1, "target": {"node": j, "path": path}})
    g["animations"].append(an)
    return len(times)


def _static_world(rig, i):
    m = np.eye(4)
    while True:
        tr, rot, sc = rig.rest(i)
        loc = np.eye(4)
        loc[:3, :3] = quat_mat(rot) @ np.diag(sc)
        loc[:3, 3] = tr
        m = loc @ m
        if i not in rig.parent:
            return m
        i = rig.parent[i]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("afk"); ap.add_argument("mixamo"); ap.add_argument("dst"); ap.add_argument("anims", nargs="+")
    a = ap.parse_args()
    dst, src = Rig(a.afk), Rig(a.mixamo)
    off = bind_offset(dst, src)
    for name in a.anims:
        print(f"MX {name}: {retarget(dst, src, name, off)} khung")
    A.write(a.dst, dst.g, A.prune(dst.g, dst.b))
    print("→", a.dst)


if __name__ == "__main__":
    main()
