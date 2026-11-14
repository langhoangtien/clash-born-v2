"""Cắt lưới theo mặt phẳng ngang → các vòng tiết diện (D-399, tự gắn xương).

Lưới dáng chữ A, mặt quay +Z, trục đứng +Y. Mỗi vòng = một thành phần liên thông của các đoạn cắt (hai đoạn chung
một cạnh lưới là nối nhau): tâm, khoảng x / z, số điểm.
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import glb_anims as GA  # noqa: E402
import rig_math as RM  # noqa: E402


def load_mesh(path):
    """Mọi primitive của mọi nút có lưới, đã áp biến đổi nút (Tripo `_front.glb` có xoay trên nút) → (đỉnh, tam giác)."""
    g, b = GA.read(path)
    nodes = g["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    verts, tris, base = [], [], 0
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        chain, k = [], i
        while k is not None:
            chain.append(nodes[k])
            k = parent.get(k)
        for p in g["meshes"][n["mesh"]]["primitives"]:
            v = np.array(GA.array(g, b, p["attributes"]["POSITION"]), float)
            if "skin" not in n:  # nút có da: glTF bỏ qua biến đổi nút
                for nd in chain:
                    s = np.array(nd.get("scale", [1, 1, 1]), float)
                    v = RM.qrot(np.array(nd.get("rotation", [0, 0, 0, 1]), float)[None], v * s) \
                        + np.array(nd.get("translation", [0, 0, 0]), float)
            idx = np.array(GA.array(g, b, p["indices"]), np.int64).reshape(-1, 3)
            verts.append(v)
            tris.append(idx + base)
            base += len(v)
    return np.concatenate(verts), np.concatenate(tris)


def weld(verts, tris, eps=1e-5):
    """Gộp đỉnh trùng chỗ (Tripo tách đỉnh ở đường may UV) để cạnh chung được nhận ra."""
    key = np.round(verts / eps).astype(np.int64)
    _, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
    return verts[first], inv.reshape(-1)[tris], inv.reshape(-1)


class Slicer:
    def __init__(self, verts, tris):
        self.v, self.t = weld(verts, tris)[:2]
        e = np.sort(np.concatenate([self.t[:, [0, 1]], self.t[:, [1, 2]], self.t[:, [2, 0]]]), axis=1)
        self.edges, inv = np.unique(e, axis=0, return_inverse=True)
        self.tri_edges = inv.reshape(3, -1).T  # mỗi tam giác: 3 chỉ số cạnh

    def rings(self, y):
        """Các vòng tiết diện ở độ cao y: danh sách dict(c=tâm, lo, hi, n)."""
        ya, yb = self.v[self.edges[:, 0], 1], self.v[self.edges[:, 1], 1]
        cross = (np.minimum(ya, yb) <= y) & (np.maximum(ya, yb) > y)
        if not cross.any():
            return []
        f = (y - ya) / np.where(yb == ya, 1, yb - ya)
        pts = self.v[self.edges[:, 0]] + (self.v[self.edges[:, 1]] - self.v[self.edges[:, 0]]) * f[:, None]
        par = np.arange(len(self.edges))

        def find(a):
            while par[a] != a:
                par[a] = par[par[a]]
                a = par[a]
            return a
        for te in self.tri_edges[cross[self.tri_edges].sum(1) == 2]:
            a, b = te[cross[te]]
            ra, rb = find(a), find(b)
            if ra != rb:
                par[ra] = rb
        ids = np.nonzero(cross)[0]
        roots = np.array([find(i) for i in ids])
        out = []
        for r in np.unique(roots):
            p = pts[ids[roots == r]]
            out.append({"c": p.mean(0), "lo": p.min(0), "hi": p.max(0), "n": len(p)})
        return sorted(out, key=lambda d: d["c"][0])
