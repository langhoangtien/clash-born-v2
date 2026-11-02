#!/usr/bin/env python3
"""Gắn xương + hoạt ảnh cho thú 4 chân dựng bằng Tripo (D-205).

Tripo rig quadruped cho sói thiếu hẳn chân trước phải (cả hai chân trước dính một xương) và chỉ có hoạt ảnh đi,
nên dựng xương ở đây: khớp đặt theo bảng MODELS (tọa độ glTF của mô hình Tripo gốc: x trước, y lên, z ngang;
đo bằng tools/models/rig_quadruped.py --probe), trọng số da tự tính (bone heat của Blender), rồi làm hoạt ảnh
idle / run / attack / hit / death (rig `Creature` trong units_3d.json). Mặt quay về -Y Blender (= +Z Godot).

  <venv có bpy>/bin/python tools/models/rig_quadruped.py <tên> vào.glb ra.glb [ra.blend]
ra.blend (tùy chọn): file Blender để sửa hoạt ảnh bằng tay (mỗi hoạt ảnh một action + rãnh NLA cùng tên).
"""
import math, os, sys
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import quadruped_anims as A  # noqa: E402

# Khớp mỗi mô hình (glTF, đất y = 0). Chân: vai/hông → khuỷu/gối → cổ chân → mũi bàn chân; z theo từng bên.
MODELS = {
    "neutral_wolf": {
        "ground": 0.357,  # mô hình Tripo gốc nằm giữa gốc tọa độ: nâng lên để chân chạm đất
        "hips": [(-0.20, 0.42), (0.0, 0.43)],
        "chest": [(0.0, 0.43), (0.17, 0.46)],
        "neck": [(0.17, 0.46), (0.26, 0.55)],
        "head": [(0.26, 0.55), (0.48, 0.47)],
        "tail": [(-0.26, 0.41), (-0.38, 0.33), (-0.50, 0.26)],
        "front": [(0.17, 0.42), (0.17, 0.25), (0.15, 0.10), (0.24, 0.02)],
        "front_z": {"l": -0.13, "r": 0.10},
        "hind": [(-0.15, 0.40), (-0.14, 0.26), (-0.26, 0.18), (-0.25, 0.02)],
        "hind_z": {"l": -0.11, "r": 0.075},
    },
}
LEG_BONES = {"front": ("upper", "lower", "paw"), "hind": ("thigh", "shin", "foot")}


def bl(x, y, z=0.0):
    """glTF (x trước, y lên, z ngang) → Blender sau khi xoay mặt về -Y: (-z, -x, y)."""
    return Vector((-z, -x, y))


def import_mesh(path, ground):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    for o in list(bpy.context.scene.objects):
        if o is not mesh and o.type != "MESH":
            mesh.parent = None
            bpy.data.objects.remove(o)
    mesh.matrix_world.identity()
    mesh.rotation_mode = "XYZ"
    mesh.rotation_euler = (0, 0, -math.pi / 2)  # glTF +x (mõm) → Blender -Y
    mesh.location = (0, 0, ground)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return mesh


def build_armature(m):
    data = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones

    def bone(name, a, b, parent=None, up=Vector((0, 0, 1)), deform=True):
        e = eb.new(name)
        e.head, e.tail = a, b
        e.align_roll(up)
        e.use_deform = deform
        if parent:
            e.parent = eb[parent]
        return e

    bone("root", Vector((0, 0, 0)), Vector((0, -0.2, 0)), deform=False)
    bone("hips", bl(*m["hips"][0]), bl(*m["hips"][1]), "root")
    bone("chest", bl(*m["chest"][0]), bl(*m["chest"][1]), "hips").use_connect = True
    bone("neck", bl(*m["neck"][0]), bl(*m["neck"][1]), "chest").use_connect = True
    bone("head", bl(*m["head"][0]), bl(*m["head"][1]), "neck").use_connect = True
    t = m["tail"]
    bone("tail_1", bl(*t[0]), bl(*t[1]), "hips")
    bone("tail_2", bl(*t[1]), bl(*t[2]), "tail_1").use_connect = True
    fwd = Vector((0, -1, 0))
    for kind, parent in (("front", "chest"), ("hind", "hips")):
        for side, z in m[kind + "_z"].items():
            pts = [bl(x, y, z) for x, y in m[kind]]
            prev = parent
            for k, nm in enumerate(LEG_BONES[kind]):
                name = f"{kind}_{nm}.{side}"
                bone(name, pts[k], pts[k + 1], prev, up=fwd).use_connect = k > 0
                prev = name
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(mesh, arm):
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    weld_weights(mesh)
    empty = [v.index for v in mesh.data.vertices if not v.groups]
    print(f"đỉnh không có trọng số: {len(empty)}")


def weld_weights(mesh):
    """Đỉnh trùng chỗ (tách ở đường may UV) lấy chung trọng số trung bình — không thì da nứt khi cử động."""
    spots = {}
    for v in mesh.data.vertices:
        spots.setdefault(tuple(round(c, 4) for c in v.co), []).append(v)
    groups = mesh.vertex_groups
    for vs in spots.values():
        if len(vs) < 2:
            continue
        acc = {}
        for v in vs:
            for g in v.groups:
                acc[g.group] = acc.get(g.group, 0.0) + g.weight / len(vs)
        for v in vs:
            for g in list(v.groups):
                groups[g.group].remove([v.index])
            for gi, w in acc.items():
                groups[gi].add([v.index], w, "REPLACE")


def export(arm, out):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, use_selection=True, export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_force_sampling=True, export_frame_range=False, export_def_bones=True,
                              export_optimize_animation_size=False)
    tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
    print(f"→ {out}: {tris} tam giác, {len(arm.data.bones)} xương")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    name, src, out = argv[:3]
    m = MODELS[name]
    mesh = import_mesh(src, m["ground"])
    arm = build_armature(m)
    skin(mesh, arm)
    A.animate(arm)
    export(arm, out)
    if len(argv) > 3:
        for act in bpy.data.actions:
            act.use_fake_user = True
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(argv[3]))


if __name__ == "__main__":
    main()
