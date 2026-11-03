#!/usr/bin/env python3
"""Chuẩn bị GLB có xương + nhiều hoạt ảnh (afk.ai, Mesh2Motion…) cho game (D-205).

  python3 -I tools/models/glb_anims.py vào.glb ra.glb --keep Idle=idle,Run=run,Bite=attack,Hit=hit,Death=death
      [--drop-bones REGEX]

- `A+B=tên`: nối hoạt ảnh A rồi B thành một (D-209, vd vung + thu tay của afk.ai); --join-gap: giây nội suy ở chỗ nối; `A@0.5`: chỉ lấy A tới 0,5 s; `A@1.05-2.4`: chỉ lấy đoạn đó; `A~`: giữ tại chỗ (bỏ dời của xương gốc, D-229).
- --drop-bones: bỏ xương có tên khớp REGEX (ngón tay…), trọng số dồn về xương cha (D-209).

- Chỉ giữ các hoạt ảnh trong --keep, đổi sang tên game (rig `Creature`: idle / run / attack / hit / death);
  bỏ accessor / dữ liệu của hoạt ảnh bị bỏ.
- Đỉnh trùng chỗ (tách ở đường may UV) lấy chung trọng số da — không thì da nứt khi cử động.
- Nâng mô hình cho điểm thấp nhất ở tư thế gốc chạm đất (y = 0).
Sau đó chạy glb_slim.py để thu ảnh màu.
"""
import argparse, json, os, struct, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_rig_ops as R  # noqa: E402

COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    off = 20 + n
    return json.loads(b[20:20 + n]), bytearray(b[off + 8:off + 8 + struct.unpack("<I", b[off:off + 4])[0]])


def array(g, binc, i):
    a = g["accessors"][i]
    bv = g["bufferViews"][a["bufferView"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    c = SIZE[a["type"]]
    dt = COMP[a["componentType"]]
    assert bv.get("byteStride", c * np.dtype(dt).itemsize) == c * np.dtype(dt).itemsize, "accessor xen kẽ"
    return np.frombuffer(binc, dt, a["count"] * c, o).reshape(a["count"], c)


def weld(g, binc):
    for mesh in g["meshes"]:
        for p in mesh["primitives"]:
            at = p["attributes"]
            if "JOINTS_0" not in at:
                continue
            pos, jo, we = (array(g, binc, at[k]) for k in ("POSITION", "JOINTS_0", "WEIGHTS_0"))
            spots = {}
            for v, xyz in enumerate(np.round(pos, 4)):
                spots.setdefault(tuple(xyz), []).append(v)
            jo_new, we_new = jo.copy(), we.astype(np.float64)
            for vs in spots.values():
                if len(vs) < 2:
                    continue
                acc = {}
                for v in vs:
                    for j, w in zip(jo[v], we[v]):
                        acc[int(j)] = acc.get(int(j), 0.0) + float(w)
                top = sorted(acc.items(), key=lambda kv: -kv[1])[:4] + [(0, 0.0)] * 4
                total = sum(w for _, w in top[:4]) or 1.0
                for v in vs:
                    jo_new[v] = [j for j, _ in top[:4]]
                    we_new[v] = [w / total for _, w in top[:4]]
            jo[:] = jo_new  # ghi thẳng vào buffer (cùng kiểu, cùng chỗ)
            we[:] = we_new.astype(we.dtype) if we.dtype == np.float32 else np.round(we_new * np.iinfo(we.dtype).max)


def lift(g, binc):
    low = min(float(array(g, binc, p["attributes"]["POSITION"])[:, 1].min())
              for m in g["meshes"] for p in m["primitives"])
    for n in g["scenes"][g.get("scene", 0)]["nodes"]:
        t = g["nodes"][n].setdefault("translation", [0.0, 0.0, 0.0])
        t[1] -= low
    return -low


def prune(g, binc):
    """Chỉ giữ accessor còn được dùng; dựng lại bufferViews (ảnh giữ nguyên)."""
    used = set()
    for m in g["meshes"]:
        for p in m["primitives"]:
            used.update(p["attributes"].values())
            if "indices" in p:
                used.add(p["indices"])
    for s in g.get("skins", []):
        if "inverseBindMatrices" in s:
            used.add(s["inverseBindMatrices"])
    for a in g.get("animations", []):
        for s in a["samplers"]:
            used.update((s["input"], s["output"]))
    views = sorted({g["accessors"][i]["bufferView"] for i in used} | {im["bufferView"] for im in g.get("images", [])})
    vmap, blob, new_views = {}, bytearray(), []
    for v in views:
        bv = dict(g["bufferViews"][v])
        data = binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        blob += b"\0" * (-len(blob) % 4)
        bv.update(buffer=0, byteOffset=len(blob))
        vmap[v] = len(new_views)
        new_views.append(bv)
        blob += data
    amap = {i: k for k, i in enumerate(sorted(used))}
    g["accessors"] = [dict(g["accessors"][i], bufferView=vmap[g["accessors"][i]["bufferView"]]) for i in sorted(used)]
    g["bufferViews"] = new_views
    for im in g.get("images", []):
        im["bufferView"] = vmap[im["bufferView"]]
    for m in g["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: amap[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = amap[p["indices"]]
    for s in g.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = amap[s["inverseBindMatrices"]]
    for a in g.get("animations", []):
        for s in a["samplers"]:
            s["input"], s["output"] = amap[s["input"]], amap[s["output"]]
    blob += b"\0" * (-len(blob) % 4)
    g["buffers"] = [{"byteLength": len(blob)}]
    return bytes(blob)


def write(path, g, blob):
    j = json.dumps(g, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 28 + len(j) + len(blob))
    out += struct.pack("<I", len(j)) + b"JSON" + j + struct.pack("<I", len(blob)) + b"BIN\0" + blob
    open(path, "wb").write(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--keep", required=True, help="Tên_gốc=tên_game,… (A+B=tên: nối)")
    ap.add_argument("--drop-bones", default="")
    ap.add_argument("--attach", action="append", default=[], help="vũ khí.glb:xương (D-231, gắn cứng vào xương)")
    ap.add_argument("--join-gap", type=float, default=R.FRAME, help="giây nội suy ở chỗ nối A+B")
    a = ap.parse_args()
    keep = dict(kv.split("=") for kv in a.keep.split(","))
    g, binc = read(a.src)
    have = {an.get("name") for an in g.get("animations", [])}
    missing = {n.split("@")[0].replace("~", "") for src in keep for n in src.split("+")} - have
    assert not missing, f"không có hoạt ảnh: {missing}; có: {sorted(have)}"
    special = {src: name for src, name in keep.items() if "+" in src or "@" in src or "~" in src}
    joined = [R.concat(g, binc, array, [n.replace("~", "") for n in src.split("+")], name, a.join_gap) for src, name in special.items()]
    for an, src in zip(joined, special):
        if "~" in src:
            R.in_place(g, binc, array, an)
    g["animations"] = [dict(an, name=keep[an["name"]]) for an in g["animations"] if an.get("name") in keep] + joined
    if a.drop_bones:
        print("xương: %d → %d" % R.drop_bones(g, binc, array, a.drop_bones))
    for spec in a.attach:
        path, bone = spec.rsplit(":", 1)
        print(f"gắn {os.path.basename(path)} vào {bone}: {R.attach_rigid(g, binc, array, path, bone, read)} đỉnh")
    weld(g, binc)
    up = lift(g, binc)
    blob = prune(g, binc)
    write(a.dst, g, blob)
    print(f"→ {a.dst}: {[an['name'] for an in g['animations']]}, nâng {up:.3f} m, {len(blob) / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
