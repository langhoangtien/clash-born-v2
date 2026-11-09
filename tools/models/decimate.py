#!/usr/bin/env python3
"""D-322: giảm tam giác một GLB tĩnh có ảnh màu (lưới Tripo trước khi gắn xương) bằng Blender (Decimate collapse, giữ UV).

  <venv có bpy>/bin/python tools/models/decimate.py vào.glb ra.glb --tris 3200
"""
import argparse, sys
import bpy


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--tris", type=int, required=True)
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    before = sum(len(o.data.polygons) for o in meshes)
    for o in meshes:
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.ratio = min(1.0, a.tris / max(1, tris))
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="dec")
    after = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    bpy.ops.export_scene.gltf(filepath=a.dst, export_format="GLB")
    print(f"{before} mặt → {after} tam giác → {a.dst}")


if __name__ == "__main__":
    main()
