#!/usr/bin/env python3
"""Bộ asset tĩnh phong cách mới (bước 1 đồ họa): dựng bằng Blender (bpy), màu + sáng tối vẽ sẵn vào màu đỉnh
(camera cố định → không cần đèn, vẽ unshaded). Mỗi mặt một màu: hướng nắng (trên-trái-sau màn hình) chia 3 dải
sáng / vừa / tối; tối ngả xanh lạnh, sáng ngả ấm; chân tối dần (giả AO).

  <venv có bpy>/bin/python tools/models/style_kit.py
Ghi assets/models/style/*.glb (gốc ở giữa đáy, đơn vị mét = 100 px thế giới).
"""
import math, os, random
import bpy, bmesh
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "style")
SUN = Vector((-0.5, -0.55, 1.0)).normalized()  # Blender: x đông, y bắc, z lên — nắng từ trên, chếch tây nam (phía camera) như concept

# Bảng màu (sRGB 0–255) lấy từ concept người chơi duyệt.
PINE = (46, 84, 84)
PINE_LIGHT = (92, 126, 96)
TRUNK = (92, 50, 44)
ROUND = (112, 134, 70)
AUTUMN = (196, 128, 52)
LEAF_ORANGE = (214, 112, 48)
STONE = (104, 110, 116)
STONE_TOP = (138, 140, 140)
MOSS = (82, 98, 56)
REED = (112, 124, 66)
REED_TIP = (156, 134, 74)
TUFT = (92, 112, 60)
BUSH = (70, 100, 56)        # bụi cỏ (VIS-06): cùng sắc cỏ nền (98, 113, 71), đậm hơn cho rõ vùng bụi
BUSH_TIP = (124, 138, 72)
LILY = (66, 96, 58)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def shade(color, n, z, height, rng, light=None):
    """Màu một mặt: 3 dải theo hướng nắng, bóng ngả xanh lạnh, sáng ngả ấm, chân tối (z/height)."""
    t = n.dot(SUN)
    base = Vector(color) / 255.0
    hi = Vector(light) / 255.0 if light else base * 1.12 + Vector((0.04, 0.03, 0.0))
    lo = Vector((base.x * 0.55, base.y * 0.62, base.z * 0.68 + 0.02))
    c = lo if t < 0.05 else (base if t < 0.55 else hi)
    ao = 0.72 + 0.28 * min(1.0, max(0.0, z / max(0.01, height)) ** 0.6)
    c = c * ao * rng.uniform(0.95, 1.05)
    return (min(1, c.x), min(1, c.y), min(1, c.z), 1.0)


def paint(obj, zone, rng):
    """zone(face_center, normal) → (màu, màu sáng hoặc None). Ghi màu theo góc mặt (flat)."""
    me = obj.data
    height = max(v.co.z for v in me.vertices) or 1.0
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in me.polygons:
        col, light = zone(poly.center, poly.normal)
        c = shade(col, poly.normal, poly.center.z, height, rng, light)
        for li in poly.loop_indices:
            attr.data[li].color = c
    me.color_attributes.active_color = attr


def mesh_from(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def cone_tier(bm, r, h, z0, segs, droop, rng, twist):
    """Một tầng lá thông: đáy răng cưa (đỉnh xen kẽ trễ xuống), chóp nhọn."""
    ring = []
    for i in range(segs * 2):
        a = twist + math.pi * i / segs
        rr = r * (1.0 if i % 2 == 0 else 0.8) * rng.uniform(0.92, 1.06)
        zz = z0 - (droop if i % 2 == 0 else 0.0)
        ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), zz)))
    top = bm.verts.new((0, 0, z0 + h))
    mid = bm.verts.new((0, 0, z0 + 0.05))
    for i in range(len(ring)):
        bm.faces.new((ring[i], ring[(i + 1) % len(ring)], top))
        bm.faces.new((ring[(i + 1) % len(ring)], ring[i], mid))


def trunk(bm, r, h, segs=5):
    bot = [bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), 0)) for i in range(segs)]
    top = [bm.verts.new((v.co.x * 0.7, v.co.y * 0.7, h)) for v in bot]
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((bot[i], bot[j], top[j], top[i]))


def pine(name, height, rng):
    bm = bmesh.new()
    trunk(bm, 0.16 * height / 4, 0.9)
    tiers = 4 if height < 4 else (5 if height < 5 else 6)
    for k in range(tiers):
        f = k / tiers
        r = (1.25 - 0.85 * f) * height / 4.2
        z0 = 0.7 + f * (height - 1.6)
        cone_tier(bm, r, 1.25 * height / 4.2, z0, 7, 0.22 * height / 4.2, rng, rng.uniform(0, 1))
    obj = finish(name, bm)
    paint(obj, lambda c, n: (TRUNK, None) if c.z < 0.75 and Vector((c.x, c.y)).length < 0.3 else (PINE, PINE_LIGHT), rng)
    return obj


