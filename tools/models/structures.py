#!/usr/bin/env python3
"""Trụ low-poly mặt phẳng (D-203): thân đá bát giác cùng bảng màu đá chung (đá rừng / rào), chân loe, vành răng
cưa, mái nhọn + pha lê màu phe. Một file mỗi phe: <tên>_blue.glb / <tên>_red.glb. Màu + sáng tối vẽ sẵn vào màu đỉnh.

  <venv có bpy>/bin/python tools/models/structures.py
"""
import math, os, random, sys
import bpy, bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import style_kit as K  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "style", "structures")
TEAMS = {"blue": ((62, 112, 196), (120, 190, 255)), "red": ((186, 62, 56), (255, 150, 110))}  # (mái, pha lê)
WOOD = (110, 74, 52)


def prism(bm, r0, r1, z0, z1, sides, rng, twist=0.0):
    """Lăng trụ `sides` cạnh, bán kính đáy r0 → đỉnh r1."""
    ring = lambda r, z, k: [bm.verts.new((r * math.cos(2 * math.pi * i / sides + k) * rng.uniform(0.97, 1.03),
                                          r * math.sin(2 * math.pi * i / sides + k) * rng.uniform(0.97, 1.03), z)) for i in range(sides)]
    a, b = ring(r0, z0, 0.0), ring(r1, z1, twist)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)


def tower(team, rng, height=4.0):
    roof, crystal = TEAMS[team]
    bm = bmesh.new()
    prism(bm, 1.25, 1.1, 0.0, 0.45, 8, rng)            # bệ
    prism(bm, 0.95, 0.8, 0.45, height * 0.62, 8, rng)    # thân
    prism(bm, 1.05, 1.05, height * 0.62, height * 0.7, 8, rng)  # vành
    for i in range(8):  # răng cưa
        a = 2 * math.pi * (i + 0.5) / 8
        c = Vector((math.cos(a) * 0.95, math.sin(a) * 0.95, 0))
        res = bmesh.ops.create_cube(bm, size=1.0)
        for v in res["verts"]:
            v.co = Vector((v.co.x * 0.32, v.co.y * 0.32, (v.co.z + 0.5) * 0.32 + height * 0.7)) + c
    prism(bm, 0.25, 0.25, height * 0.7, height * 0.8, 6, rng)      # cột đỡ mái
    prism(bm, 0.95, 0.0, height * 0.8, height * 1.02, 8, rng, 0.2)  # mái nhọn
    obj = K.finish("tower_" + team, bm)
    top = height * 0.8

    def zone(c, n):
        if c.z > top - 0.01:
            return roof, None
        if c.z > height * 0.7 and abs(c.x) < 0.3 and abs(c.y) < 0.3:
            return WOOD, None
        return (K.STONE_TOP, K.STONE_TOP) if n.z > 0.6 else ((K.MOSS, None) if c.z < 0.5 and rng.random() < 0.3 else (K.STONE, K.STONE_TOP))
    K.paint(obj, zone, rng)
    gem = bmesh.new()
    bmesh.ops.create_icosphere(gem, subdivisions=0, radius=0.32)
    for v in gem.verts:
        v.co = Vector((v.co.x, v.co.y, v.co.z * 1.6 + height * 1.2))
    g = K.finish("crystal_" + team, gem)
    K.paint(g, lambda c, n: (crystal, None), rng)
    return [obj, g]


def main():
    os.makedirs(OUT, exist_ok=True)
    for team in TEAMS:
        K.reset()
        objs = tower(team, random.Random(3))
        mat = bpy.data.materials.new("tower_mat")
        for o in objs:
            o.data.materials.append(mat)
        bpy.ops.object.select_all(action="SELECT")
        path = os.path.join(OUT, f"tower_{team}.glb")
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_vertex_color="ACTIVE", export_normals=False, export_yup=True)
        print(path, sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons), "tam giác")


if __name__ == "__main__":
    main()
