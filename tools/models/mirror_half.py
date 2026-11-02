#!/usr/bin/env python3
"""Soi gương nửa sạch của mô hình sang nửa kia (D-205: Tripo dựng thừa một khối ở chân trước phải con sói).

  <venv có bpy>/bin/python tools/models/mirror_half.py vào.glb ra.glb --keep=-z [--center=-0.017]
--keep: nửa giữ lại theo trục glTF (+x/-x/+z/-z); --center: tọa độ mặt phẳng đối xứng trên trục đó (đo từ
khoảng giữa hai chân). Lưới được dời cho mặt phẳng về 0 rồi Symmetrize của Blender (gộp đỉnh ở đường giữa).
Ảnh màu và UV giữ nguyên: nửa mới dùng chung vùng ảnh của nửa cũ.
"""
import argparse, sys
import bpy

# trục glTF → (trục Blender sau khi nhập, dấu): glTF x → Blender x, glTF z → Blender -y
AXIS = {"x": (0, 1), "z": (1, -1)}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--keep", required=True, choices=["+x", "-x", "+z", "-z"])
    ap.add_argument("--center", type=float, default=0.0)
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.src)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    axis, sign = AXIS[a.keep[1]]
    keep_positive = (a.keep[0] == "+") == (sign > 0)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    shift = [0.0, 0.0, 0.0]
    shift[axis] = -a.center * sign
    bpy.ops.transform.translate(value=shift)
    bpy.ops.mesh.symmetrize(direction=("POSITIVE_" if keep_positive else "NEGATIVE_") + "XY"[axis],
                            threshold=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.export_scene.gltf(filepath=a.dst, use_selection=True, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print(f"→ {a.dst}: {tris} tam giác")


if __name__ == "__main__":
    main()
