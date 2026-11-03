#!/usr/bin/env python3
"""Gắn xương + hoạt ảnh cho xe pháo Tripo (D-224; thay máy bắn đá D-218): afk.ai không có bộ xương cho xe (`object`
chỉ nhún / lắc), nên dựng ở đây — thân xe, nòng pháo (giật lùi khi bắn, quay quanh trục hai má đá), 4 bánh. Mỗi đỉnh
thuộc hẳn một xương (vật cứng), chia theo vùng hình học trong bảng dưới (tọa độ glTF sau khi xoay mặt về +Z bằng
glb_yaw.py: x ngang, y lên, z trước; lưới Tripo nằm giữa gốc, y −0,44…0,44). Hoạt ảnh theo rig `Creature`: idle / run
(bánh lăn) / attack (ngóc nòng ngắm, bắn ở 0,35: nòng giật lùi + xe khựng, trượt về) / hit / death.

  <venv có bpy>/bin/python tools/models/rig_siege.py vào_đã_xoay.glb ra.glb
"""
import math, sys
import bpy
import numpy as np
from mathutils import Quaternion, Vector

PIVOT = (0.0, 0.1, 0.02)  # trục nòng (giữa hai má đá)
BARREL = ((0.0, 0.08, -0.1), (0.0, 0.2, 0.52))  # đuôi nòng → miệng nòng
BARREL_RADIUS, BARREL_HALF_WIDTH, BARREL_MIN_Z = 0.16, 0.17, -0.14
WHEELS = {"wheel_fl": (0.37, -0.26, 0.26), "wheel_fr": (-0.37, -0.26, 0.26),
          "wheel_bl": (0.37, -0.26, -0.265), "wheel_br": (-0.37, -0.26, -0.265)}
WHEEL_RADIUS, WHEEL_INNER = 0.2, 0.29  # bánh: |x| > WHEEL_INNER và gần tâm bánh
FPS = 30
ANIMS = {"idle": 60, "run": 20, "attack": 30, "hit": 10, "death": 36}
RECOIL = 0.09  # m nòng giật lùi


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
    a, b = np.array(BARREL[0]), np.array(BARREL[1])
    t = np.clip(np.dot(np.array(p) - a, b - a) / np.dot(b - a, b - a), 0, 1)
    near = np.linalg.norm(np.array(p) - (a + t * (b - a))) < BARREL_RADIUS
    if abs(x) < BARREL_HALF_WIDTH and z > BARREL_MIN_Z and near:
        return "barrel"
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
    bones = {"barrel": (bl(PIVOT), bl(BARREL[1]))} | {n: (bl(c), bl(c) + Vector((0, 0, 0.12))) for n, c in WHEELS.items()}
    for name, (h, t) in bones.items():
        e = data.edit_bones.new(name)
        e.head, e.tail, e.parent = h, t, root
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {n: mesh.vertex_groups.new(name=n) for n in ["body", "barrel"] + list(WHEELS)}
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
# Quanh +X Blender: góc âm = nòng (mũi −Y) ngóc lên; góc dương = bánh lăn tới trước. +Y Blender = lùi về sau.
def recoil(k):
    ax = Vector(BARREL[1]) - Vector(BARREL[0])
    back = -bl(tuple(ax.normalized()))
    return tuple(back * RECOIL * k)


def pose(name, t):
    p = {}
    if name == "idle":
        p["body"] = (0.5 * math.sin(t * 2 * math.pi), (0, 0, 0.003 * math.sin(t * 4 * math.pi)))
        p["barrel"] = (-1.5 * math.sin(t * 2 * math.pi), (0, 0, 0))
    elif name == "run":
        for w in WHEELS:
            p[w] = (360.0 * t, (0, 0, 0))
        p["body"] = (1.0 * math.sin(t * 4 * math.pi), (0, 0, 0.008 * abs(math.sin(t * 2 * math.pi))))
    elif name == "attack":  # ngóc nòng ngắm, bắn ở 0,35: giật lùi mạnh, xe khựng, nòng trượt về chậm
        aim = ease(t / 0.3) if t < 0.35 else 1.0 - ease((t - 0.6) / 0.4)
        kick = ease((t - 0.33) / 0.04) if t < 0.4 else 1.0 - ease((t - 0.4) / 0.45)
        p["barrel"] = (-8 * aim - 6 * kick, recoil(kick))
        p["body"] = (-2.5 * kick, (0, 0.025 * kick, 0))
    elif name == "hit":
        p["body"] = (4 * bump(t, 0.3, 0.6), (0, 0.03 * bump(t, 0.3, 0.6), 0))
    elif name == "death":  # nghiêng đổ sang bên, lún xuống, nòng gục
        k = ease(t * 1.4)
        p["body"] = (0, (0, 0, -0.1 * k))
        p["body_roll"] = 26 * k
        p["barrel"] = (14 * k, (0, 0, 0))
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
    mesh = next(o for o in arm.children if o.type == "MESH")
    arm.location.z -= min((mesh.matrix_world @ v.co).z for v in mesh.data.vertices)  # D-219: gốc dưới bánh, khỏi chìm
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=argv[1], use_selection=True, export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_force_sampling=True, export_frame_range=False)
    print("→", argv[1])


if __name__ == "__main__":
    main()
