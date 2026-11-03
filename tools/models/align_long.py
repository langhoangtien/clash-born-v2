#!/usr/bin/env python3
"""Xoay lưới cho trục dài nhất (PCA) nằm theo trục Z glTF, tâm về gốc (D-224: đạn mảnh tinh thể bay theo hướng −Z).

  <venv có bpy>/bin/python tools/models/align_long.py vào.glb ra.glb
"""
import sys
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
pts = np.array([v.co[:] for v in mesh.data.vertices])
center = pts.mean(0)
_, _, vt = np.linalg.svd(pts - center, full_matrices=False)
long_axis = Vector(vt[0])
rot = long_axis.rotation_difference(Vector((0, -1, 0))).to_matrix().to_4x4()  # Blender −Y = glTF +Z
mesh.data.transform(rot @ Matrix.Translation(-Vector(center)))
bpy.ops.export_scene.gltf(filepath=argv[1], use_selection=True, export_yup=True)
print("→", argv[1])
