#!/usr/bin/env python3
"""Quái rừng low-poly mặt phẳng (D-203, theo concept người dùng gửi): dựng bằng Blender (bpy), mỗi bộ phận là một
khối cứng gắn vào một khớp (empty); hoạt ảnh xoay / dời khớp, xuất glTF mỗi hoạt ảnh một rãnh NLA cùng tên
(idle, run, attack, hit, death — rig `Creature` trong units_3d.json). Sói đã thay bằng mô hình Tripo gắn xương
(D-205, tools/models/rig_quadruped.py). Màu + sáng tối vẽ sẵn vào màu đỉnh như
style_kit (game vẽ không đèn). Hướng mặt: -Y Blender (= +Z Godot).

  <venv có bpy>/bin/python tools/models/creatures.py
Ghi assets/models/style/creatures/<tên>.glb.
"""
import math, os, random, sys
import bpy, bmesh
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import style_kit as K  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "style", "creatures")
FPS = 30
# hoạt ảnh: (số khung, lặp)
ANIMS = {"idle": (60, True), "run": (20, True), "attack": (24, False), "hit": (10, False), "death": (36, False)}
SAMPLES = 8  # số khóa mỗi hoạt ảnh

STONE = (128, 126, 120)
STONE_TOP = (156, 152, 142)
MOSS = (118, 146, 62)
GLOW = (255, 150, 40)


# ---------- dựng khối ----------

def _bm_ico(r, sub, scale, rng, jit=0.12):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bulge = {}
    for v in bm.verts:
        k = bulge.setdefault(tuple(round(c, 3) for c in v.co), rng.uniform(1 - jit, 1 + jit))
        v.co = Vector((v.co.x * scale[0] * k, v.co.y * scale[1] * k, v.co.z * scale[2] * k))
    return bm


def _bm_box(size, taper, rng, jit=0.05):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        t = taper if v.co.z > 0 else 1.0
        v.co = Vector((v.co.x * size[0] * t, v.co.y * size[1] * t, v.co.z * size[2]))
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jit * min(size)
    return bm


def _bm_cone(r, h, segs, rng):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=0.0, depth=h)
    for v in bm.verts:
        v.co.z += h / 2
    return bm


def _paint(obj, zone, rng):
    """Tô màu đỉnh theo mặt: zone(tâm mặt, pháp tuyến) → màu; sáng tối theo hướng nắng (không AO theo độ cao)."""
    me = obj.data
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in me.polygons:
        c = K.shade(zone(poly.center, poly.normal), poly.normal, 1.0, 1.0, rng)
        for li in poly.loop_indices:
            attr.data[li].color = c
    me.color_attributes.active_color = attr


class Rig:
    """Khớp (empty) + bộ phận (lưới cứng gắn khớp) + hoạt ảnh theo hàm tư thế."""

    def __init__(self, name, rng):
        self.name, self.rng, self.joints = name, rng, {}
        bpy.context.scene.render.fps = FPS
        self.mat = bpy.data.materials.new(name + "_mat")  # một vật liệu trơn: Godot bật màu đỉnh làm màu
        self.root = self.joint("root", (0, 0, 0), None)

    def joint(self, name, at, parent="root"):
        e = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(e)
        p = self.joints.get(parent) if parent else None
        e.location = Vector(at) - (p["at"] if p else Vector())
        if p:
            e.parent = p["obj"]
        self.joints[name] = {"obj": e, "at": Vector(at)}
        return e

    def part(self, joint, bm, at, zone):
        """Lưới `bm` (dựng quanh gốc) đặt tại `at` (toạ độ thế giới), gắn khớp `joint`."""
        j = self.joints[joint]
        off = Vector(at) - j["at"]
        for v in bm.verts:
            v.co += off
        me = bpy.data.meshes.new(f"{self.name}_{joint}_{len(bpy.data.meshes)}")
        bm.normal_update()
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(me)
        bm.free()
        me.materials.append(self.mat)
        obj = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = j["obj"]
        _paint(obj, zone, self.rng)
        return obj

    def animate(self, pose):
        """pose(tên, t 0..1) → {khớp: (rx, ry, rz độ, dx, dy, dz m)}. Mỗi hoạt ảnh nối tiếp trên dòng thời gian, mỗi
        khớp một action đẩy vào rãnh NLA mang tên hoạt ảnh; glTF NLA_TRACKS gộp các rãnh cùng tên thành một hoạt ảnh."""
        start = 1
        for name, (frames, _loop) in ANIMS.items():
            for k in range(SAMPLES + 1):
                t = k / SAMPLES
                full = {jn: (0, 0, 0, 0, 0, 0) for jn in self.joints}  # khớp không nói tới: về tư thế gốc
                full.update(pose(name, t))
                for jn, (rx, ry, rz, dx, dy, dz) in full.items():
                    obj = self.joints[jn]["obj"]
                    obj.rotation_euler = Euler((math.radians(rx), math.radians(ry), math.radians(rz)))
                    obj.location = self._rest(jn) + Vector((dx, dy, dz))
                    obj.keyframe_insert("rotation_euler", frame=start + round(t * frames))
                    obj.keyframe_insert("location", frame=start + round(t * frames))
            for jn, j in self.joints.items():
                obj = j["obj"]
                act = obj.animation_data.action
                act.name = f"{name}_{jn}"
                track = obj.animation_data.nla_tracks.new()
                track.name = name
                track.strips.new(name, start, act)
                obj.animation_data.action = None
            start += frames + 10
        for jn, j in self.joints.items():  # tư thế nghỉ khi xuất
            j["obj"].rotation_euler = Euler((0, 0, 0))
            j["obj"].location = self._rest(jn)

    def _rest(self, jn):
        j = self.joints[jn]
        return j["at"] - (self.joints[_parent(self, jn)]["at"] if j["obj"].parent else Vector())

    def export(self):
        os.makedirs(OUT, exist_ok=True)
        path = os.path.join(OUT, self.name + ".glb")
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_vertex_color="ACTIVE", export_normals=False,
                                  export_yup=True, export_animations=True, export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                                  export_force_sampling=True, export_frame_range=False,
                                  export_optimize_animation_size=False, export_optimize_animation_keep_anim_object=True)
        tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
        print(f"{self.name}: {tris} tam giác")


