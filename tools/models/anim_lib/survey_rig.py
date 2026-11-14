#!/usr/bin/env python3
"""Khảo sát bộ xương afk.ai của nhiều GLB (D-398): tên xương, cây cha–con, xoay nghỉ, độ dài, chiều cao hông.

  python3 -I tools/models/anim_lib/survey_rig.py a_afk.glb b_afk.glb … [--ref a_afk.glb]

So với file --ref (mặc định file đầu): xương thiếu / thừa, cha khác, góc lệch xoay nghỉ (độ), tỉ lệ độ dài.
"""
import argparse, json, os, struct, sys
import numpy as np


def read_json(path):
    with open(path, "rb") as f:
        head = f.read(20)
        n = struct.unpack("<I", head[12:16])[0]
        return json.loads(f.read(n))


def qmul(a, b):
    x1, y1, z1, w1 = a; x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def qrot(q, v):
    u = np.array(q[:3]); w = q[3]
    return 2 * np.dot(u, v) * u + (w * w - np.dot(u, u)) * np.array(v) + 2 * w * np.cross(u, v)


def rig(path):
    g = read_json(path)
    nodes = g["nodes"]
    joints = g["skins"][0]["joints"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    name = {i: nodes[i].get("name", str(i)) for i in range(len(nodes))}
    world = {}

    def wt(i):
        if i in world:
            return world[i]
        n = nodes[i]
        t = np.array(n.get("translation", [0, 0, 0]), float); r = np.array(n.get("rotation", [0, 0, 0, 1]), float)
        s = np.array(n.get("scale", [1, 1, 1]), float)
        if i in parent:
            pt, pr, ps = wt(parent[i])
            world[i] = (pt + qrot(pr, ps * t), qmul(pr, r), ps * s)
        else:
            world[i] = (t, r, s)
        return world[i]
    out = {}
    for j in joints:
        n = nodes[j]
        out[name[j]] = dict(parent=name.get(parent.get(j)), rot=np.array(n.get("rotation", [0, 0, 0, 1]), float),
                            length=float(np.linalg.norm(n.get("translation", [0, 0, 0]))), pos=wt(j)[0],
                            wrot=wt(j)[1])
    anims = [a.get("name") for a in g.get("animations", [])]
    tr = sorted({name[c["target"]["node"]] for a in g.get("animations", [])[:50] for c in a["channels"]
                 if c["target"]["path"] == "translation"})
    sc = sorted({name[c["target"]["node"]] for a in g.get("animations", [])[:50] for c in a["channels"]
                 if c["target"]["path"] == "scale"})
    return out, anims, tr, sc


def angle(a, b):
    d = abs(float(np.dot(a / np.linalg.norm(a), b / np.linalg.norm(b))))
    return np.degrees(2 * np.arccos(min(1.0, d)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+"); ap.add_argument("--ref")
    a = ap.parse_args()
    ref_path = a.ref or a.files[0]
    ref, _, _, _ = rig(ref_path)
    for p in a.files:
        r, anims, tr, sc = rig(p)
        hip = next((k for k in ("pelvis", "hips", "Hips") if k in r), None)
        hy = r[hip]["pos"][1] if hip else float("nan")
        top = max(v["pos"][1] for v in r.values())
        print(f"== {os.path.relpath(p)}: {len(r)} xương, {len(anims)} hoạt ảnh, hông '{hip}' cao {hy:.3f}, "
              f"xương cao nhất {top:.3f}")
        print(f"   track dời (50 hoạt ảnh đầu): {tr}; track co giãn: {sc}")
        miss, extra = sorted(set(ref) - set(r)), sorted(set(r) - set(ref))
        if miss or extra:
            print(f"   thiếu so với ref: {miss}\n   thừa: {extra}")
        par = [k for k in r if k in ref and r[k]["parent"] != ref[k]["parent"]]
        if par:
            print(f"   cha khác: {par}")
        common = [k for k in r if k in ref]
        rot_d = sorted(((angle(r[k]["rot"], ref[k]["rot"]), k) for k in common), reverse=True)
        wrot_d = sorted(((angle(r[k]["wrot"], ref[k]["wrot"]), k) for k in common), reverse=True)
        print("   lệch xoay nghỉ cục bộ lớn nhất (độ): " + ", ".join(f"{k} {d:.2f}" for d, k in rot_d[:5]))
        print("   lệch xoay nghỉ thế giới lớn nhất (độ): " + ", ".join(f"{k} {d:.2f}" for d, k in wrot_d[:5]))
        ratios = np.array([r[k]["length"] / ref[k]["length"] for k in common if ref[k]["length"] > 1e-4])
        print(f"   tỉ lệ độ dài xương / ref: min {ratios.min():.3f} max {ratios.max():.3f} "
              f"trung vị {np.median(ratios):.3f}")
        for k in ("thigh_l", "calf_l", "upperarm_l", "lowerarm_l", "spine_01", "neck_01"):
            if k in r and k in ref:
                print(f"     {k}: {r[k]['length']:.3f} (ref {ref[k]['length']:.3f})")


if __name__ == "__main__":
    main()
