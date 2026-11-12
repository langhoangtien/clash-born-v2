#!/usr/bin/env python3
"""D-367: tính `bow_string.tips` (units_3d.json, D-349) cho cung đặt bằng place_prop.py: hai đầu dây cũ của lưới cung
Tripo (trước khi bỏ dây) → toạ độ trong xương cầm cung, cùng phép đặt place_prop dùng cho lưới cung đã bỏ dây.

  python3 -I tools/models/bow_tips.py thân_afk.glb cung_đủ_dây.glb cung_bỏ_dây.glb --box x0,y0,z0,x1,y1,z1
        --bone hand_l --size 0.62 --grip 0.5 --rot=… [--reach 0.045] [--offset 0,0,0]
`--box`: hộp chứa dây trong lưới cung gốc (như drop_loose.py); đầu dây = đỉnh cao nhất / thấp nhất trong hộp.
"""
import argparse, json, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as A  # noqa: E402
from place_prop import rot  # noqa: E402


def positions(path):
    g, b = A.read(path)
    return A.array(g, b, g["meshes"][0]["primitives"][0]["attributes"]["POSITION"]).astype(np.float64)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("body"); ap.add_argument("bow"); ap.add_argument("bare")
    ap.add_argument("--box", required=True)
    ap.add_argument("--bone", default="hand_l")
    ap.add_argument("--size", type=float, required=True)
    ap.add_argument("--grip", type=float, default=0.5)
    ap.add_argument("--grip-depth", type=float, default=0.5)
    ap.add_argument("--rot", default="0,0,0")
    ap.add_argument("--reach", type=float, default=0.045)
    ap.add_argument("--offset", default="0,0,0")
    a = ap.parse_args()
    g, b = A.read(a.body)
    sk = g["skins"][0]
    names = [g["nodes"][j]["name"] for j in sk["joints"]]
    ibm = A.array(g, b, sk["inverseBindMatrices"])[names.index(a.bone)].reshape(4, 4).T
    bind = np.linalg.inv(ibm)
    head, along = bind[:3, 3], bind[:3, 1] / np.linalg.norm(bind[:3, 1])
    bare = positions(a.bare)  # cùng phép đặt với place_prop (theo hộp bao của cung đã bỏ dây)
    lo, hi = bare.min(0), bare.max(0)
    k = a.size / (hi[1] - lo[1])
    grip = np.array([lo[0] + (hi[0] - lo[0]) * a.grip_depth, lo[1] + (hi[1] - lo[1]) * a.grip, (lo[2] + hi[2]) / 2])
    at = head + along * a.reach + np.array([float(v) for v in a.offset.split(",")])
    box = np.array([float(v) for v in a.box.split(",")]).reshape(2, 3)
    p = positions(a.bow)
    s = p[np.all((p >= box[0]) & (p <= box[1]), axis=1)]
    ends = [s[np.argmax(s[:, 1])], s[np.argmin(s[:, 1])]]
    tips = []
    for e in ends:
        w = rot([float(v) for v in a.rot.split(",")]) @ ((e - grip) * k) + at
        tips.append(np.round((ibm @ np.append(w, 1.0))[:3], 4).tolist())
    print(json.dumps({"bone": a.bone, "tips": tips}))


if __name__ == "__main__":
    main()
