#!/usr/bin/env python3
"""D-308: uốn một đoạn tường THẲNG (Tripo) thành cung tròn để ghép vòng tường bãi đấu.

  python3 -I tools/models/bend_arc.py vào.glb ra.glb --radius 4.8 --deg 45 [--height 0.8]

Chiều dài của tường (trục ngang dài nhất) trải đều theo cung `deg` độ ở bán kính `radius` (m, tâm vòng); cỡ phóng
đều sao cho chiều dài = độ dài cung. Kết quả: cung đối xứng quanh trục +X (giữa cung ở (radius, 0, 0)), mặt lõm quay
về tâm, đáy y = 0, đơn vị mét. UV giữ nguyên (ảnh màu không đổi). Chỉ hỗ trợ GLB một lưới, một nút không biến đổi.
"""
import argparse, json, math, struct
import numpy as np


def read(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    g = json.loads(d[20:20 + n])
    off = 20 + n
    bl = struct.unpack("<I", d[off:off + 4])[0]
    return g, bytearray(d[off + 8:off + 8 + bl])


def view(g, b, acc_i):
    a = g["accessors"][acc_i]
    bv = g["bufferViews"][a["bufferView"]]
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return o, np.frombuffer(bytes(b[o:o + a["count"] * 12]), np.float32).reshape(-1, 3).copy()


def write(path, g, b):
    g["buffers"][0]["byteLength"] = len(b)
    j = json.dumps(g, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    b = bytes(b) + b"\0" * (-len(b) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(b))
    out += struct.pack("<II", len(j), 0x4E4F534A) + j + struct.pack("<II", len(b), 0x004E4942) + b
    open(path, "wb").write(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--radius", type=float, default=4.8)
    ap.add_argument("--deg", type=float, default=45.0)
    ap.add_argument("--height", type=float, default=0.0, help="ép chiều cao (m); 0 = giữ tỉ lệ")
    a = ap.parse_args()
    g, b = read(a.src)
    assert len(g["meshes"]) == 1 and not any(k in g["nodes"][0] for k in ("matrix", "rotation", "scale", "translation"))
    prim = g["meshes"][0]["primitives"][0]
    po, pos = view(g, b, prim["attributes"]["POSITION"])
    no, nor = view(g, b, prim["attributes"]["NORMAL"])
    span = pos.max(0) - pos.min(0)
    long_ax, thick_ax = (2, 0) if span[2] >= span[0] else (0, 2)
    arc = a.radius * math.radians(a.deg)
    k = arc / span[long_ax]
    center = (pos.max(0) + pos.min(0)) / 2
    u = (pos[:, long_ax] - center[long_ax]) * k
    v = (pos[:, thick_ax] - center[thick_ax]) * k
    y = (pos[:, 1] - pos[:, 1].min()) * k
    if a.height > 0.0:
        y *= a.height / y.max()
        nor = nor * np.array([1.0, span[1] * k / y.max(), 1.0], np.float32)  # pháp tuyến khi ép dọc: nhân nghịch đảo
    th = u / a.radius
    r = a.radius + v
    out = np.stack([r * np.cos(th), y, r * np.sin(th)], 1).astype(np.float32)
    nu, nv = nor[:, long_ax], nor[:, thick_ax]  # pháp tuyến: (dọc, dày) → xoay theo góc cung
    n_out = np.stack([nv * np.cos(th) - nu * np.sin(th), nor[:, 1], nv * np.sin(th) + nu * np.cos(th)], 1)
    n_out /= np.maximum(1e-6, np.linalg.norm(n_out, axis=1, keepdims=True))
    b[po:po + out.nbytes] = out.tobytes()
    b[no:no + n_out.astype(np.float32).nbytes] = n_out.astype(np.float32).tobytes()
    acc = g["accessors"][prim["attributes"]["POSITION"]]
    acc["min"], acc["max"] = out.min(0).tolist(), out.max(0).tolist()
    write(a.dst, g, b)
    print(f"→ {a.dst}: cung {a.deg:g}° bán kính {a.radius} m, cao {y.max():.2f} m, dày {span[thick_ax] * k:.2f} m")


if __name__ == "__main__":
    main()
