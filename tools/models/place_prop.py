#!/usr/bin/env python3
"""Đặt vũ khí / khiên Tripo dựng riêng vào nắm tay của thân đã gắn xương (D-235): ra GLB cùng hệ tọa độ lưới thân, để
`glb_anims.py --attach ra.glb:xương` gắn cứng vào xương bàn tay (vật cứng, không da → không bao giờ cong).

  python3 -I tools/models/place_prop.py thân_afk.glb vật.glb ra.glb --bone hand_r --size 0.42 --grip 0.12
        [--rot 90,0,0] [--reach 0.045] [--offset 0,0,0]
Vật Tripo: đứng thẳng (trục y), mặt trước +X. `--size`: chiều cao vật trong hệ thân (m); `--grip`: chỗ nắm theo trục y
(phần từ đáy lên, 0..1; với khiên là tâm quai — cùng `--grip-depth` để lấy mặt sau); `--rot`: xoay (độ, quanh X, Y, Z
theo thứ tự) sau khi đưa chỗ nắm về gốc; điểm đặt = đầu xương + `--reach` dọc xương (vào giữa nắm tay) + `--offset`.
"""
import argparse, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as A  # noqa: E402


def rot(deg):
    rx, ry, rz = np.radians(deg)
    X = np.array([[1, 0, 0], [0, np.cos(rx), -np.sin(rx)], [0, np.sin(rx), np.cos(rx)]])
    Y = np.array([[np.cos(ry), 0, np.sin(ry)], [0, 1, 0], [-np.sin(ry), 0, np.cos(ry)]])
    Z = np.array([[np.cos(rz), -np.sin(rz), 0], [np.sin(rz), np.cos(rz), 0], [0, 0, 1]])
    return Z @ Y @ X


def bone_frame(path, bone):
    g, b = A.read(path)
    sk = g["skins"][0]
    names = [g["nodes"][j]["name"] for j in sk["joints"]]
    m = np.linalg.inv(A.array(g, b, sk["inverseBindMatrices"])[names.index(bone)].reshape(4, 4).T)
    return m[:3, 3], m[:3, 1] / np.linalg.norm(m[:3, 1])  # đầu xương, hướng dọc xương (trục y)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("body"); ap.add_argument("prop"); ap.add_argument("dst")
    ap.add_argument("--bone", required=True)
    ap.add_argument("--size", type=float, required=True)
    ap.add_argument("--grip", type=float, default=0.5)
    ap.add_argument("--grip-depth", type=float, default=0.5, help="chỗ nắm theo trục x (0 = mặt sau, 1 = mặt trước)")
    ap.add_argument("--rot", default="0,0,0")
    ap.add_argument("--reach", type=float, default=0.045)
    ap.add_argument("--offset", default="0,0,0")
    a = ap.parse_args()
    head, along = bone_frame(a.body, a.bone)
    g, b = A.read(a.prop)
    p = g["meshes"][0]["primitives"][0]
    pos = A.array(g, b, p["attributes"]["POSITION"]).astype(np.float64)
    lo, hi = pos.min(0), pos.max(0)
    k = a.size / (hi[1] - lo[1])
    grip = np.array([lo[0] + (hi[0] - lo[0]) * a.grip_depth, lo[1] + (hi[1] - lo[1]) * a.grip, (lo[2] + hi[2]) / 2])
    R = rot([float(v) for v in a.rot.split(",")])
    at = head + along * a.reach + np.array([float(v) for v in a.offset.split(",")])
    new = (R @ ((pos - grip) * k).T).T + at
    A.array(g, b, p["attributes"]["POSITION"])[:] = new.astype(np.float32)
    if "NORMAL" in p["attributes"]:
        nrm = A.array(g, b, p["attributes"]["NORMAL"])
        nrm[:] = (R @ nrm.T.astype(np.float64)).T.astype(np.float32)
    acc = g["accessors"][p["attributes"]["POSITION"]]
    acc["min"], acc["max"] = new.min(0).tolist(), new.max(0).tolist()
    for n in g["nodes"]:  # Tripo: nút không xoay; bỏ mọi biến đổi nút cho chắc
        for key in ("translation", "rotation", "scale", "matrix"):
            n.pop(key, None)
    A.write(a.dst, g, A.prune(g, b))
    print(f"→ {a.dst}: cao {a.size} m, nắm tại {np.round(at, 3)}")


if __name__ == "__main__":
    main()
