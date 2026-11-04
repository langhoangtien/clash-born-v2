#!/usr/bin/env python3
"""Gỡ áo choàng / vạt áo khỏi xương tay (D-244): gắn xương tự động (afk.ai) hay cho mép áo choàng bám tay → vung tay
là áo bị kéo thành dải dài như cánh. Đỉnh có trọng số tay mà cách đoạn xương tay (đòn vai → vai → khuỷu → cổ tay → bàn tay)
xa hơn `--dist` (m) thì phần trọng số tay chuyển sang xương thân theo độ cao (spine_03 / spine_02 / spine_01 /
pelvis) — áo chỉ đi theo thân. `--cloth-hue 250-320`: đỉnh bám tay có màu áo (sắc độ trên ảnh màu, đọc theo UV)
thì chuyển luôn dù gần tay hơn (> `--near`). Bộ xương và hoạt ảnh giữ nguyên.

  python3 -I tools/models/cloth_weights.py vào_afk.glb ra_afk.glb [--dist 0.10] [--cloth-hue 250-320 --near 0.03]
"""
import argparse, io, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as A  # noqa: E402

FINGERS = ("index", "middle", "ring", "pinky", "thumb")
TRUNK = ("spine_03", "spine_02", "spine_01", "pelvis")  # từ cao xuống thấp


def _segment_distance(x, a, b):
    ab = b - a
    t = np.clip(((x - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(x - (a + np.outer(t, ab)), axis=1)


def _cloth_mask(g, b, p, hue):
    """Đỉnh có màu áo: sắc độ (độ) trong khoảng `hue`, đủ đậm — đọc ảnh màu tại UV của đỉnh."""
    lo, hi = (float(v) for v in hue.split("-"))
    tex = g["materials"][p["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    bv = g["bufferViews"][g["images"][g["textures"][tex]["source"]]["bufferView"]]
    start = bv.get("byteOffset", 0)
    img = np.asarray(Image.open(io.BytesIO(bytes(b[start:start + bv["byteLength"]]))).convert("HSV"))
    uv = A.array(g, b, p["attributes"]["TEXCOORD_0"])
    px = np.clip((uv * [img.shape[1], img.shape[0]]).astype(int), 0, [img.shape[1] - 1, img.shape[0] - 1])
    hsv = img[px[:, 1], px[:, 0]].astype(np.float32)
    deg = hsv[:, 0] * 360.0 / 255.0
    return (deg >= lo) & (deg <= hi) & (hsv[:, 1] > 60) & (hsv[:, 2] > 40)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--dist", type=float, default=0.10)
    ap.add_argument("--cloth-hue", default="")
    ap.add_argument("--near", type=float, default=0.03)
    a = ap.parse_args()
    g, b = A.read(a.src)
    sk = g["skins"][0]
    names = [g["nodes"][j]["name"] for j in sk["joints"]]
    ibm = A.array(g, b, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    head = {n: np.linalg.inv(m)[:3, 3] for n, m in zip(names, ibm)}
    trunk = [(names.index(n), head[n][1]) for n in TRUNK]
    for mesh in g["meshes"]:
        for p in mesh["primitives"]:
            if "JOINTS_0" not in p["attributes"]:
                continue
            pos = A.array(g, b, p["attributes"]["POSITION"]).astype(np.float64)
            jo = A.array(g, b, p["attributes"]["JOINTS_0"])
            we = A.array(g, b, p["attributes"]["WEIGHTS_0"])
            cloth = _cloth_mask(g, b, p, a.cloth_hue) if a.cloth_hue else np.zeros(len(pos), bool)
            for side in "lr":
                h = [head[f"{n}_{side}"] for n in ("clavicle", "upperarm", "lowerarm", "hand")]
                tip = h[3] + (h[3] - h[2]) * 0.6
                dist = np.minimum.reduce([_segment_distance(pos, h[k], h[k + 1]) for k in range(3)]
                                         + [_segment_distance(pos, h[3], tip)])
                limb = [names.index(f"{n}_{side}") for n in ("clavicle", "upperarm", "lowerarm", "hand")]
                limb += [i for i, n in enumerate(names) if n.endswith("_" + side) and n.startswith(FINGERS)]
                moved = 0
                for v in np.nonzero((dist > a.dist) | (cloth & (dist > a.near)))[0]:
                    on = np.isin(jo[v], limb) & (we[v] > 0)
                    if not on.any():
                        continue
                    to = next((i for i, y in trunk if pos[v, 1] >= y), trunk[-1][0])
                    w = float(we[v][on].sum())
                    we[v][on] = 0.0
                    same = np.nonzero(jo[v] == to)[0]
                    slot = same[0] if len(same) else int(np.argmin(we[v]))
                    if not len(same):
                        jo[v][slot] = to
                        we[v][slot] = 0.0
                    we[v][slot] += w
                    we[v] /= max(we[v].sum(), 1e-9)
                    moved += 1
                print(f"tay {side}: {moved} đỉnh áo → thân")
    A.write(a.dst, g, A.prune(g, b))
    print("→", a.dst)


if __name__ == "__main__":
    main()