def puff_tree(name, color, rng, height=3.2):
    bm = bmesh.new()
    trunk(bm, 0.2, 1.4)
    for (x, y, z, r, sub) in ((0, 0, 2.15, 1.15, 2), (0.55, -0.2, 1.75, 0.8, 1), (-0.5, 0.3, 1.8, 0.85, 1), (0.1, 0.35, 2.75, 0.7, 1)):
        res = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r * height / 3.2)
        for v in res["verts"]:
            v.co = Vector((v.co.x * rng.uniform(0.9, 1.1) + x, v.co.y * rng.uniform(0.9, 1.1) + y, v.co.z * 0.85 * rng.uniform(0.92, 1.05) + z * height / 3.2))
    obj = finish(name, bm)
    paint(obj, lambda c, n: (TRUNK, None) if c.z < 1.3 and Vector((c.x, c.y)).length < 0.35 else (color, None), rng)
    return obj


def leaf_plant(name, rng):
    """Khóm lá cam thấp (lá dày hình thoi tỏa tròn) — điểm màu như concept."""
    bm = bmesh.new()
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0)) * 0.16
        L = rng.uniform(0.55, 0.75)
        p = [bm.verts.new(q) for q in (Vector((0, 0, 0.12)), d * L * 0.5 + s + Vector((0, 0, 0.32)), d * L + Vector((0, 0, 0.22)), d * L * 0.5 - s + Vector((0, 0, 0.32)))]
        bm.faces.new(p)  # một mặt: shader bộ asset vẽ cả hai phía
    obj = finish(name, bm)
    paint(obj, lambda c, n: (LEAF_ORANGE, None), rng)
    return obj


def slab(name, w, d, h, rng, lean=0.05):
    """Khối đá dựng kiểu concept: thân hộp hơi thuôn, mép đứng vát, đỉnh đẽo thành 2–3 mặt lệch nhau."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    top_edges = [e for e in bm.edges if all(v.co.z > 0 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=top_edges, cuts=1, use_grid_fill=True)
    for v in bm.verts:
        top = v.co.z > 0
        k = rng.uniform(0.82, 0.92) if top else 1.0
        v.co = Vector((v.co.x * w * k + (lean * h if top else 0.0), v.co.y * d * k, (v.co.z + 0.5) * h))
        if top:
            v.co.z -= rng.uniform(0.0, 0.16) * h * (abs(v.co.x) / w + abs(v.co.y) / d)
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > h * 0.5], offset=min(w, d) * 0.14, segments=1, affect="EDGES")
    side = [f for f in bm.faces if abs(f.normal.z) < 0.3 and f.calc_area() > w * h * 0.3]
    res = bmesh.ops.subdivide_edges(bm, edges=list({e for f in side for e in f.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 0.01}), cuts=1)
    for v in res["geom_inner"]:
        if isinstance(v, bmesh.types.BMVert):  # khía dọc thân: đá đẽo, không phẳng như gạch
            v.co.x *= rng.uniform(0.86, 1.0)
            v.co.y *= rng.uniform(0.86, 1.0)
    for v in bm.verts:
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.5, 0.5))) * 0.05 * w
    obj = finish(name, bm)
    paint(obj, lambda c, n: (MOSS, None) if n.z > 0.8 and c.z < h * 0.85 and rng.random() < 0.5 else ((STONE, STONE_TOP) if n.z <= 0.6 else (STONE_TOP, STONE_TOP)), rng)
    return obj


def blades(name, count, height, spread, color, tip, rng, width=0.07):
    """Khóm lá mảnh (lau sậy / cỏ): mỗi lá một tam giác dựng hơi nghiêng, ngọn ngả màu."""
    bm = bmesh.new()
    for _ in range(count):
        a = rng.uniform(0, 2 * math.pi)
        base = Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(0, spread)
        side = Vector((-math.sin(a), math.cos(a), 0)) * width
        h = height * rng.uniform(0.6, 1.1)
        lean = Vector((math.cos(a), math.sin(a), 0)) * h * rng.uniform(0.1, 0.35)
        bm.faces.new([bm.verts.new(base - side), bm.verts.new(base + side), bm.verts.new(base + lean + Vector((0, 0, h)))])
    obj = finish(name, bm)
    paint(obj, lambda c, n: (tip, None) if c.z > height * 0.55 else (color, None), rng)
    return obj


def bush(name, rng, blades_n=44, r=0.75, height=1.0):
    """Bụi cỏ (VIS-06, D-179): lõi vòm thấp màu đậm lấp chân + lá dài tỏa ra, cao giữa thấp mép, ngọn ngả vàng."""
    bm = bmesh.new()
    res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r * 0.7)
    for v in res["verts"]:
        v.co = Vector((v.co.x, v.co.y, max(0.0, v.co.z) * 0.4))
    for _ in range(blades_n):
        a = rng.uniform(0, 2 * math.pi)
        k = math.sqrt(rng.uniform(0, 1))
        out = Vector((math.cos(a), math.sin(a), 0))
        base = out * k * r * 0.85
        side = Vector((-out.y, out.x, 0)) * 0.13
        h = height * (1.0 - 0.45 * k * k) * rng.uniform(0.75, 1.1)
        tip = base + out * h * rng.uniform(0.2, 0.45) + Vector((0, 0, h))
        bm.faces.new([bm.verts.new(base - side), bm.verts.new(base + side), bm.verts.new(tip)])
    obj = finish(name, bm)
    # lõi (mặt gần ngang) một màu đậm, không dải sáng — khỏi thành mảng chanh dưới nắng
    paint(obj, lambda c, n: (BUSH, BUSH) if abs(n.z) > 0.5 else ((BUSH_TIP, None) if c.z > height * 0.6 else (BUSH, None)), rng)
    return obj


def boulder(name, rng, r, squash):
    """Đá cuội tròn mép nước: cầu ico thô, dẹt, lệch đỉnh ngẫu nhiên (cùng đỉnh cùng độ lệch — không hở mặt)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    bulge = {}
    for v in bm.verts:
        k = bulge.setdefault(tuple(round(c, 3) for c in v.co), rng.uniform(0.88, 1.08))
        v.co = Vector((v.co.x * k, v.co.y * k * rng.uniform(0.85, 1.0), (v.co.z * k * squash) + r * squash * 0.55))
    obj = finish(name, bm)
    paint(obj, lambda c, n: (MOSS, None) if n.z > 0.75 and rng.random() < 0.35 else ((STONE, STONE_TOP) if n.z <= 0.6 else (STONE_TOP, STONE_TOP)), rng)
    return obj


