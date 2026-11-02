"""Hoạt ảnh thú 4 chân cho bộ xương của rig_quadruped.py (D-205): idle, run, attack, hit, death.

Góc tính bằng độ, quanh trục cục bộ của xương (xương chân trục Z hướng trước, xương thân / đuôi trục Z hướng lên):
  rx > 0: chân vung ra trước, thân / cổ / đầu ngẩng lên, đuôi vểnh lên;  rz: quay ngang (đầu nhìn, đuôi vẫy).
Xương `root` (nằm trên đất, Y cục bộ hướng trước, Z lên) mang dời chỗ: (dx ngang, dy trước, dz lên) m.
"""
import math

FPS = 30
# tên: (số khung, lặp)
ANIMS = {"idle": (60, True), "run": (20, True), "attack": (24, False), "hit": (10, False), "death": (36, False)}
STEP = 2  # khung giữa hai khóa


def wave(t, n=1.0, phase=0.0):
    return math.sin((t * n + phase) * 2 * math.pi)


def bump(t, at, width):
    """0 → 1 → 0 quanh `at`, mượt (cos)."""
    d = abs(t - at) / width
    return 0.5 + 0.5 * math.cos(math.pi * d) if d < 1 else 0.0


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def legs(p, kind, side, swing, lift):
    """swing: góc vung (độ, + ra trước); lift 0..1: co chân khi nhấc."""
    if kind == "front":
        p[f"front_upper.{side}"] = (swing + 10 * lift, 0, 0)
        p[f"front_lower.{side}"] = (-45 * lift, 0, 0)
        p[f"front_paw.{side}"] = (-30 * lift, 0, 0)
    else:
        p[f"hind_thigh.{side}"] = (swing + 15 * lift, 0, 0)
        p[f"hind_shin.{side}"] = (35 * lift, 0, 0)
        p[f"hind_foot.{side}"] = (-40 * lift, 0, 0)


def idle(t):
    br = wave(t, 2)
    p = {"root": (0, 0, 0, 0, 0, 0.006 * br),
         "chest": (1.5 * br, 0, 0), "neck": (-1.5 * br, 0, 3 * wave(t, 1, 0.2)),
         "head": (3 * wave(t, 1, 0.5), 0, 6 * wave(t, 1, 0.25)),
         "tail_1": (4, 0, 12 * wave(t, 2)), "tail_2": (0, 0, 14 * wave(t, 2, -0.15))}
    return p


def run(t):
    p = {"root": (3 * wave(t, 2, 0.25), 0, 0, 0, 0, 0.03 * abs(wave(t))),
         "chest": (4 * wave(t, 2), 0, 0), "head": (-4 * wave(t, 2), 0, 0),
         "tail_1": (18, 0, 8 * wave(t)), "tail_2": (6, 0, 10 * wave(t, 1, -0.15))}
    # chạy nước kiệu: trước trái + sau phải cùng nhịp, đối pha cặp kia
    for kind, side, ph in (("front", "l", 0.0), ("hind", "r", 0.0), ("front", "r", 0.5), ("hind", "l", 0.5)):
        a = (t + ph) * 2 * math.pi
        legs(p, kind, side, 32 * math.sin(a), max(0.0, math.cos(a)))
    return p


def attack(t):
    crouch = bump(t, 0.22, 0.24)
    lunge = bump(t, 0.45, 0.22)
    p = {"root": (-6 * crouch + 4 * lunge, 0, 0, 0, -0.04 * crouch + 0.16 * lunge, -0.05 * crouch + 0.02 * lunge),
         "chest": (-6 * crouch, 0, 0), "neck": (-12 * crouch + 10 * lunge, 0, 0),
         "head": (-10 * crouch - 24 * bump(t, 0.47, 0.12) + 14 * bump(t, 0.38, 0.1), 0, 0),
         "tail_1": (10 * crouch + 20 * lunge, 0, 0)}
    for side in ("l", "r"):
        legs(p, "front", side, -12 * crouch + 30 * lunge, 0.6 * bump(t, 0.4, 0.15))
        legs(p, "hind", side, 14 * crouch - 18 * lunge, 0.4 * crouch)
    return p


def hit(t):
    k = bump(t, 0.3, 0.7)
    return {"root": (-6 * k, 0, 0, 0, -0.06 * k, 0), "chest": (6 * k, 0, 0),
            "neck": (8 * k, 0, 0), "head": (12 * k, 0, 6 * k), "tail_1": (-10 * k, 0, 0)}


def death(t):
    k = ease(t * 1.4)
    fall = ease(t * 1.4 - 0.15)
    p = {"root": (0, 88 * fall, 0, -0.04 * fall, 0, 0.16 * fall - 0.05 * bump(t, 0.12, 0.12)),
         "chest": (-6 * k, 0, 0), "neck": (-20 * k, 0, 0), "head": (-15 * k, 0, -10 * k),
         "tail_1": (-25 * k, 0, 0), "tail_2": (-10 * k, 0, 0)}
    for side, s in (("l", 1), ("r", -1)):
        legs(p, "front", side, 20 * k * s, 0.3 * k)
        legs(p, "hind", side, -20 * k * s, 0.3 * k)
    return p


POSES = {"idle": idle, "run": run, "attack": attack, "hit": hit, "death": death}


def animate(arm):
    """Mỗi hoạt ảnh một action, đẩy vào rãnh NLA cùng tên (glTF NLA_TRACKS xuất mỗi rãnh một hoạt ảnh)."""
    import bpy
    from mathutils import Euler, Vector
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    arm.animation_data_create()
    start = 0
    for name, (frames, _loop) in ANIMS.items():
        arm.animation_data.action = bpy.data.actions.new(name)
        for f in range(0, frames + 1, STEP):
            pose = POSES[name](f / frames)
            for b in pb:
                v = pose.get(b.name, (0, 0, 0))
                b.rotation_euler = Euler([math.radians(x) for x in v[:3]])
                b.location = Vector(v[3:6]) if len(v) > 3 else Vector()
                b.keyframe_insert("rotation_euler", frame=start + f)
                b.keyframe_insert("location", frame=start + f)
        act = arm.animation_data.action
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, start, act)
        arm.animation_data.action = None
        start += frames + 10
    for b in pb:
        b.rotation_euler = Euler((0, 0, 0))
        b.location = Vector()
