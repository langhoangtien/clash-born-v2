#!/usr/bin/env python3
"""Đo biến dạng lưới theo hoạt ảnh của một GLB có da (D-399): so bản tự gắn với bản afk.

  python3 -I tools/models/anim_lib/deform_check.py a.glb b.glb --anims A,B,…

Mỗi khung: da tuyến tính (LBS) trên đỉnh đã gộp. Đếm (đỉnh / tam giác bị dính ít nhất một khung):
- giãn: đỉnh có cạnh dài > 2× lúc nghỉ;
- lật: tam giác có pháp tuyến quay > 90° so với pháp tuyến nghỉ đã xoay theo xương nặng nhất của tam giác;
- lún: tam giác diện tích < 10 % lúc nghỉ.
"""
import argparse, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as GA  # noqa: E402
import rig_math as RM  # noqa: E402
import mesh_slices as MS  # noqa: E402

STRETCH, AREA = 2.0, 0.1


def mats(q, t):
    x, y, z, w = (q[..., i] for i in range(4))
    m = np.zeros(q.shape[:-1] + (4, 4))
    m[..., 0, :3] = np.stack([1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], -1)
    m[..., 1, :3] = np.stack([2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)], -1)
    m[..., 2, :3] = np.stack([2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)], -1)
    m[..., :3, 3] = t
    m[..., 3, 3] = 1
    return m


class Skinned:
    def __init__(self, path):
        self.g, self.b = GA.read(path)
        g, b = self.g, self.b
        self.skel = RM.Skeleton(g)
        node = next(n for n in g["nodes"] if "mesh" in n)
        p = g["meshes"][node["mesh"]]["primitives"][0]
        v = np.array(GA.array(g, b, p["attributes"]["POSITION"]), float)
        t = np.array(GA.array(g, b, p["indices"]), np.int64).reshape(-1, 3)
        self.v, self.t, inv = MS.weld(v, t)
        first = np.zeros(len(self.v), np.int64)
        first[inv] = np.arange(len(inv))
        self.j = np.array(GA.array(g, b, p["attributes"]["JOINTS_0"]), np.int64)[first]
        w = np.array(GA.array(g, b, p["attributes"]["WEIGHTS_0"]), float)[first]
        self.w = w / np.maximum(w.sum(1, keepdims=True), 1e-9)
        skin = g["skins"][0]
        self.jidx = np.array([self.skel.index[j] for j in skin["joints"]])
        self.ibm = np.array(GA.array(g, b, skin["inverseBindMatrices"]), float).reshape(-1, 4, 4).transpose(0, 2, 1)

    def frames(self, name):
        an = next(a for a in self.g["animations"] if a["name"] == name)
        _, t, r = RM.sample(self.g, lambda i: GA.array(self.g, self.b, i), an, self.skel)
        wp, wr = self.skel.fk(t, r)
        M = mats(wr[:, self.jidx], wp[:, self.jidx]) @ self.ibm[None]  # (F, J, 4, 4)
        vh = np.concatenate([self.v, np.ones((len(self.v), 1))], 1)
        out = np.zeros((len(M), len(self.v), 3))
        for k in range(4):
            Mk = M[:, self.j[:, k]]  # (F, V, 4, 4)
            out += self.w[None, :, k, None] * np.einsum("fvij,vj->fvi", Mk, vh)[..., :3]
        return out, M


def tri_normals(v, t):
    n = np.cross(v[..., t[:, 1], :] - v[..., t[:, 0], :], v[..., t[:, 2], :] - v[..., t[:, 0], :])
    return n


def check(sk, name):
    vs, M = sk.frames(name)
    e = np.unique(np.sort(np.concatenate([sk.t[:, [0, 1]], sk.t[:, [1, 2]], sk.t[:, [2, 0]]]), 1), axis=0)
    rest_len = np.linalg.norm(sk.v[e[:, 0]] - sk.v[e[:, 1]], axis=1)
    n0 = tri_normals(sk.v, sk.t)
    a0 = np.linalg.norm(n0, axis=1)
    ok = a0 > 1e-10
    dom = sk.j[sk.t[:, 0], np.argmax(sk.w[sk.t[:, 0]], 1)]
    stretched, flipped, squashed = np.zeros(len(sk.v), bool), np.zeros(len(sk.t), bool), np.zeros(len(sk.t), bool)
    for f in range(len(vs)):
        ln = np.linalg.norm(vs[f, e[:, 0]] - vs[f, e[:, 1]], axis=1)
        bad = ln > STRETCH * np.maximum(rest_len, 1e-6)
        stretched[e[bad, 0]] = True
        stretched[e[bad, 1]] = True
        n = tri_normals(vs[f], sk.t)
        ref = np.einsum("tij,tj->ti", M[f, dom, :3, :3], n0)
        flipped |= ok & (np.sum(n * ref, 1) < 0)
        squashed |= ok & (np.linalg.norm(n, axis=1) < AREA * a0)
    return int(stretched.sum()), int(flipped.sum()), int(squashed.sum())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+"); ap.add_argument("--anims", required=True)
    a = ap.parse_args()
    sks = [Skinned(f) for f in a.files]
    print("| hoạt ảnh | " + " | ".join(f"{os.path.basename(f)}: giãn đỉnh / lật / lún tam giác" for f in a.files) + " |")
    for name in a.anims.split(","):
        print(f"| {name} | " + " | ".join("%d / %d / %d" % check(sk, name) for sk in sks) + " |")
    print(f"(đỉnh sau gộp: {[len(sk.v) for sk in sks]}, tam giác: {[len(sk.t) for sk in sks]})")


if __name__ == "__main__":
    main()
