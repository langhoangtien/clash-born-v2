#!/usr/bin/env python3
"""Tách vũ khí khỏi lưới hero Tripo (D-231): afk.ai gắn xương lưới còn cầm kiếm / khiên dang ra thì đặt sai xương
tay ("4 cái tay"). Gắn xương thân trơn, rồi gắn vũ khí cứng vào xương bàn tay (glb_rig_ops.attach_rigid).

  <venv có bpy>/bin/python tools/models/split_weapons.py vào_front.glb thân.glb --part tên:x0,x1,y0,y1,z0,z1 [...]
Mỗi --part: hộp (tọa độ glTF của file vào: x ngang, y lên, z trước) — đỉnh trong hộp thuộc vũ khí; mặt có đủ 3
đỉnh trong hộp tách sang <thân>_<tên>.glb; --loose: chỉ mảnh rời (nối qua cạnh) nằm trọn trong hộp. Phần còn lại ghi ra thân.glb. Cùng ảnh màu / UV.
"""
import argparse, os, sys
import bpy, bmesh


def _islands(bm):
    seen, out = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, isle = [f], []
        seen.add(f)
        while stack:
            cur = stack.pop()
            isle.append(cur)
            for e in cur.edges:
                for nb in e.link_faces:
                    if nb not in seen:
                        seen.add(nb)
                        stack.append(nb)
        out.append(isle)
    return out


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--part", action="append", default=[])
    ap.add_argument("--loose", action="store_true", help="chỉ tách mảnh rời nằm trọn trong hộp")
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for spec in a.part:
        name, box = spec.split(":")
        x0, x1, y0, y1, z0, z1 = (float(v) for v in box.split(","))
        bm = bmesh.new()
        bm.from_mesh(mesh.data)
        inside = lambda v: x0 <= v.co.x <= x1 and y0 <= v.co.z <= y1 and z0 <= -v.co.y <= z1  # glTF (x, y, z) = Blender (x, z, −y)
        part = [f for f in bm.faces if all(inside(v) for v in f.verts)]
        if a.loose:  # chỉ lấy mảnh rời nằm trọn trong hộp (giữ bàn tay nối liền cánh tay ở lại thân)
            part = [f for isle in _islands(bm) if all(inside(v) for f in isle for v in f.verts) for f in isle]
        out = bmesh.new()
        vmap = {}
        uv_in = bm.loops.layers.uv.active
        uv_out = out.loops.layers.uv.new("UVMap")
        for f in part:
            vs = []
            for v in f.verts:
                if v not in vmap:
                    vmap[v] = out.verts.new(v.co)
                vs.append(vmap[v])
            nf = out.faces.new(vs)
            for lo, li in zip(nf.loops, f.loops):
                lo[uv_out].uv = li[uv_in].uv
        bmesh.ops.delete(bm, geom=part, context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(mesh.data)
        me = bpy.data.meshes.new(name)
        out.to_mesh(me)
        me.materials.append(mesh.data.materials[0])
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        path = os.path.splitext(a.dst)[0] + "_" + name + ".glb"
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True)
        print(f"→ {path}: {len(part)} mặt")
        bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a.dst, use_selection=True, export_yup=True)
    print(f"→ {a.dst}: {len(mesh.data.polygons)} mặt")


if __name__ == "__main__":
    main()
