#!/usr/bin/env python3
"""Gắn xương + hoạt ảnh cho xe công thành Tripo (D-218): afk.ai không có bộ xương cho máy bắn đá (`object` chỉ
nhún / lắc), nên dựng ở đây — thân xe, cần bắn (quay quanh trục trên khung đá), 4 bánh. Mỗi đỉnh thuộc hẳn một
xương (vật cứng), chia theo vùng hình học trong bảng dưới (tọa độ glTF của mô hình Tripo gốc: x ngang, y lên,
z trước; đất y = −0,5). Hoạt ảnh theo rig `Creature`: idle / run (bánh lăn) / attack (cần vung qua đầu ra trước)
/ hit / death. Mặt xe quay +Z glTF (= −Y Blender) — đúng hướng game.

  <venv có bpy>/bin/python tools/models/rig_siege.py vào.glb ra.glb
"""
import math, sys
import bpy
import numpy as np
from mathutils import Quaternion, Vector

PIVOT = (0.0, 0.22, -0.02)  # trục cần bắn
ARM = ((0.0, 0.04, 0.32), (0.0, 0.42, -0.30))  # đầu thấp phía trước → gầu đá phía sau
ARM_RADIUS, ARM_HALF_WIDTH = 0.075, 0.08
BUCKET, BUCKET_RADIUS = (0.0, 0.40, -0.32), 0.21
WHEELS = {"wheel_fl": (0.42, -0.33, 0.25), "wheel_fr": (-0.42, -0.33, 0.25),
          "wheel_bl": (0.42, -0.33, -0.28), "wheel_br": (-0.42, -0.33, -0.28)}
WHEEL_RADIUS, WHEEL_INNER = 0.19, 0.34  # bánh: |x| > WHEEL_INNER và gần tâm bánh
FPS = 30
ANIMS = {"idle": 60, "run": 20, "attack": 36, "hit": 10, "death": 36}


def bl(p):
    """glTF (x, y, z) → Blender (x, −z, y)."""
    return Vector((p[0], -p[2], p[1]))


def part_of(p):
    """Xương sở hữu đỉnh p (tọa độ glTF)."""
    x, y, z = p
    if abs(x) > WHEEL_INNER:
        for name, c in WHEELS.items():
            if np.sign(x) == np.sign(c[0]) and math.hypot(y - c[1], z - c[2]) < WHEEL_RADIUS:
                return name
    a, b = np.array(ARM[0]), np.array(ARM[1])
    t = np.clip(np.dot(np.array(p) - a, b - a) / np.dot(b - a, b - a), 0, 1)
    if abs(x) < ARM_HALF_WIDTH and np.linalg.norm(np.array(p) - (a + t * (b - a))) < ARM_RADIUS:
        return "arm"
    if np.linalg.norm(np.array(p) - np.array(BUCKET)) < BUCKET_RADIUS and y > 0.22:
        return "arm"
    return "body"


def build(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    bpy.context.scene.render.fps = FPS  # mặc định Blender 24 → hoạt ảnh dài thêm 25%
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    data = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("body")
    root.head, root.tail = Vector((0, 0, 0)), Vector((0, 0, 0.3))
    bones = {"arm": (bl(PIVOT), bl(ARM[1]))} | {n: (bl(c), bl(c) + Vector((0, 0, 0.12))) for n, c in WHEELS.items()}
    for name, (h, t) in bones.items():
        e = data.edit_bones.new(name)
        e.head, e.tail, e.parent = h, t, root
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {n: mesh.vertex_groups.new(name=n) for n in ["body", "arm"] + list(WHEELS)}
    count = {}
    for v in mesh.data.vertices:
        w = mesh.matrix_world @ v.co
        owner = part_of((w.x, w.z, -w.y))
        groups[owner].add([v.index], 1.0, "REPLACE")
        count[owner] = count.get(owner, 0) + 1
    print("đỉnh theo xương:", count)
    mesh.parent = arm
    mesh.modifiers.new("rig", "ARMATURE").object = arm
    return arm


def bump(t, at, width):
    d = abs(t - at) / width
    return 0.5 + 0.5 * math.cos(math.pi * d) if d < 1 else 0.0


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


# Mỗi hoạt ảnh: t 0..1 → {xương: (độ quay quanh trục X thế giới, (dời x, y, z) Blender)}.
# Góc dương quanh +X Blender: gầu (phía sau, +Y) vung lên rồi ra trước (−Y); bánh lăn tới trước.
def pose(name, t):
    p = {}
    if name == "idle":
        p["body"] = (0.6 * math.sin(t * 2 * math.pi), (0, 0, 0.004 * math.sin(t * 4 * math.pi)))
    elif name == "run":
        for w in WHEELS:
            p[w] = (360.0 * t, (0, 0, 0))
        p["body"] = (1.2 * math.sin(t * 4 * math.pi), (0, 0, 0.01 * abs(math.sin(t * 2 * math.pi))))
    elif name == "attack":  # lùi cần lấy đà, vung mạnh qua đầu (tới 0,4), giữ, hạ chậm về
        swing = ease((t - 0.28) / 0.12) if t < 0.55 else 1.0 - ease((t - 0.55) / 0.4)
        p["arm"] = (-12 * bump(t, 0.18, 0.18) + 105 * swing, (0, 0, 0))
        p["body"] = (-4 * bump(t, 0.42, 0.12), (0, 0.02 * bump(t, 0.42, 0.12), 0))
    elif name == "hit":
        p["body"] = (5 * bump(t, 0.3, 0.6), (0, 0.03 * bump(t, 0.3, 0.6), 0))
    elif name == "death":  # nghiêng đổ sang bên, lún xuống, cần đổ về trước
        k = ease(t * 1.4)
        p["body"] = (0, (0, 0, -0.12 * k))
        p["body_roll"] = 28 * k
        p["arm"] = (60 * k, (0, 0, 0))
        p["wheel_fr"] = (0, (-0.06 * k, 0, 0.05 * k))
    return p


def set_pose(arm, p):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        ang, off = p.get(pb.name, (0, (0, 0, 0)))
        inv = pb.bone.matrix_local.to_3x3().inverted()
        q = Quaternion(inv @ Vector((1, 0, 0)), math.radians(ang))
        if pb.name == "body" and "body_roll" in p:
            q = q @ Quaternion(inv @ Vector((0, 1, 0)), math.radians(p["body_roll"]))
        pb.rotation_quaternion = q
        pb.location = inv @ Vector(off)


def animate(arm):
    arm.animation_data_create()
    start = 0
    for name, frames in ANIMS.items():
        arm.animation_data.action = bpy.data.actions.new(name)
        for f in range(0, frames + 1, 2):
            set_pose(arm, pose(name, f / frames))
            for pb in arm.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=start + f)
                pb.keyframe_insert("location", frame=start + f)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, start, arm.animation_data.action)
        arm.animation_data.action = None
        start += frames + 10
    set_pose(arm, {})


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    arm = build(argv[0])
    animate(arm)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=argv[1], use_selection=True, export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_force_sampling=True, export_frame_range=False)
    print("→", argv[1])


if __name__ == "__main__":
    main()
