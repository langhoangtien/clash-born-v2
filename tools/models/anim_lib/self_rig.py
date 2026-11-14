#!/usr/bin/env python3
"""Tự gắn xương afk cho lưới Tripo, không gọi afk.ai (D-399).

  python3 -I tools/models/anim_lib/self_rig.py mẫu_afk.glb tên_front.glb ra_tự_gắn.glb

1. fit_skeleton: ướm 66 xương của tướng mẫu vào lưới (mốc hình học), xoay nghỉ theo quy ước afk.
2. heat_weights: trọng số da kiểu bone heat (numpy), 4 xương / đỉnh.
3. Ghi GLB: đỉnh / pháp tuyến đã áp xoay của nút Tripo, thêm cây xương + skin như file afk (cùng tên nút, cùng thứ tự
   khớp với mẫu) → dùng được với apply_anims.py / glb_anims.py như bản afk.
"""
import argparse, os, sys, time
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as GA  # noqa: E402
import glb_rig_ops as R  # noqa: E402
import rig_math as RM  # noqa: E402
import mesh_slices as MS  # noqa: E402
import fit_skeleton as FS  # noqa: E402
import heat_weights as HW  # noqa: E402

NO_SKIN = {"afk-human", "Armature", "root"}
TRUNK = {"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01",
         "neck_01": "head", "head": "head_leaf"}


def deform_bones(ts, pos):
    """(chỉ số khớp trong skin mẫu, đoạn xương) cho xương có trọng số: bỏ nút gốc và xương mút `_leaf`."""
    joints = [ts.name[ts.index[j]] for j in ts.g["skins"][0]["joints"]]
    out = []
    for k, name in enumerate(joints):
        if name in NO_SKIN or "leaf" in name:
            continue
        end = TRUNK.get(name) or FS.chain_child(name)
        if end not in pos:
            continue
        out.append((k, (pos[name], pos[end])))
    return joints, out


def bake_node(g, b):
    """Tripo `_front.glb` để xoay trên nút lưới → áp vào đỉnh / pháp tuyến, bỏ xoay nút (afk cũng làm vậy)."""
    for n in g["nodes"]:
        if "mesh" not in n or "rotation" not in n:
            continue
        q = np.array(n.pop("rotation"), float)
        for p in g["meshes"][n["mesh"]]["primitives"]:
            for key in ("POSITION", "NORMAL"):
                if key in p["attributes"]:
                    arr = np.array(GA.array(g, b, p["attributes"][key]), float)
                    p["attributes"][key] = R.add_accessor(g, b, RM.qrot(q[None], arr), "VEC3", key == "POSITION")
    for a in g["accessors"]:  # POSITION mới cần min / max đủ 3 trục
        if a.get("type") == "VEC3" and "min" in a and len(a["min"]) == 1:
            arr = np.frombuffer(b, np.float32, a["count"] * 3,
                                g["bufferViews"][a["bufferView"]]["byteOffset"]).reshape(-1, 3)
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()


def add_skeleton(g, b, ts, pos, rot, joints):
    base = len(g["nodes"])
    order = {name: base + k for k, name in enumerate(ts.name)}
    for k, name in enumerate(ts.name):
        p = ts.parent[k]
        pp, pr = (pos[ts.name[p]], rot[ts.name[p]]) if p >= 0 else (np.zeros(3), np.array([0, 0, 0, 1.0]))
        t = RM.qrot(RM.qinv(pr), pos[name] - pp)
        r = RM.qnorm(RM.qmul(RM.qinv(pr), rot[name]))
        kids = [order[ts.name[c]] for c in range(len(ts.name)) if ts.parent[c] == k]
        node = {"name": name, "translation": t.tolist(), "rotation": r.tolist()}
        if kids:
            node["children"] = kids
        g["nodes"].append(node)
    ibm = []
    for name in joints:
        m = np.eye(4)
        x, y, z, w = rot[name]
        m[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
        m[:3, 3] = pos[name]
        ibm.append(np.linalg.inv(m).T.reshape(-1))  # glTF: cột trước
    g.setdefault("skins", []).append({"joints": [order[n] for n in joints], "skeleton": order["root"],
                                      "inverseBindMatrices": R.add_accessor(g, b, np.array(ibm), "MAT4")})
    scene = g["scenes"][g.get("scene", 0)]["nodes"]
    scene.append(order[ts.name[0]])
    return len(g["skins"]) - 1


def add_weights(g, b, skin, bones):
    for n in g["nodes"]:
        if "mesh" not in n:
            continue
        n["skin"] = skin
        for p in g["meshes"][n["mesh"]]["primitives"]:
            v = np.array(GA.array(g, b, p["attributes"]["POSITION"]), float)
            t = np.array(GA.array(g, b, p["indices"]), np.int64).reshape(-1, 3)
            wv, wt, inv = MS.weld(v, t)
            idx, w = HW.heat(wv, wt, [s for _, s in bones])
            jid = np.array([k for k, _ in bones])[idx][inv]
            p["attributes"]["JOINTS_0"] = _raw(g, b, jid.astype(np.uint16), 5123)
            p["attributes"]["WEIGHTS_0"] = R.add_accessor(g, b, w[inv], "VEC4")


def _raw(g, b, arr, comp):
    b += b"\0" * (-len(b) % 4)
    g["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": arr.nbytes})
    b += arr.tobytes()
    g["accessors"].append({"bufferView": len(g["bufferViews"]) - 1, "componentType": comp, "count": len(arr),
                           "type": "VEC4"})
    return len(g["accessors"]) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("template"); ap.add_argument("mesh"); ap.add_argument("out")
    a = ap.parse_args()
    t0 = time.time()
    ts, pos, rot = FS.fit(a.template, a.mesh)
    t1 = time.time()
    g, b = GA.read(a.mesh)
    bake_node(g, b)
    joints, bones = deform_bones(ts, pos)
    skin = add_skeleton(g, b, ts, pos, rot, joints)
    add_weights(g, b, skin, bones)
    t2 = time.time()
    blob = GA.prune(g, b)
    GA.write(a.out, g, blob)
    print(f"→ {a.out}: {len(joints)} khớp, {len(bones)} xương có trọng số; ướm xương {t1 - t0:.1f} s, "
          f"trọng số {t2 - t1:.1f} s, tổng {time.time() - t0:.1f} s")


if __name__ == "__main__":
    main()
