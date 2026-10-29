#!/usr/bin/env python3
"""D-176: sinh cây low-poly (≤ 150 tam giác, màu theo đỉnh, mặt phẳng) cho rừng chặn đường.

  python3 tools/models/make_low_trees.py
Ghi assets/models/custom/nature/low_tree_{round,pine,twin}.glb (gốc ở giữa đáy, cao ~3,2 đơn vị).
Màu đỉnh ghi thẳng (dự án đọc COLOR_0 như sRGB: ModelLibrary.use_vertex_colors, tree_fade.gdshader).
"""
import json, math, os, random, struct

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "custom", "nature")
TRUNK = (64, 40, 22)
LEAF = [(48, 112, 26), (70, 140, 32), (104, 170, 44)]  # tối → sáng (theo độ cao mặt)
PINE = [(26, 78, 34), (38, 100, 42), (58, 124, 52)]


def rgba(c):
    return [c[0] / 255, c[1] / 255, c[2] / 255, 1.0]


def prism(r, h, n, y0=0.0):
    """Thân cây: lăng trụ n cạnh, không đáy."""
    tris = []
    for i in range(n):
        a, b = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        p = [(r * math.cos(a), y0, r * math.sin(a)), (r * math.cos(b), y0, r * math.sin(b))]
        q = [(x * 0.75, y0 + h, z * 0.75) for x, _, z in p]
        tris += [(p[0], q[0], p[1]), (p[1], q[0], q[1])]
    return tris


def cone(r, h, n, y0, rot=0.0):
    tris = []
    top = (0.0, y0 + h, 0.0)
    for i in range(n):
        a, b = rot + 2 * math.pi * i / n, rot + 2 * math.pi * (i + 1) / n
        p, q = (r * math.cos(a), y0, r * math.sin(a)), (r * math.cos(b), y0, r * math.sin(b))
        tris += [(p, top, q), (q, (0.0, y0, 0.0), p)]
    return tris


def ico(sub):
    t = (1 + 5 ** 0.5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    v = [norm(p) for p in v]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
         (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    tris = [(v[a], v[b], v[c]) for a, b, c in f]
    for _ in range(sub):
        nxt = []
        for a, b, c in tris:
            ab, bc, ca = norm(mid(a, b)), norm(mid(b, c)), norm(mid(c, a))
            nxt += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        tris = nxt
    return tris


def blob(r, sy, at, sub, rng):
    """Tán tròn: cầu ico, nhấp nhô ngẫu nhiên theo đỉnh (cùng đỉnh → cùng độ lệch, không hở mặt)."""
    jit = {}
    def put(p):
        k = tuple(round(c, 4) for c in p)
        if k not in jit:
            jit[k] = rng.uniform(0.86, 1.1)
        s = r * jit[k]
        return (at[0] + p[0] * s, at[1] + p[1] * s * sy, at[2] + p[2] * s)
    return [tuple(put(p) for p in t) for t in ico(sub)]


def mid(a, b):
    return tuple((x + y) / 2 for x, y in zip(a, b))


def norm(p):
    n = math.sqrt(sum(c * c for c in p))
    return tuple(c / n for c in p)


def shade(tris, palette, y_lo, y_hi, rng):
    """Màu từng mặt theo độ cao tâm mặt (dưới tối, trên sáng) + nhiễu nhẹ."""
    out = []
    for t in tris:
        y = sum(p[1] for p in t) / 3
        k = min(len(palette) - 1, max(0, int((y - y_lo) / max(0.01, y_hi - y_lo) * len(palette) + rng.uniform(-0.4, 0.4))))
        out.append((t, palette[k]))
    return out


def build(name, parts):
    pos, nor, col = [], [], []
    for t, c in parts:
        a, b, d = t
        u, v = [b[i] - a[i] for i in range(3)], [d[i] - a[i] for i in range(3)]
        n = norm((u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]))
        for p in t:
            pos.append(p); nor.append(n); col.append(rgba(c))
    write_glb(os.path.join(OUT, name + ".glb"), name, pos, nor, col)
    print(f"{name}: {len(parts)} tam giác")


def write_glb(path, name, pos, nor, col):
    blob_ = b"".join(struct.pack("<3f", *p) for p in pos) + b"".join(struct.pack("<3f", *n) for n in nor) + b"".join(struct.pack("<4f", *c) for c in col)
    n = len(pos)
    lo = [min(p[i] for p in pos) for i in range(3)]
    hi = [max(p[i] for p in pos) for i in range(3)]
    j = {"asset": {"version": "2.0", "generator": "tools/models/make_low_trees.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
         "nodes": [{"name": name, "mesh": 0}],
         "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2}, "material": 0}]}],
         "materials": [{"name": "tree_vc", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 1}}],
         "buffers": [{"byteLength": len(blob_)}],
         "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 12 * n}, {"buffer": 0, "byteOffset": 12 * n, "byteLength": 12 * n},
                         {"buffer": 0, "byteOffset": 24 * n, "byteLength": 16 * n}],
         "accessors": [{"bufferView": 0, "componentType": 5126, "count": n, "type": "VEC3", "min": lo, "max": hi},
                       {"bufferView": 1, "componentType": 5126, "count": n, "type": "VEC3"},
                       {"bufferView": 2, "componentType": 5126, "count": n, "type": "VEC4"}]}
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    blob_ += b"\0" * (-len(blob_) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<3I", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob_)))
        f.write(struct.pack("<2I", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<2I", len(blob_), 0x004E4942) + blob_)


def main():
    rng = random.Random(176)
    trunk = lambda h: [(t, TRUNK) for t in prism(0.16, h, 5)]
    build("low_tree_round", trunk(1.0) + shade(blob(1.15, 0.9, (0, 2.1, 0), 1, rng), LEAF, 1.1, 3.1, rng))
    pine = cone(1.15, 1.4, 7, 0.7) + cone(0.9, 1.3, 7, 1.45, 0.4) + cone(0.6, 1.1, 7, 2.15, 0.8)
    build("low_tree_pine", trunk(0.8) + shade(pine, PINE, 0.7, 3.2, rng))
    twin = blob(0.95, 0.9, (0.25, 1.9, 0.1), 1, rng) + blob(0.7, 0.9, (-0.55, 1.45, -0.2), 0, rng)
    build("low_tree_twin", trunk(0.9) + shade(twin, LEAF, 0.9, 2.8, rng))


if __name__ == "__main__":
    main()
