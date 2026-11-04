#!/usr/bin/env python3
"""Đổi chất liệu vật dựng (D-243): điểm ảnh màu có sắc độ trong `--hue` (độ, vd vàng đồng 20-60) thành thép bạc ánh
lạnh như lưỡi kiếm (giữ sáng tối của ảnh gốc), phần khác (đá xanh…) giữ nguyên. Ghi GLB mới, bớt nhám cho có ánh.

  python3 -I tools/models/recolor_prop.py vào.glb ra.glb [--hue 20-60] [--roughness 0.55]
"""
import argparse, io, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as A  # noqa: E402

STEEL_DARK = np.array([120, 128, 140], np.float32)  # thép trong bóng
STEEL_LIGHT = np.array([232, 236, 242], np.float32)  # thép chỗ sáng (như lưỡi kiếm)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--hue", default="20-60")
    ap.add_argument("--roughness", type=float, default=0.55)
    a = ap.parse_args()
    lo, hi = (float(v) for v in a.hue.split("-"))
    g, b = A.read(a.src)
    for im in g["images"]:
        bv = g["bufferViews"][im["bufferView"]]
        start = bv.get("byteOffset", 0)
        img = Image.open(io.BytesIO(bytes(b[start:start + bv["byteLength"]]))).convert("RGB")
        hsv = np.asarray(img.convert("HSV"), np.float32)
        rgb = np.asarray(img, np.float32)
        hue = hsv[..., 0] * 360.0 / 255.0
        sel = (hue >= lo) & (hue <= hi) & (hsv[..., 1] > 50)
        lum = (rgb @ np.array([0.299, 0.587, 0.114], np.float32)) / 255.0
        k = np.clip((lum - 0.25) / 0.6, 0, 1)[..., None]
        steel = STEEL_DARK + (STEEL_LIGHT - STEEL_DARK) * k
        rgb[sel] = steel[sel]
        out = io.BytesIO()
        Image.fromarray(rgb.astype(np.uint8)).save(out, "JPEG", quality=92)
        data = out.getvalue()
        b += b"\0" * (-len(b) % 4)
        g["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(data)})
        b += data
        im["bufferView"] = len(g["bufferViews"]) - 1
        im["mimeType"] = "image/jpeg"
        print(f"{int(sel.mean() * 100)}% điểm ảnh → thép")
    for m in g.get("materials", []):
        m.setdefault("pbrMetallicRoughness", {})["roughnessFactor"] = a.roughness
    A.write(a.dst, g, A.prune(g, b))
    print("→", a.dst)


if __name__ == "__main__":
    main()
