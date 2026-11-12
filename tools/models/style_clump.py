#!/usr/bin/env python3
"""D-368: mẫu cây / bụi hướng 1 (D-365, người chơi chọn C2): tán là vài khối lá tròn to, mỗi mặt tô 3 dải sáng / vừa / tối
(shade của style_kit — nắng trên-trái, bóng ngả xanh lạnh) + vân lá vẽ tay chỉ lấy sáng tối (`leaf_paint`, Codex; units_3d.json
`faces`) → cùng cách vẽ với đá / đất. Bản MẪU: chưa đặt trên map (scenery_3d / decor không đổi).

  /opt/bpyvenv/bin/python tools/models/style_clump.py      → assets/models/style/tree_clump.glb, bush_clump.glb
"""
import math, os, random, sys
import bpy  # noqa: F401 — nạp trước bmesh
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import style_kit as K  # noqa: E402

LEAF = (78, 106, 52)
LEAF_LIGHT = (118, 136, 62)
BUSH_LEAF = (66, 92, 48)
BUSH_LIGHT = (102, 122, 56)


def clump(bm, at, r, squash, rng, sub=2):
    """Một khối lá: cầu ico lồi lõm nhẹ (đỉnh trùng chỗ cùng độ lệch — không hở), dẹt theo `squash`."""
    res = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bulge = {}
    for v in res["verts"]:
        k = bulge.setdefault(tuple(round(c, 3) for c in v.co), rng.uniform(0.9, 1.08))
        v.co = Vector((v.co.x * k + at[0], v.co.y * k + at[1], v.co.z * k * squash + at[2]))


def tree(name, rng, height=3.4):
    bm = bmesh.new()
    K.trunk(bm, 0.22, 1.5)
    s = height / 3.4
    for (x, y, z, r) in ((0.0, 0.0, 2.45, 1.05), (0.75, -0.25, 2.0, 0.78), (-0.7, 0.2, 2.05, 0.8), (0.15, 0.6, 2.2, 0.72),
                         (-0.15, -0.55, 2.15, 0.7), (0.2, 0.1, 3.05, 0.68)):
        clump(bm, (x * s, y * s, z * s), r * s, 0.82, rng)
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (K.TRUNK, None) if c.z < 1.45 * s and Vector((c.x, c.y)).length < 0.4 else (LEAF, LEAF_LIGHT), rng)
    return obj


def bush(name, rng):
    bm = bmesh.new()
    for (x, y, z, r) in ((0.0, 0.0, 0.42, 0.6), (0.5, 0.15, 0.32, 0.45), (-0.45, 0.1, 0.33, 0.47), (0.05, -0.42, 0.3, 0.42)):
        clump(bm, (x, y, z), r, 0.78, rng)
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (BUSH_LEAF, BUSH_LIGHT), rng)
    return obj


def main():
    rng = random.Random(368)
    for build in (lambda: tree("tree_clump", rng), lambda: bush("bush_clump", rng)):
        K.reset()
        K.export(build())


if __name__ == "__main__":
    main()
