#!/usr/bin/env python3
"""GLB Tripo → FBX để tải lên Mixamo (D-207): xoay mặt về hướng Mixamo cần (+Z glTF = -Y Blender), chân chạm đất,
nhúng ảnh màu vào FBX.

  <venv có bpy>/bin/python tools/models/to_mixamo.py vào.glb ra.fbx [--face +x]
--face: hướng mặt của mô hình trong GLB (Tripo multiview thường nhìn +x).
"""
import argparse, math, sys
import bpy

YAW = {"+x": -math.pi / 2, "-x": math.pi / 2, "+z": 0.0, "-z": math.pi}  # góc xoay quanh trục đứng Blender


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--face", default="+x", choices=sorted(YAW))
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    mesh.parent = None
    mesh.rotation_mode = "XYZ"
    # glTF +x nhập vào Blender là +x; +z glTF là -y Blender. Mixamo cần mặt nhìn -y Blender (= +z glTF).
    mesh.rotation_euler = (0, 0, mesh.rotation_euler.z + YAW[a.face])
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    low = min(v.co.z for v in mesh.data.vertices)
    mesh.location.z -= low
    bpy.ops.object.transform_apply(location=True)
    bpy.ops.export_scene.fbx(filepath=a.dst, use_selection=True, path_mode="COPY", embed_textures=True)
    print(f"→ {a.dst}")


if __name__ == "__main__":
    main()
