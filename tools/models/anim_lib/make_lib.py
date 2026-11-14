#!/usr/bin/env python3
"""Dựng file kho hoạt ảnh từ một GLB afk.ai: bỏ lưới, vật liệu, ảnh; giữ bộ xương (skin) + hoạt ảnh (D-398).

  python3 -I tools/models/anim_lib/make_lib.py tướng_afk.glb kho.glb [--only REGEX] [--skip REGEX] [--prefix "MX "]

--only / --skip: lọc hoạt ảnh theo tên (vd tách kho theo nhóm: `--only '^(Sword|Shield)'`).
--prefix: đổi tên hoạt ảnh khi đưa vào kho (vd `MX ` cho hoạt ảnh Mixamo đã chuyển sang xương afk bằng retarget.py).
Kho không vào game: apply_anims.py lấy từ kho ghép vào GLB tướng.
"""
import argparse, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import glb_anims as GA  # noqa: E402


def strip_meshes(g):
    for n in g["nodes"]:
        n.pop("mesh", None)
    for key in ("meshes", "materials", "textures", "images", "samplers"):
        g.pop(key, None)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--only", default=""); ap.add_argument("--skip", default=""); ap.add_argument("--prefix", default="")
    a = ap.parse_args()
    g, binc = GA.read(a.src)
    anims = g.get("animations", [])
    if a.only:
        anims = [an for an in anims if re.search(a.only, an.get("name", ""))]
    if a.skip:
        anims = [an for an in anims if not re.search(a.skip, an.get("name", ""))]
    g["animations"] = [dict(an, name=a.prefix + an["name"]) for an in anims]
    strip_meshes(g)
    g["meshes"] = []  # GA.prune duyệt meshes
    blob = GA.prune(g, binc)
    g.pop("meshes")
    GA.write(a.dst, g, blob)
    print(f"→ {a.dst}: {len(g['animations'])} hoạt ảnh, {os.path.getsize(a.dst) / 1e6:.2f} MB")


if __name__ == "__main__":
    main()
