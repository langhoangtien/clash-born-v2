#!/usr/bin/env python3
"""D-175: Tìm góc xoay / cỡ để chân mô hình khối đá (GLB Tripo) khớp nhất hình chiếu khối trong map.

  python3 -I tools/models/fit_block.py khối.glb bản_vẽ.json
Bản vẽ: art_inbox/07_kit/ban_ve/<tên>.json (polygon_guide, ô guide = 16 đơn vị thế giới).
In: yaw (độ, quay quanh trục đứng như Godot), lật x, cỡ (đơn vị thế giới / đơn vị mô hình), IoU chân.
"""
import json, math, struct, sys
import numpy as np
from PIL import Image, ImageDraw
from shapely.geometry import Polygon, MultiPoint
from shapely.ops import unary_union
from shapely import affinity

GUIDE = 16.0


def footprint(path):
    d = open(path, 'rb').read(); n = struct.unpack('<I', d[12:16])[0]; j = json.loads(d[20:20 + n]); off = 20 + n
    bl = struct.unpack('<I', d[off:off + 4])[0]; b = d[off + 8:off + 8 + bl]
    def acc(i, dt, c):
        a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]; o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.frombuffer(b, dt, a['count'] * c, o).reshape(a['count'], c)
    pr = j['meshes'][0]['primitives'][0]
    v = acc(pr['attributes']['POSITION'], np.float32, 3)
    ia = j['accessors'][pr['indices']]
    idx = acc(pr['indices'], {5125: np.uint32, 5123: np.uint16}[ia['componentType']], 1).reshape(-1, 3)
    low = v[:, 1].min() + 0.15 * np.ptp(v[:, 1])  # chân: tam giác có đỉnh ở 15% dưới
    tris = [Polygon(v[t][:, [0, 2]]) for t in idx if v[t][:, 1].min() <= low]
    tris = [t.buffer(0) for t in tris if t.area > 0]
    allp = unary_union([Polygon(v[t][:, [0, 2]]).buffer(0) for t in idx if Polygon(v[t][:, [0, 2]]).area > 0])
    return allp, v


def main():
    glb, plan = sys.argv[1], sys.argv[2]
    target = Polygon(json.load(open(plan))['polygon_guide']).buffer(0)
    target = affinity.scale(target, GUIDE, GUIDE, origin=(0, 0))
    fp, v = footprint(glb)
    best = None
    for flip in (1, -1):
        f0 = affinity.scale(fp, flip, 1, origin=(0, 0))
        for deg in range(0, 360, 3):
            # Godot: rotation.y = θ quay (x, z) → (x cosθ + z sinθ, -x sinθ + z cosθ)
            g = affinity.rotate(f0, -deg, origin=(0, 0))
            for mul in (0.85, 0.9, 0.95, 1.0):  # hơi nhỏ hơn được: chân không lòi ra lối / trụ
                s = math.sqrt(target.area / g.area) * mul
                h = affinity.scale(g, s, s, origin=(0, 0))
                h = affinity.translate(h, target.centroid.x - h.centroid.x, target.centroid.y - h.centroid.y)
                inter = h.intersection(target).area
                score = inter / h.union(target).area - 0.5 * (h.area - inter) / target.area  # phạt phần lòi ra ngoài
                if best is None or score > best[0]:
                    best = (score, deg, flip, s, inter / h.union(target).area)
    _, deg, flip, s, iou = best
    c = fp.centroid
    print(json.dumps({"yaw": deg, "flip_x": flip, "scale": round(s, 3), "iou": round(iou, 3),
                      "foot_center": [round(c.x, 5), round(c.y, 5)], "min_y": round(float(v[:, 1].min()), 5),
                      "model_height": round(float(np.ptp(v[:, 1])), 5)}))


if __name__ == "__main__":
    main()
