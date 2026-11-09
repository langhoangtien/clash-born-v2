#!/usr/bin/env python3
"""Xoay cả mô hình quanh trục đứng (D-218): Tripo multiview cho mặt trước nhìn +X, game cần +Z (camera ở phía +Z).

  python3 -I tools/models/glb_yaw.py vào.glb ra.glb --deg -90     # −90: mặt +X → +Z
  [--scale k]: D-310 — nhân cỡ cả mô hình (vật cảnh vật đặt bằng MultiMesh cần cỡ thật theo mét)
Ghép phép xoay vào các nút gốc của cảnh; lưới / xương / hoạt ảnh giữ nguyên.
"""
import argparse, json, math, struct


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return [aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--deg", type=float, required=True)
    ap.add_argument("--scale", type=float, default=1.0)
    a = ap.parse_args()
    b = open(a.src, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    g = json.loads(b[20:20 + n])
    h = math.radians(a.deg) / 2
    q = [0.0, math.sin(h), 0.0, math.cos(h)]
    c, s = math.cos(2 * h), math.sin(2 * h)
    for i in g["scenes"][g.get("scene", 0)]["nodes"]:
        nd = g["nodes"][i]
        assert "matrix" not in nd, "nút dùng matrix: chưa hỗ trợ"
        nd["rotation"] = qmul(q, nd.get("rotation", [0, 0, 0, 1]))
        if "translation" in nd:
            x, y, z = nd["translation"]
            nd["translation"] = [(c * x + s * z) * a.scale, y * a.scale, (-s * x + c * z) * a.scale]
        if a.scale != 1.0:
            nd["scale"] = [v * a.scale for v in nd.get("scale", [1, 1, 1])]
    j = json.dumps(g, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    rest = b[20 + n:]
    open(a.dst, "wb").write(struct.pack("<III", 0x46546C67, 2, 20 + len(j) + len(rest)) +
                           struct.pack("<I", len(j)) + b"JSON" + j + rest)
    print(f"→ {a.dst}: xoay {a.deg:g}°, cỡ ×{a.scale:g}")


if __name__ == "__main__":
    main()