def _parent(rig, jn):
    p = rig.joints[jn]["obj"].parent
    return next(k for k, v in rig.joints.items() if v["obj"] is p)


def wave(t, n=1.0, phase=0.0):
    return math.sin((t * n + phase) * 2 * math.pi)


def bump(t, at, width):
    return max(0.0, 1.0 - abs(t - at) / width)


# ---------- golem đá (trại lớn) ----------

def golem(rng):
    r = Rig("golem", rng)
    stone = lambda c, n: MOSS if n.z > 0.6 and rng.random() < 0.55 else (STONE_TOP if n.z > 0.3 else STONE)
    glow = lambda c, n: GLOW
    r.joint("hips", (0, 0, 0.85))
    r.joint("torso", (0, 0, 1.0), "hips")
    r.part("torso", _bm_ico(0.62, 1, (1.15, 0.8, 0.85), rng), (0, 0, 1.45), stone)
    r.part("torso", _bm_box((0.16, 0.05, 0.16), 1.0, rng, 0), (0, -0.5, 1.4), glow)  # chữ rune
    r.joint("head", (0, -0.2, 1.95), "torso")
    r.part("head", _bm_box((0.46, 0.42, 0.36), 0.85, rng), (0, -0.25, 2.05), stone)
    for sx in (-1, 1):
        r.part("head", _bm_box((0.08, 0.04, 0.05), 1.0, rng, 0), (sx * 0.1, -0.47, 2.07), glow)
        sh = f"arm_{'l' if sx < 0 else 'r'}"
        r.joint(sh, (sx * 0.72, 0, 1.7), "torso")
        r.part(sh, _bm_ico(0.34, 1, (1, 1, 1.1), rng), (sx * 0.86, 0, 1.55), stone)
        r.part(sh, _bm_box((0.42, 0.42, 0.62), 0.9, rng), (sx * 0.95, -0.08, 0.95), stone)
        r.part(sh, _bm_box((0.5, 0.5, 0.36), 0.85, rng), (sx * 0.98, -0.12, 0.5), stone)
        lg = f"leg_{'l' if sx < 0 else 'r'}"
        r.joint(lg, (sx * 0.3, 0, 0.85), "hips")
        r.part(lg, _bm_box((0.4, 0.44, 0.85), 0.9, rng), (sx * 0.32, 0, 0.42), stone)

    def pose(name, t):
        p = {}
        if name == "idle":
            p["torso"] = (2 * wave(t), 0, 0, 0, 0, 0.03 * wave(t))
            p["arm_l"] = (4 * wave(t, 1, 0.25), 0, 0, 0, 0, 0)
            p["arm_r"] = (-4 * wave(t, 1, 0.25), 0, 0, 0, 0, 0)
        elif name == "run":
            s = wave(t)
            p["leg_l"], p["leg_r"] = (28 * s, 0, 0, 0, 0, 0), (-28 * s, 0, 0, 0, 0, 0)
            p["arm_l"], p["arm_r"] = (-22 * s, 0, 0, 0, 0, 0), (22 * s, 0, 0, 0, 0, 0)
            p["torso"] = (-8, 0, 6 * s, 0, 0, 0.05 * abs(wave(t, 2)))
        elif name == "attack":
            lift = bump(t, 0.35, 0.35)
            slam = bump(t, 0.55, 0.15)
            a = 130 * lift - 30 * slam
            p["arm_l"] = p["arm_r"] = (a, 0, 0, 0, 0, 0)
            p["torso"] = (-12 * lift + 18 * slam, 0, 0, 0, 0, 0)
        elif name == "hit":
            p["torso"] = (12 * bump(t, 0.3, 0.7), 0, 0, 0, 0, 0)
        elif name == "death":
            k = min(1.0, t * 1.4)
            p["hips"] = (-80 * k, 0, 0, 0, -0.4 * k, -0.55 * k)
            p["arm_l"], p["arm_r"] = (40 * k, 0, -30 * k, 0, 0, 0), (40 * k, 0, 30 * k, 0, 0, 0)
        return p
    r.animate(pose)
    r.export()


def main():
    for build, seed in ((golem, 11),):
        K.reset()
        build(random.Random(seed))


if __name__ == "__main__":
    main()
