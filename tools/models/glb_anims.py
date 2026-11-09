#!/usr/bin/env python3
"""Chuẩn bị GLB có xương + nhiều hoạt ảnh (afk.ai, Mesh2Motion…) cho game (D-205).

  python3 -I tools/models/glb_anims.py vào.glb ra.glb --keep Idle=idle,Run=run,Bite=attack,Hit=hit,Death=death
      [--drop-bones REGEX]

- `A+B=tên`: nối hoạt ảnh A rồi B thành một (D-209, vd vung + thu tay của afk.ai); --join-gap: giây nội suy ở chỗ nối; `A@0.5`: chỉ lấy A tới 0,5 s; `A@1.05-2.4`: chỉ lấy đoạn đó; `A~`: giữ tại chỗ (bỏ dời của xương gốc, D-229);
  `A^`: soi gương trái ↔ phải, `A%`: nửa trái làm theo nửa phải (D-323, glb_mirror.py).
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
import glb_mirror as M  # noqa: E402

COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    off = 20 + n
    g, binc = json.loads(b[20:20 + n]), bytearray(b[off + 8:off + 8 + struct.unpack("<I", b[off:off + 4])[0]])
    _untangle(g, binc)
    return g, binc


def _untangle(g, binc):
    """afk-rig ≥ 1.3 ghi thuộc tính đỉnh xen kẽ (byteStride) → chép mỗi accessor ra vùng liền để array() trả view."""
    for a in g.get("accessors", []):
        bv = g["bufferViews"][a["bufferView"]] if "bufferView" in a else None
        if bv is None:
            continue
        c, dt = SIZE[a["type"]], np.dtype(COMP[a["componentType"]])
        stride = bv.get("byteStride", c * dt.itemsize)
        if stride == c * dt.itemsize:
            continue
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        rows = np.frombuffer(bytes(binc[start:start + stride * (a["count"] - 1) + c * dt.itemsize]) + bytes(stride),
                             np.uint8, a["count"] * stride).reshape(a["count"], stride)[:, :c * dt.itemsize]
        binc += b"\0" * (-len(binc) % 4)
        g["bufferViews"].append({"buffer": 0, "byteOffset": len(binc), "byteLength": rows.size})
        binc += rows.tobytes()
        a["bufferView"] = len(g["bufferViews"]) - 1
        a.pop("byteOffset", None)


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
    blob, new_views, vmap = bytearray(), [], {}

    def put(data, extra):
        nonlocal blob
        blob += b"\0" * (-len(blob) % 4)
        new_views.append(dict(extra, buffer=0, byteOffset=len(blob), byteLength=len(data)))
        blob += data
        return len(new_views) - 1
    accs = []
    for i in sorted(used):  # mỗi accessor một vùng riêng, chỉ đúng phần dùng (afk-rig 1.3 gom mọi hoạt ảnh vào một vùng)
        a = dict(g["accessors"][i])
        bv = g["bufferViews"][a["bufferView"]]
        start = bv.get("byteOffset", 0) + a.pop("byteOffset", 0)
        size = a["count"] * SIZE[a["type"]] * np.dtype(COMP[a["componentType"]]).itemsize
        extra = {"target": bv["target"]} if "target" in bv else {}
        a["bufferView"] = put(bytes(binc[start:start + size]), extra)
        accs.append(a)
    for im in g.get("images", []):
        v = im["bufferView"]
        if v not in vmap:
            bv = g["bufferViews"][v]
            vmap[v] = put(bytes(binc[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]), {})
        im["bufferView"] = vmap[v]
    amap = {i: k for k, i in enumerate(sorted(used))}
    g["accessors"] = accs
    g["bufferViews"] = new_views
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


def _bare(n):
    return n.replace("~", "").replace("^", "").replace("%", "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--keep", required=True, help="Tên_gốc=tên_game,… (A+B=tên: nối)")
    ap.add_argument("--drop-bones", default="")
    ap.add_argument("--attach", action="append", default=[], help="vũ khí.glb:xương (D-231, gắn cứng vào xương)")
    ap.add_argument("--join-gap", type=float, default=R.FRAME, help="giây nội suy ở chỗ nối A+B")
    a = ap.parse_args()
    pairs = [kv.split("=") for kv in a.keep.split(",")]
    assert len({src for src, _ in pairs}) == len(pairs), "trùng tên nguồn trong --keep (cái sau đè cái trước); dùng tên@0-dài"
    keep = dict(pairs)
    g, binc = read(a.src)
    have = {an.get("name") for an in g.get("animations", [])}
    missing = {_bare(n).split("@")[0] for src in keep for n in src.split("+")} - have
    assert not missing, f"không có hoạt ảnh: {missing}; có: {sorted(have)}"
    R.bake_root(g, binc, array)  # D-238: gốc FBX (Mixamo) xoay / tỉ lệ 0,01 → đơn vị
    special = {src: name for src, name in keep.items() if any(ch in src for ch in "+@~^%")}
    joined = [R.concat(g, binc, array, [_bare(n) for n in src.split("+")], name, a.join_gap) for src, name in special.items()]
    for an, src in zip(joined, special):
        if "~" in src:
            R.in_place(g, binc, array, an)
        if "^" in src or "%" in src:
            M.mirror(g, binc, array, an, "full" if "^" in src else "sym")
    g["animations"] = [dict(an, name=keep[an["name"]]) for an in g["animations"] if an.get("name") in keep] + joined
    if a.drop_bones:
        print("xương: %d → %d" % R.drop_bones(g, binc, array, a.drop_bones))
    for spec in a.attach:
        path, bone = spec.split(".glb:", 1)  # tên xương Mixamo có dấu ":" (mixamorig:RightHand)
        path += ".glb"
        print(f"gắn {os.path.basename(path)} vào {bone}: {R.attach_rigid(g, binc, array, path, bone, read)} đỉnh")
    weld(g, binc)
    up = lift(g, binc)
    blob = prune(g, binc)
    write(a.dst, g, blob)
    print(f"→ {a.dst}: {[an['name'] for an in g['animations']]}, nâng {up:.3f} m, {len(blob) / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
