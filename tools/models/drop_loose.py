#!/usr/bin/env python3
"""Bỏ các mảnh rời nhỏ (Tripo hay dựng thừa vũ khí / khối lơ lửng) khỏi GLB một lưới (D-207).

  python3 -I tools/models/drop_loose.py vào.glb ra.glb --max-tris 60 [--box x0,y0,z0,x1,y1,z1 …]
Mảnh rời = nhóm tam giác nối nhau qua đỉnh trùng chỗ; mảnh có ≤ --max-tris tam giác bị bỏ (đỉnh giữ nguyên, chỉ
bỏ chỉ số). In danh sách mảnh (số tam giác, hộp bao) để chọn ngưỡng.
"""
import argparse, json, struct
import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--max-tris", type=int, default=0)
    ap.add_argument("--box", action="append", default=[], help="D-318: bỏ tam giác nằm trọn trong hộp x0,y0,z0,x1,y1,z1 (lặp được)")
    a = ap.parse_args()
    b = bytearray(open(a.src, "rb").read())
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    base = 20 + n + 8
    p = j["meshes"][0]["primitives"][0]
    acc = lambda i: (j["accessors"][i], j["bufferViews"][j["accessors"][i]["bufferView"]])
    pa, pv = acc(p["attributes"]["POSITION"])
    po, stride = base + pv.get("byteOffset", 0) + pa.get("byteOffset", 0), pv.get("byteStride", 12)  # D-318: GLB xen kẽ (afk.ai)
    pos = np.array([np.frombuffer(b, np.float32, 3, po + r * stride) for r in range(pa["count"])])
    ia, iv = acc(p["indices"])
    dt = {5125: np.uint32, 5123: np.uint16}[ia["componentType"]]
    at = base + iv.get("byteOffset", 0) + ia.get("byteOffset", 0)
    tri = np.frombuffer(b, dt, ia["count"], at).reshape(-1, 3).copy()
    spot = {}
    wid = np.array([spot.setdefault(tuple(v), len(spot)) for v in np.round(pos, 4)])
    par = list(range(len(spot)))

    def root(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    for t in tri:
        r = root(wid[t[1]])
        par[root(wid[t[0]])] = r
        par[root(wid[t[2]])] = r
    label = np.array([root(wid[t[0]]) for t in tri])
    keep = np.ones(len(tri), bool)
    for lab in sorted(set(label), key=lambda x: -(label == x).sum()):
        m = label == lab
        box = pos[tri[m].ravel()]
        drop = m.sum() <= a.max_tris
        print(f"{m.sum():5d} tam giác  {box.min(0).round(2)} … {box.max(0).round(2)}{'  ← bỏ' if drop else ''}")
        keep[m] = not drop
    for spec in a.box:
        lo, hi = np.array([float(v) for v in spec.split(",")]).reshape(2, 3)
        inside = np.all((pos[tri] >= lo) & (pos[tri] <= hi), axis=(1, 2))
        print(f"hộp {spec}: bỏ {(inside & keep).sum()} tam giác")
        keep &= ~inside
    new = tri[keep].astype(dt).tobytes()
    b[at:at + len(new)] = new
    ia["count"] = int(keep.sum() * 3)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    rest = bytes(b[20 + n:])
    open(a.dst, "wb").write(struct.pack("<III", 0x46546C67, 2, 20 + len(js) + len(rest)) +
                           struct.pack("<I", len(js)) + b"JSON" + js + rest)
    print(f"→ {a.dst}: {keep.sum()} tam giác")


if __name__ == "__main__":
    main()
