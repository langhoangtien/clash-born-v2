#!/usr/bin/env python3
"""D-373: đặt cung vào nắm tay theo MỘT khung của hoạt ảnh bắn (Mixamo Longbow…): ở khung đó cung dựng đứng, mặt
phẳng cung chứa hướng ngắm (từ tay kéo sang tay cầm cung), dây quay về phía người bắn, giữa cung nằm trong nắm tay.
Ra lưới cung trong không gian bind của thân (dùng `glb_anims.py --attach cung.glb:xương`) + `bow_string.tips` trong hệ
xương cầm cung (units_3d.json, D-349) — tính từ hai đầu dây cũ của lưới cung Tripo.

  python3 -I tools/models/bow_grip.py thân.glb cung_đủ_dây.glb cung_bỏ_dây.glb ra.glb --anim "standing aim overdraw"
        --time 2.0 --string-axis +z [--hold LeftHand --pull RightHand --size 0.62 --reach 0.035]
`--string-axis`: phía dây trong lưới cung gốc (cung đứng theo y). `--size`, `--reach` (từ cổ tay vào giữa nắm, dọc xương):
theo chiều cao thân.
"""
import argparse, json, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as A  # noqa: E402
from retarget import Rig  # noqa: E402

AXES = {"+x": 0, "-x": 0, "+z": 2, "-z": 2}


def positions(path):
    g, b = A.read(path)
    return g, b, A.array(g, b, g["meshes"][0]["primitives"][0]["attributes"]["POSITION"])


def frame(rig, a):
    """(M: bind → thế giới của xương cầm ở khung, tâm nắm tay, hướng ngắm, trục lên) — thế giới = cảnh glTF."""
    ch, _ = rig.sampler(a.anim)
    w = rig.world(ch, a.time)
    hold, pull = rig.index[a.hold], rig.index[a.pull]
    M = w(hold) @ rig.ibm[hold]
    wrist, tip = w(hold)[:3, 3], w(hold)[:3, :3] @ np.array([0.0, 1.0, 0.0])
    aim = wrist - w(pull)[:3, 3]
    up = np.array([0.0, 1.0, 0.0])
    aim -= up * aim.dot(up)
    return M, wrist, tip / np.linalg.norm(tip), aim / np.linalg.norm(aim), up


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("body"); ap.add_argument("bow"); ap.add_argument("bare"); ap.add_argument("dst")
    ap.add_argument("--anim", required=True); ap.add_argument("--time", type=float, required=True)
    ap.add_argument("--string-axis", default="+z", choices=list(AXES))
    ap.add_argument("--hold", default="LeftHand"); ap.add_argument("--pull", default="RightHand")
    ap.add_argument("--size", type=float, default=0.62); ap.add_argument("--reach", type=float, default=0.035)
    a = ap.parse_args()
    rig = Rig(a.body)
    _, _, body = positions(a.body)
    tall = float(np.ptp(body[:, 1]))
    M, wrist, along, aim, up = frame(rig, a)
    s = abs(np.linalg.det(M[:3, :3])) ** (1 / 3)
    g, b, bare = positions(a.bare)
    lo, hi = bare.min(0), bare.max(0)
    center = (lo + hi) / 2
    k = a.size * tall * s / (hi[1] - lo[1])
    ax = AXES[a.string_axis]
    sign = 1.0 if a.string_axis[0] == "+" else -1.0
    # cơ sở cung gốc → thế giới: y → lên, phía dây → về người bắn (−aim), trục còn lại theo quy tắc tay phải
    cols = {1: up, ax: -aim * sign}
    other = 2 if ax == 0 else 0
    cols[other] = np.cross(cols[(other + 1) % 3], cols[(other + 2) % 3])
    R = np.stack([cols[0], cols[1], cols[2]], axis=1)
    grip = wrist + along * a.reach * tall * s
    to_bind = np.linalg.inv(M)

    def place(p):
        world = (R @ ((p - center) * k).T).T + grip
        return (to_bind[:3, :3] @ world.T).T + to_bind[:3, 3]
    out = place(bare.astype(np.float64))
    pos = A.array(g, b, g["meshes"][0]["primitives"][0]["attributes"]["POSITION"])
    pos[:] = out.astype(np.float32)
    p = g["meshes"][0]["primitives"][0]
    if "NORMAL" in p["attributes"]:
        nrm = A.array(g, b, p["attributes"]["NORMAL"])
        rot = to_bind[:3, :3] @ R
        rot /= np.cbrt(abs(np.linalg.det(rot)))
        nrm[:] = (rot @ nrm.T.astype(np.float64)).T.astype(np.float32)
    acc = g["accessors"][p["attributes"]["POSITION"]]
    acc["min"], acc["max"] = out.min(0).tolist(), out.max(0).tolist()
    for n in g["nodes"]:
        for key in ("translation", "rotation", "scale", "matrix"):
            n.pop(key, None)
    A.write(a.dst, g, A.prune(g, b))
    _, _, full = positions(a.bow)
    string = full[(full[:, ax] - center[ax]) * sign > (hi[ax] - center[ax]) * 0.55]
    ends = [string[np.argmax(string[:, 1])], string[np.argmin(string[:, 1])]]
    hold = rig.index[a.hold]
    tips = [np.round((rig.ibm[hold] @ np.append(place(e[None].astype(np.float64))[0], 1.0))[:3], 4).tolist() for e in ends]
    print(json.dumps({"bone": rig.g["nodes"][hold]["name"].replace(":", "_"),
                      "pull_bone": rig.g["nodes"][rig.index[a.pull]]["name"].replace(":", "_"), "tips": tips}))


if __name__ == "__main__":
    main()
