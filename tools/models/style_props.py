"""D-317: vật trang trí rừng + đồ riêng từng loại trại quái, dựng bằng Blender cùng cách tô của style_kit (màu đỉnh, 3 dải
nắng, chân tối) — người chơi: đá / vật dựng Blender sắc nét hơn Tripo / Codex. Gọi từ style_kit.main().
Mọi vật thấp (≤ 0,6 m) trừ totem / pha lê (đặt trong vùng chặn, decor_camps.py)."""
import math
import bmesh
from mathutils import Vector
import style_kit as K

BONE = (222, 212, 186)
WOOD = (150, 104, 66)
WOOD_END = (206, 168, 112)
EMBER = (255, 168, 60)
FLAME = (255, 222, 120)
TOTEM_RED = (178, 64, 48)
TOTEM_TEAL = (54, 132, 128)
CRYSTAL = (86, 150, 214)
CRYSTAL_LIGHT = (176, 222, 250)
CAP = (196, 70, 48)
STEM = (232, 222, 200)
PETALS = ((236, 232, 220), (178, 140, 212), (240, 206, 92))


def _box(bm, center, size, rot=0.0, tilt=0.0):
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        p = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        p = Vector((p.x, p.y * math.cos(tilt) - p.z * math.sin(tilt), p.y * math.sin(tilt) + p.z * math.cos(tilt)))
        v.co = Vector((p.x * math.cos(rot) - p.y * math.sin(rot), p.x * math.sin(rot) + p.y * math.cos(rot), p.z)) + Vector(center)
    return res["verts"]


def _cyl(bm, center, r, length, segs, axis_rot):
    """Trụ nằm ngang dọc trục quay `axis_rot` (rad quanh z), tâm `center`."""
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r * 0.92, depth=length)
    for v in res["verts"]:
        x, y, z = v.co.z, v.co.x, v.co.y  # trục cone (z) → x
        v.co = Vector((x * math.cos(axis_rot) - y * math.sin(axis_rot), x * math.sin(axis_rot) + y * math.cos(axis_rot), z)) + Vector(center)


def bones(name, rng):
    """Đống xương (trại sói): 4 khúc xương nằm chéo + sọ dẹt."""
    bm = bmesh.new()
    for i in range(4):
        a = rng.uniform(0, math.pi)
        _box(bm, (rng.uniform(-0.3, 0.3), rng.uniform(-0.25, 0.25), 0.05), (0.5, 0.07, 0.07), a)
        for s in (-1, 1):  # đầu xương phình
            _box(bm, (math.cos(a) * 0.25 * s + rng.uniform(-0.3, 0.3) * 0, math.sin(a) * 0.25 * s, 0.06), (0.11, 0.13, 0.1), a)
    skull = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.17)
    for v in skull["verts"]:
        v.co = Vector((v.co.x * 1.2 + 0.32, v.co.y + 0.18, max(0.0, v.co.z) * 0.8 + 0.02))
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (BONE, None), rng)
    return obj


def log(name, rng):
    """Khúc gỗ đổ: thân nằm, đầu gỗ sáng, rêu trên lưng."""
    bm = bmesh.new()
    _cyl(bm, (0, 0, 0.2), 0.2, 1.7, 7, rng.uniform(-0.1, 0.1))
    _box(bm, (0.35, 0.12, 0.3), (0.35, 0.06, 0.06), 0.6)  # cành gãy
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (WOOD_END, None) if abs(n.x) > 0.9 else ((K.MOSS, None) if n.z > 0.85 and rng.random() < 0.6 else (WOOD, None)), rng)
    return obj


def stump(name, rng):
    """Gốc cây cụt: mặt cắt sáng có vòng, rễ tỏa."""
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.38, radius2=0.3, depth=0.4)
    for v in res["verts"]:
        v.co.z += 0.2
    for i in range(4):
        a = i * math.pi / 2 + rng.uniform(-0.3, 0.3)
        _box(bm, (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.06), (0.3, 0.1, 0.1), a, 0.0)
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (WOOD_END, WOOD_END) if n.z > 0.9 and c.z > 0.35 else (WOOD, None), rng)
    return obj


def campfire(name, rng):
    """Lửa trại (trại pháp sư): vòng đá nhỏ, 3 khúc củi, ngọn lửa hai tấm chéo màu sáng (không đèn → luôn rực)."""
    bm = bmesh.new()
    for i in range(8):
        a = 2 * math.pi * i / 8
        st = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.13)
        for v in st["verts"]:
            v.co = Vector((v.co.x + math.cos(a) * 0.48, v.co.y + math.sin(a) * 0.48, max(0.0, v.co.z) * 0.8))
    for i in range(3):
        _box(bm, (0, 0, 0.12), (0.6, 0.08, 0.08), i * math.pi / 3, 0.25)
    for a in (0.0, math.pi / 2):
        d = Vector((math.cos(a), math.sin(a), 0)) * 0.22
        bm.faces.new([bm.verts.new(-d + Vector((0, 0, 0.1))), bm.verts.new(d + Vector((0, 0, 0.1))), bm.verts.new((0, 0, 0.7))])
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (FLAME, FLAME) if c.z > 0.3 else ((EMBER, EMBER) if abs(n.z) < 0.2 and c.z > 0.15 and Vector((c.x, c.y)).length < 0.05 else ((K.STONE, K.STONE_TOP) if Vector((c.x, c.y)).length > 0.35 else (WOOD, None))), rng)
    return obj


