"""Rào đá, tường thành dựng bằng khối đá thật (D-185, theo concept): mỗi viên đá là một khối vát mép, cỡ lệch
nhau, cùng màu đá rừng (D-186), mạch là khe giữa các khối — không dán ảnh vân. Dùng helper của style_kit."""
import bmesh
from mathutils import Vector
import style_kit as K

# D-186: cùng bảng màu đá rừng (style_kit.STONE / STONE_TOP / MOSS) — mọi đá trong game một tông.
STONE_LIGHT = K.STONE_TOP       # mặt đỉnh
STONE_FACE = (116, 121, 126)    # mặt đứng (sáng hơn STONE một chút: tường to, đứng gần lane)
STONE_ALT = K.STONE             # viên lệch tông
MOSS = K.MOSS


def block(bm, cx, cy, sx, sy, z0, z1, bevel):
    """Một viên đá hộp vát mép, tâm (cx, cy), cỡ (sx, sy), từ z0 tới z1."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        v.co = Vector((cx + v.co.x * sx, cy + v.co.y * sy, z0 + (v.co.z + 0.5) * (z1 - z0)))
    edges = list({e for v in res["verts"] for e in v.link_edges})
    bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES")


def _course(bm, rng, length, y, depth, z0, z1, size, bevel):
    """Một hàng viên đá dọc trục x, dài mỗi viên size[0]–size[1], khe 0,06 m."""
    x = -length / 2
    while x < length / 2 - 0.2:
        w = min(rng.uniform(*size), length / 2 - x)
        top = z1 + rng.uniform(-0.05, 0.05) * (z1 - z0)
        block(bm, x + w / 2, y + rng.uniform(-0.03, 0.03), w - 0.06, depth, z0, top, bevel)
        x += w


def _paint(obj, rng, top_z):
    tone = {}
    def zone(c, n):
        if n.z > 0.6:
            return (MOSS, None) if c.z < top_z * 0.5 and rng.random() < 0.15 else (STONE_LIGHT, STONE_LIGHT)
        key = round(c.x, 0), round(c.z, 1)
        return (tone.setdefault(key, STONE_ALT if rng.random() < 0.35 else STONE_FACE), None)
    K.paint(obj, zone, rng)


def fence(name, rng, length=4.0, height=1.1, thick=0.7):
    """Rào đá ranh giới: lõi thấp + một hàng khối đá lớn cỡ lệch nhau trên đỉnh (kiểu lỗ châu mai thấp)."""
    bm = bmesh.new()
    block(bm, 0, 0, length, thick * 0.9, 0, height * 0.45, 0.04)
    _course(bm, rng, length, 0, thick, height * 0.4, height, (0.7, 1.15), 0.09)
    obj = K.finish(name, bm)
    _paint(obj, rng, height)
    return obj
