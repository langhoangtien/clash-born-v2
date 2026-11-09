#!/usr/bin/env python3
"""D-312: sao một mô hình tô màu đỉnh (bộ style_kit) sang màu khác — giữ sáng tối từng đỉnh, đổi sắc độ về màu `--to`
(vd khóm lá cam → khóm dương xỉ xanh ven đường, như ảnh mẫu lane). Chỉ đổi dữ liệu COLOR_0 (ushort chuẩn hóa).

  python3 -I tools/models/recolor_vc.py vào.glb ra.glb --to 6f8a3c
"""
import argparse, json, struct
import numpy as np

LUMA = np.array([0.2126, 0.7152, 0.0722])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst"); ap.add_argument("--to", required=True)
    a = ap.parse_args()
    d = bytearray(open(a.src, "rb").read())
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    base = 20 + n + 8
    to = np.array([int(a.to[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0
    for mesh in j["meshes"]:
        for prim in mesh["primitives"]:
            acc = j["accessors"][prim["attributes"]["COLOR_0"]]
            assert acc["componentType"] == 5123 and acc["type"] == "VEC4", "chỉ hỗ trợ màu ushort RGBA"
            bv = j["bufferViews"][acc["bufferView"]]
            off = base + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            c = np.frombuffer(bytes(d[off:off + acc["count"] * 8]), np.uint16).reshape(-1, 4).astype(float) / 65535
            l = c[:, :3] @ LUMA
            c[:, :3] = to[None] * (l / max(l.mean(), 1e-4))[:, None]
            d[off:off + acc["count"] * 8] = (np.clip(c, 0, 1) * 65535).astype(np.uint16).tobytes()
    open(a.dst, "wb").write(bytes(d))
    print("→", a.dst)


if __name__ == "__main__":
    main()