def totem(name, rng):
    """Cột totem (trại pháp sư): 4 khối gỗ chồng tô xen đỏ / xanh ngọc, cánh ngang trên đỉnh. Cao 1,8 m."""
    bm = bmesh.new()
    for k in range(4):
        w = 0.42 - k * 0.03
        _box(bm, (0, 0, 0.22 + k * 0.42), (w, w * 0.9, 0.4), rng.uniform(-0.08, 0.08))
    _box(bm, (0, 0, 1.72), (1.0, 0.16, 0.14))
    obj = K.finish(name, bm)
    tiers = lambda z: int(z / 0.42)
    K.paint(obj, lambda c, n: ((TOTEM_RED if tiers(c.z) % 2 else TOTEM_TEAL), None) if abs(n.z) < 0.5 and c.z < 1.6 else (WOOD, None), rng)
    return obj


def crystals(name, rng):
    """Cụm pha lê xanh (trại lớn): 5 lăng trụ lục giác nhọn nghiêng tỏa trên bệ đá thấp. Cao ~1,3 m."""
    bm = bmesh.new()
    base = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.45)
    for v in base["verts"]:
        v.co = Vector((v.co.x, v.co.y, max(0.0, v.co.z) * 0.45))
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        lean = 0.0 if i == 0 else rng.uniform(0.25, 0.45)
        h = (1.3 if i == 0 else rng.uniform(0.6, 0.95))
        r = 0.13 if i == 0 else 0.09
        foot = Vector((math.cos(a), math.sin(a), 0)) * (0.0 if i == 0 else 0.22) + Vector((0, 0, 0.12))
        up = (Vector((math.cos(a) * math.sin(lean), math.sin(a) * math.sin(lean), math.cos(lean)))).normalized()
        side = up.cross(Vector((0, 0, 1)) if i else Vector((1, 0, 0))).normalized()
        side2 = up.cross(side)
        ring = [bm.verts.new(foot + (side * math.cos(t) + side2 * math.sin(t)) * r) for t in [k * math.pi / 3 for k in range(6)]]
        top = [bm.verts.new(v.co + up * h * 0.8) for v in ring]
        tip = bm.verts.new(foot + up * h)
        for k in range(6):
            bm.faces.new((ring[k], ring[(k + 1) % 6], top[(k + 1) % 6], top[k]))
            bm.faces.new((top[k], top[(k + 1) % 6], tip))
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (K.STONE, K.STONE_TOP) if c.z < 0.2 and Vector((c.x, c.y)).length > 0.25 else (CRYSTAL, CRYSTAL_LIGHT), rng)
    return obj


def mushrooms(name, rng):
    """Cụm nấm mũ đỏ (rừng, trại pháp sư): 4 cây nấm cao thấp."""
    bm = bmesh.new()
    for i in range(4):
        x, y = rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25)
        h = rng.uniform(0.18, 0.38)
        stem = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.04, radius2=0.035, depth=h)
        for v in stem["verts"]:
            v.co += Vector((x, y, h / 2))
        cap = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=h * 0.45)
        for v in cap["verts"]:
            v.co = Vector((v.co.x + x, v.co.y + y, max(0.0, v.co.z) * 0.7 + h))
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (CAP, None) if n.z > 0.2 and c.z > 0.15 else (STEM, None), rng)
    return obj


def flowers(name, rng):
    """Khóm hoa dại (khoảng rừng trống): lá cỏ ngắn + đốm hoa trắng / tím / vàng (tam giác nằm sát ngọn)."""
    bm = bmesh.new()
    heads = []
    for _ in range(24):
        a = rng.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0, 0.45)
        side = Vector((-math.sin(a), math.cos(a), 0)) * 0.04
        h = rng.uniform(0.18, 0.32)
        tip = base + Vector((0, 0, h))
        bm.faces.new([bm.verts.new(base - side), bm.verts.new(base + side), bm.verts.new(tip)])
        if rng.random() < 0.7:
            heads.append(tip)
    for p in heads:
        f = bm.faces.new([bm.verts.new(p + Vector((math.cos(t), math.sin(t), 0.02)) * 0.1) for t in (0, 2.1, 4.2)])
    obj = K.finish(name, bm)
    petals = {}
    K.paint(obj, lambda c, n: (petals.setdefault((round(c.x, 2), round(c.y, 2)), rng.choice(PETALS)), None) if n.z > 0.9 else (K.TUFT, None), rng)
    return obj


BUILDERS = [bones, log, stump, campfire, totem, crystals, mushrooms, flowers]