def lily(name, rng, r=0.32):
    """Lá súng: đĩa dẹt 9 cạnh có khía, nổi sát mặt nước."""
    bm = bmesh.new()
    center = bm.verts.new((0, 0, 0.02))
    ring = [bm.verts.new((r * math.cos(2 * math.pi * i / 9 + 0.5), r * math.sin(2 * math.pi * i / 9 + 0.5), 0.02)) for i in range(9)]
    for i in range(8):  # chừa một khía
        bm.faces.new((center, ring[i], ring[i + 1]))
    obj = finish(name, bm)
    paint(obj, lambda c, n: (LILY, None), rng)
    return obj


def finish(name, bm):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT, obj.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_vertex_color="ACTIVE", export_normals=False,
                              export_materials="NONE", export_yup=True)
    print(f"{obj.name}: {sum(len(p.vertices) - 2 for p in obj.data.polygons)} tam giác")


def main():
    import style_walls as W  # D-185: rào / tường thành dựng bằng khối đá
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(1)
    builders = [
        lambda: pine("pine_s", 3.2, rng), lambda: pine("pine_m", 4.4, rng), lambda: pine("pine_l", 5.6, rng),
        lambda: puff_tree("tree_round", ROUND, rng), lambda: puff_tree("tree_autumn", AUTUMN, rng, 3.6),
        lambda: leaf_plant("plant_orange", rng),
        lambda: slab("rock_tall", 1.3, 1.1, 2.4, rng), lambda: slab("rock_wide", 1.9, 1.2, 1.8, rng),
        lambda: slab("rock_low", 1.5, 1.1, 1.1, rng), lambda: slab("rock_small", 0.8, 0.7, 0.5, rng),
        lambda: W.fence("fence", random.Random(51)), lambda: W.great_wall("great_wall", random.Random(52)),
        lambda: blades("reeds", 15, 1.3, 0.45, REED, REED_TIP, rng, 0.09), lambda: blades("grass_tuft", 8, 0.45, 0.25, TUFT, REED, rng, 0.06),
        lambda: lily("lily", rng), lambda: W.wall_low("wall_low", random.Random(53)), lambda: boulder("boulder_a", rng, 1.0, 0.6), lambda: boulder("boulder_b", rng, 0.7, 0.72),
        lambda: bush("bush_a", rng, 56), lambda: bush("bush_b", rng, 46, 0.65, 0.9), lambda: bush("bush_c", rng, 64, 0.85, 1.1),
    ]
    for build in builders:
        reset()
        export(build())


if __name__ == "__main__":
    main()
