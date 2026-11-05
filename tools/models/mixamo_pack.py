#!/usr/bin/env python3
"""Gộp hoạt ảnh Mixamo vào một GLB (D-238): một FBX có thân (With Skin hoặc nhân vật T-pose) + nhiều FBX hoạt ảnh
(Without Skin, cùng bộ xương `mixamorig`) → GLB một lưới, mỗi FBX một hoạt ảnh tên theo tên file. Sau đó dùng như
file afk.ai: `glb_anims.py` chọn / đổi tên / cắt / gắn vũ khí (`--attach vật.glb:mixamorig:RightHand`).

  <venv có bpy>/bin/python tools/models/mixamo_pack.py thân.fbx ra.glb thư_mục_hoặc_file.fbx …
"""
import glob, os, sys
import bpy


def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    return [o for o in bpy.data.objects if o not in before]


def _track(arm, act, name):
    act.name = name
    act.use_fake_user = True
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, int(act.frame_range[0]), act)
    if hasattr(strip, "action_slot") and len(getattr(act, "slots", [])):
        strip.action_slot = act.slots[0]
    track.mute = True


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    body, dst, srcs = argv[0], argv[1], argv[2:]
    files = []
    for s in srcs:
        files += sorted(glob.glob(os.path.join(s, "*.fbx"))) if os.path.isdir(s) else [s]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    arm = next(o for o in import_fbx(body) if o.type == "ARMATURE")
    own = arm.animation_data.action if arm.animation_data else None
    if own is not None:
        arm.animation_data.action = None
    arm.animation_data_create()
    names = set()
    if own is not None and own.frame_range[1] - own.frame_range[0] > 2:  # file có thân là hoạt ảnh With Skin: giữ cả nó
        _track(arm, own, os.path.splitext(os.path.basename(body))[0])
        names.add(own.name)
    for f in files:
        if os.path.abspath(f) == os.path.abspath(body):
            continue
        objs = import_fbx(f)
        src = next(o for o in objs if o.type == "ARMATURE")
        act = src.animation_data.action
        name = os.path.splitext(os.path.basename(f))[0]
        assert name not in names, f"trùng tên hoạt ảnh: {name}"
        names.add(name)
        _track(arm, act, name)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
        print(f"{name}: {int(act.frame_range[1] - act.frame_range[0])} khung")
    for img in bpy.data.images:  # tên ảnh Tripo dài → "albedo" như các mô hình khác (Godot đặt tên file ảnh theo đây)
        img.name = "albedo"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=dst, export_yup=True, export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True)
    print("→", dst, len(names), "hoạt ảnh")


if __name__ == "__main__":
    main()
