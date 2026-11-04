#!/usr/bin/env python3
"""Cho vũ khí / khiên dính cứng vào một xương (D-233): gắn xương tự động chia đỉnh của khiên cho nhiều xương (cẳng tay,
bàn tay, ngón…) nên khi tay gập khiên bị uốn cong. Mảnh rời (nối qua cạnh) gần xương nào trong `--prop` thì toàn bộ
đỉnh của mảnh đó chỉ thuộc xương ấy, trọng số 1. Giữ nguyên bộ xương (vd mixamorig) để nạp lại Mixamo.

  <venv có bpy>/bin/python tools/models/rigid_props.py vào.fbx ra.fbx --prop mixamorig:LeftHand --prop mixamorig:RightHand
        [--min 20 --max 300 --touch 0.1 --center 0.2] [ra.glb]
Mảnh được chọn: số đỉnh trong [min, max] và (đỉnh gần nhất cách đầu xương ≤ touch hoặc tâm mảnh ≤ center); in danh
sách mảnh đã gán — kiểm tra kỹ, chỉnh ngưỡng nếu gán nhầm (vd miếng vai gần tay).
"""
import argparse, sys
import bpy, bmesh
from mathutils import Vector


def islands(mesh):
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, cur = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            cur.append(x.index)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        out.append(cur)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst"); ap.add_argument("glb", nargs="?")
    ap.add_argument("--prop", action="append", required=True)
    ap.add_argument("--min", type=int, default=20)
    ap.add_argument("--max", type=int, default=300)
    ap.add_argument("--touch", type=float, default=0.1, help="đỉnh gần nhất cách đầu xương ≤ (m)")
    ap.add_argument("--center", type=float, default=0.2, help="hoặc tâm mảnh cách đầu xương ≤ (m)")
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.fbx(filepath=a.src)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    arm = mesh.find_armature()
    mw = mesh.matrix_world
    pos = [mw @ v.co for v in mesh.data.vertices]
    heads = {b: arm.matrix_world @ arm.data.bones[b].head_local for b in a.prop}
    for isle in islands(mesh):
        if not a.min <= len(isle) <= a.max:
            continue
        near = {b: min((pos[i] - h).length for i in isle) for b, h in heads.items()}
        mid = sum((pos[i] for i in isle), Vector()) / len(isle)
        bone = min(near, key=near.get)
        if near[bone] > a.touch and (mid - heads[bone]).length > a.center:
            continue
        for g in mesh.vertex_groups:
            g.remove(isle)
        grp = mesh.vertex_groups.get(bone) or mesh.vertex_groups.new(name=bone)
        grp.add(isle, 1.0, "REPLACE")
        print(f"mảnh {len(isle)} đỉnh → {bone} (cách {near[bone]:.2f} m)")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=a.dst, path_mode="COPY", embed_textures=True, add_leaf_bones=False,
                             bake_anim=False)
    print("→", a.dst)
    if a.glb:
        bpy.ops.export_scene.gltf(filepath=a.glb, export_yup=True)
        print("→", a.glb)


if __name__ == "__main__":
    main()
