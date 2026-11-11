"""D-351: ghép một nhánh xương của hoạt ảnh khác vào hoạt ảnh cho glb_anims.py (`A&B#xương=tên`).

Vd `Run_Female&Bow_Casual#clavicle_l=run`: chân + thân chạy theo A, cả nhánh tay trái (từ `clavicle_l` trở xuống) giữ
tư thế cầm cung của B. Chỉ chép góc xoay cục bộ của các xương trong nhánh; B (hoặc đoạn `B@đầu-cuối`) được co giãn cho
vừa đúng một vòng của A nên hoạt ảnh lặp vẫn khép vòng. `B@t-t` (đoạn dài 0): giữ nguyên một tư thế.
"""
import numpy as np
from glb_rig_ops import add_accessor, _span
from glb_mirror import _sample, FPS


def _subtree(g, root_name):
    root = next(i for i, n in enumerate(g["nodes"]) if n.get("name") == root_name)
    out, todo = [], [root]
    while todo:
        i = todo.pop()
        out.append(i)
        todo += g["nodes"][i].get("children", [])
    return set(out)


def _length(g, anim):
    return max(g["accessors"][s["input"]]["max"][0] for s in anim["samplers"])


def overlay(g, binc, array, anim, spec):
    """anim: hoạt ảnh A (đã cắt / nối); spec: `B[@đoạn]#xương_gốc_nhánh`."""
    other, bone = spec.split("#")
    src = next(a for a in g["animations"] if a.get("name") == other.split("@")[0])
    start, end = _span(other, _length(g, src))
    bones = _subtree(g, bone)
    length = _length(g, anim)
    times = np.arange(int(round(length * FPS)) + 1) / FPS
    times[-1] = length
    sampled = _sample(g, binc, array, src, start + times / max(length, 1e-6) * (end - start))
    kept = [c for c in anim["channels"] if not (c["target"]["node"] in bones and c["target"]["path"] == "rotation")]
    t_acc = add_accessor(g, binc, times[:, None], "SCALAR", True)
    for (node, path), values in sampled.items():
        if node in bones and path == "rotation":
            anim["samplers"].append({"input": t_acc, "output": add_accessor(g, binc, values, "VEC4"),
                                     "interpolation": "LINEAR"})
            kept.append({"sampler": len(anim["samplers"]) - 1, "target": {"node": node, "path": path}})
    anim["channels"] = kept
