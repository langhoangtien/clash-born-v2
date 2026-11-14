#!/usr/bin/env python3
"""Lấy hoạt ảnh từ kho afk.ai (GLB nguồn có xương afk) ghép vào GLB tướng đích có xương afk khác cỡ (D-398).

  python3 -I tools/models/anim_lib/apply_anims.py kho.glb tướng_afk.glb ra.glb --anims Idle_A,Run,… \
      [--prefix "LIB "] [--keep-own Idle_A,Run] [--own-prefix "AFK "] [--method copy|world] [--scale-moves]

Khảo sát D-398: afk.ai trả cho mọi tướng CÙNG một bộ track xoay cục bộ (lệch trung bình < 2°; chỉ tay bị bước
"giữ tay khỏi thân" của afk-rig chỉnh riêng), track dời có ở `root` và `pelvis`, và dời hông chỉ lệch đúng bằng
chênh lệch vị trí nghỉ (không co giãn). Vì vậy mặc định `copy`: chép nguyên track xoay theo tên xương, track dời
= track nguồn + (nghỉ đích − nghỉ nguồn). `--scale-moves`: nhân phần dời quanh tư thế nghỉ với tỉ lệ chiều cao hông.
`world`: chuyển theo độ lệch xoay thế giới (rig_math.retarget) — chỉ để so sánh, lệch xa hơn so với afk.

Chỉ đọc JSON + phần nhị phân của các hoạt ảnh được chọn; không bao giờ nạp cả 593 hoạt ảnh vào Godot.
--keep-own: giữ thêm hoạt ảnh afk gốc của chính tướng đích (đổi tên với --own-prefix) để quay so sánh.
"""
import argparse, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as GA  # noqa: E402  (đọc / ghi / dọn GLB — dùng lại, không sửa)
import glb_rig_ops as R  # noqa: E402
import rig_math as RM  # noqa: E402


def names_of(g):
    return {n.get("name"): i for i, n in enumerate(g["nodes"])}


def copy_anim(sg, sb, dg, db, anim, new_name, scale_moves=False):
    """Chép một hoạt ảnh nguồn sang đích theo tên xương (cách afk.ai)."""
    s_nodes, d_by = sg["nodes"], names_of(dg)
    ss, ds = RM.Skeleton(sg), RM.Skeleton(dg)
    k = RM.hip_height(ds) / RM.hip_height(ss) if scale_moves else 1.0
    samplers, channels, cache = [], [], {}
    for c in anim["channels"]:
        name = s_nodes[c["target"]["node"]].get("name")
        if name not in d_by:
            continue
        smp = anim["samplers"][c["sampler"]]
        path = c["target"]["path"]
        if smp["input"] not in cache:
            cache[smp["input"]] = R.add_accessor(dg, db, GA.array(sg, sb, smp["input"]), "SCALAR", True)
        out = np.array(GA.array(sg, sb, smp["output"]), np.float64)
        if path == "translation":
            rest_s = np.array(s_nodes[c["target"]["node"]].get("translation", [0, 0, 0]), float)
            rest_d = np.array(dg["nodes"][d_by[name]].get("translation", [0, 0, 0]), float)
            out = rest_d + (out - rest_s) * k
        kind = {"rotation": "VEC4", "translation": "VEC3", "scale": "VEC3"}[path]
        samplers.append({"input": cache[smp["input"]], "output": R.add_accessor(dg, db, out, kind),
                         "interpolation": smp.get("interpolation", "LINEAR")})
        channels.append({"sampler": len(samplers) - 1, "target": {"node": d_by[name], "path": path}})
    return {"name": new_name, "samplers": samplers, "channels": channels}


def world_anim(sg, sb, dg, db, anim, new_name, scale_moves=False):
    """Chuyển theo độ lệch xoay thế giới (để so sánh với copy)."""
    ss, ds = RM.Skeleton(sg), RM.Skeleton(dg)
    times, t, r = RM.sample(sg, lambda i: GA.array(sg, sb, i), anim, ss)
    out_t, out_r, _ = RM.retarget(ss, ds, t, r, scale=None if scale_moves else 1.0)
    ti = R.add_accessor(dg, db, times, "SCALAR", True)
    samplers, channels = [], []
    for k, node in enumerate(ds.order):
        if ds.name[k] not in ss.by_name or node not in dg["skins"][0]["joints"]:
            continue
        for path, arr, kind in (("rotation", out_r[:, k], "VEC4"), ("translation", out_t[:, k], "VEC3")):
            if path == "translation" and ds.name[k] not in ("root", "pelvis"):
                continue
            samplers.append({"input": ti, "output": R.add_accessor(dg, db, arr, kind), "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": path}})
    return {"name": new_name, "samplers": samplers, "channels": channels}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lib"); ap.add_argument("dst"); ap.add_argument("out")
    ap.add_argument("--anims", required=True, help="tên hoạt ảnh trong kho, cách nhau dấu phẩy")
    ap.add_argument("--prefix", default="")
    ap.add_argument("--keep-own", default="", help="hoạt ảnh afk gốc của tướng đích giữ lại để so")
    ap.add_argument("--own-prefix", default="AFK ")
    ap.add_argument("--method", choices=("copy", "world"), default="copy")
    ap.add_argument("--scale-moves", action="store_true")
    a = ap.parse_args()
    sg, sb = GA.read(a.lib)
    dg, db = GA.read(a.dst)
    lib = {an.get("name"): an for an in sg.get("animations", [])}
    want = [n for n in a.anims.split(",") if n]
    missing = [n for n in want if n not in lib]
    assert not missing, f"kho không có: {missing}"
    own_names = [n for n in a.keep_own.split(",") if n]
    own = [dict(an, name=a.own_prefix + an["name"]) for an in dg.get("animations", []) if an.get("name") in own_names]
    make = copy_anim if a.method == "copy" else world_anim
    new = [make(sg, sb, dg, db, lib[n], a.prefix + n, a.scale_moves) for n in want]
    dg["animations"] = own + new
    GA.weld(dg, db)
    up = GA.lift(dg, db)
    blob = GA.prune(dg, db)
    GA.write(a.out, dg, blob)
    print(f"→ {a.out}: {len(new)} từ kho ({a.method}), {len(own)} gốc; nâng {up:.3f}; {len(blob) / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
