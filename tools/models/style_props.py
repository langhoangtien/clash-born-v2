"""D-317, D-318 (người chơi gửi ảnh mẫu: nấm, gốc cây, lửa, totem đẹp hơn): vật trang trí rừng + đồ riêng từng loại trại quái, dựng bằng Blender cùng cách tô của style_kit (màu đỉnh, 3 dải
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
CAP = (206, 58, 44)
SPOT = (246, 238, 224)
STEM = (238, 228, 206)
BARK = (118, 80, 52)
RING_DARK = (170, 128, 82)
ROPE = (196, 164, 112)
RUNE = (96, 214, 250)
BANNER = (190, 52, 40)
FLAME_OUT = (255, 132, 36)
PETAL = (246, 244, 236)
LEAF = (86, 132, 52)


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


def _glow(obj, pred, color):
    """Mặt thỏa `pred(tâm mặt)` tô một màu phẳng, không chia dải nắng (lửa, rune: vật tự sáng)."""
    attr = obj.data.color_attributes.active_color
    c = tuple(v / 255.0 for v in color) + (1.0,)
    for poly in obj.data.polygons:
        if pred(poly.center):
            for li in poly.loop_indices:
                attr.data[li].color = c


def bones(name, rng):
    """Bộ xương (trại sói / tê giác): sống lưng + 4 xương sườn cong, sọ to có hốc mắt sẫm, 2 khúc xương rời."""
    bm = bmesh.new()
    _box(bm, (0, 0, 0.06), (0.75, 0.07, 0.07))
    for i in range(4):
        x = -0.25 + i * 0.16
        for s in (-1, 1):
            _box(bm, (x, s * 0.13, 0.12), (0.05, 0.2, 0.05), 0.0, s * 0.9)
            _box(bm, (x, s * 0.2, 0.26), (0.05, 0.05, 0.12))
    skull = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.2)
    for v in skull["verts"]:
        v.co = Vector((v.co.x * 1.15 + 0.52, v.co.y, max(-0.02, v.co.z) * 0.85 + 0.16))
    for k in range(2):
        a = rng.uniform(0, math.pi)
        _box(bm, (-0.15 + k * 0.5, 0.42 * (1 if k else -1), 0.04), (0.42, 0.06, 0.06), a)
    obj = K.finish(name, bm)
    eye = lambda c, n: c.x > 0.6 and c.z > 0.2 and c.z < 0.32 and abs(c.y) > 0.04 and abs(c.y) < 0.12 and n.x > 0.5
    K.paint(obj, lambda c, n: ((60, 52, 44), (60, 52, 44)) if eye(c, n) else (BONE, None), rng)
    return obj


def _rings(c, n, top_z, r):
    """Mặt cắt gỗ: vòng tuổi sáng / sẫm xen theo bán kính."""
    d = Vector((c.x, c.y)).length / r
    return (WOOD_END if int(d * 5) % 2 == 0 else RING_DARK, WOOD_END)


def log(name, rng):
    """Khúc gỗ đổ to: thân 9 cạnh, mặt cắt có vòng tuổi, lưng phủ rêu dày, cành gãy."""
    bm = bmesh.new()
    _cyl(bm, (0, 0, 0.27), 0.27, 1.9, 9, 0.0)
    _box(bm, (0.3, 0.2, 0.42), (0.45, 0.08, 0.08), 0.7, 0.4)
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: _rings(Vector((0, c.y, c.z - 0.27)), n, 0, 0.27) if abs(n.x) > 0.9 else
            ((K.MOSS, (120, 156, 64)) if n.z > 0.55 else (BARK, None)), rng)
    return obj


def stump(name, rng):
    """Gốc cây to: thân 10 cạnh loe chân, mặt cắt vòng tuổi, 5 rễ bò, rêu viền mép."""
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.52, radius2=0.4, depth=0.55)
    for v in res["verts"]:
        v.co.z += 0.275
    for i in range(5):
        a = i * math.tau / 5 + rng.uniform(-0.2, 0.2)
        _box(bm, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.07), (0.42, 0.14, 0.12), a, 0.0)
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: _rings(c, n, 0.55, 0.4) if n.z > 0.9 and c.z > 0.5 else
            ((K.MOSS, None) if c.z > 0.42 and rng.random() < 0.5 else (BARK, None)), rng)
    return obj


def _flame(bm, a, r, h, z0):
    """Một tấm lửa răng cưa 3 lưỡi (dựng đứng theo hướng a)."""
    d = Vector((math.cos(a), math.sin(a), 0))
    pts = [-r, -r * 0.55, -r * 0.2, 0.0, r * 0.25, r * 0.6, r]
    hs = [0.0, h * 0.7, h * 0.45, h, h * 0.5, h * 0.75, 0.0]
    vs = [bm.verts.new(d * x + Vector((0, 0, z0 + y))) for x, y in zip(pts, hs)]
    base = bm.verts.new(Vector((0, 0, z0)))
    for k in range(len(vs) - 1):
        bm.faces.new((base, vs[k], vs[k + 1]))


def campfire(name, rng):
    """Lửa trại: vòng 9 viên đá, 4 khúc củi chéo, lửa 3 tấm cam bao lõi 3 tấm vàng (không đèn → luôn rực)."""
    bm = bmesh.new()
    for i in range(9):
        a = math.tau * i / 9
        st = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.16)
        for v in st["verts"]:
            v.co = Vector((v.co.x * 1.2 + math.cos(a) * 0.55, v.co.y + math.sin(a) * 0.55, max(0.0, v.co.z) * 0.85))
    for i in range(4):
        _box(bm, (0, 0, 0.14), (0.75, 0.1, 0.1), i * math.pi / 4, 0.3)
    for k in range(3):
        _flame(bm, k * math.pi / 3, 0.3, 0.75, 0.12)
    for k in range(3):
        _flame(bm, k * math.pi / 3 + 0.5, 0.17, 0.5, 0.13)
    obj = K.finish(name, bm)
    hub = lambda c: Vector((c.x, c.y)).length
    K.paint(obj, lambda c, n: (K.STONE, K.STONE_TOP) if hub(c) > 0.4 else (WOOD, None), rng)
    for poly in obj.data.polygons:  # lửa: mỗi tam giác lửa có đỉnh cao > 0,33 m (củi thấp hơn); lõi vàng sát trục
        vs = [obj.data.vertices[i].co for i in poly.vertices]
        if max(v.z for v in vs) > 0.33 and max(hub(v) for v in vs) < 0.33:
            col = FLAME if max(hub(v) for v in vs) < 0.18 else FLAME_OUT
            for li in poly.loop_indices:
                obj.data.color_attributes.active_color.data[li].color = tuple(v / 255.0 for v in col) + (1.0,)
    return obj


def totem(name, rng):
    """Cột totem (trại pháp sư): thân gỗ 8 cạnh, 2 dây quấn, sừng cong hai bên đỉnh, 2 cờ đỏ treo, chữ rune xanh
    phía trước, viên pha lê xanh trên chóp. Cao ~2 m."""
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.26, radius2=0.22, depth=1.7)
    for v in res["verts"]:
        v.co.z += 0.85
    for z in (0.75, 1.45):
        band = bmesh.ops.create_cone(bm, cap_ends=False, segments=8, radius1=0.27, radius2=0.27, depth=0.09)
        for v in band["verts"]:
            v.co.z += z
    for s in (-1, 1):
        horn = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.08, radius2=0.0, depth=0.5)
        for v in horn["verts"]:  # sừng: nón nghiêng ra ngoài + lên (55°), gốc cắm vào đỉnh cột
            x, z = v.co.x, v.co.z + 0.25
            a = s * math.radians(55)
            v.co = Vector((s * 0.2 + x * math.cos(a) + z * math.sin(a), v.co.y, 1.55 - x * math.sin(a) + z * math.cos(a)))
        _box(bm, (s * 0.3, -0.06, 1.05), (0.05, 0.16, 0.42))
    _box(bm, (0, -0.24, 1.1), (0.16, 0.04, 0.2))  # rune mặt −Y Blender = mặt +Z Godot (quay về camera)
    tip = bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.07, radius2=0.0, depth=0.3)
    for v in tip["verts"]:
        v.co.z += 1.85
    obj = K.finish(name, bm)
    def zone(c, n):
        if c.z > 1.72 and abs(c.x) < 0.1:
            return (RUNE, RUNE)
        if abs(c.x) > 0.3 and c.z > 1.5:
            return (BONE, None)
        if abs(c.x) > 0.27 and c.z < 1.3:
            return (BANNER, None)
        if c.y < -0.23 and abs(c.x) < 0.17 and 0.9 < c.z < 1.3:
            return (RUNE, RUNE)
        if abs(c.z - 0.75) < 0.06 or abs(c.z - 1.45) < 0.06:
            return (ROPE, None)
        return (WOOD, None)
    K.paint(obj, zone, rng)
    _glow(obj, lambda c: (c.z > 1.72 and abs(c.x) < 0.1) or (c.y < -0.23 and abs(c.x) < 0.17 and 0.9 < c.z < 1.3), RUNE)
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
    """Cụm nấm mũ đỏ chấm trắng (ảnh mẫu): 4 cây chân trắng mập, mũ vòm tròn, to nhỏ lẫn lộn."""
    bm = bmesh.new()
    for i in range(4):
        x, y = rng.uniform(-0.28, 0.28), rng.uniform(-0.28, 0.28)
        h = rng.uniform(0.22, 0.48)
        stem = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=h * 0.2, radius2=h * 0.15, depth=h)
        for v in stem["verts"]:
            v.co += Vector((x, y, h / 2))
        cap = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=h * 0.55)
        for v in cap["verts"]:
            v.co = Vector((v.co.x + x, v.co.y + y, max(-0.1 * h, v.co.z) * 0.75 + h))
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: ((SPOT, SPOT) if rng.random() < 0.22 else (CAP, None)) if n.z > 0.1 and c.z > 0.18 else (STEM, None), rng)
    return obj


def flowers(name, rng):
    """Khóm hoa trắng (ảnh mẫu): lá xanh tỏa thấp + 6 bông 5 cánh trắng nhụy vàng trên cuống."""
    bm = bmesh.new()
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0)) * 0.07
        bm.faces.new([bm.verts.new(v) for v in (Vector((0, 0, 0.04)), d * 0.22 + s + Vector((0, 0, 0.1)), d * 0.4 + Vector((0, 0, 0.06)), d * 0.22 - s + Vector((0, 0, 0.1)))])
    for _ in range(6):
        c = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), rng.uniform(0.2, 0.32)))
        for k in range(5):
            a = math.tau * k / 5
            bm.faces.new([bm.verts.new(c + Vector((0, 0, 0.01))), bm.verts.new(c + Vector((math.cos(a - 0.35), math.sin(a - 0.35), 0)) * 0.07),
                          bm.verts.new(c + Vector((math.cos(a + 0.35), math.sin(a + 0.35), 0)) * 0.07), bm.verts.new(c + Vector((math.cos(a), math.sin(a), 0.01)) * 0.1)])
    obj = K.finish(name, bm)
    K.paint(obj, lambda c, n: (LEAF, None) if c.z < 0.15 else (PETAL, PETAL), rng)
    return obj


BUILDERS = [bones, log, stump, campfire, totem, crystals, mushrooms, flowers]
