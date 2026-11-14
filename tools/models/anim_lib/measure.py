#!/usr/bin/env python3
"""Đo lệch hoạt ảnh lấy từ kho so với hoạt ảnh afk trả cho chính tướng đích (D-398).

  python3 -I tools/models/anim_lib/measure.py nguồn_afk.glb đích_afk.glb --anims A,B,… --height 1.3

So từng khung: vị trí bàn tay / bàn chân (thế giới, đặt hai bản cùng gốc) → cm theo chiều cao trong game (--height m).
Chân: lún (thấp hơn đáy chân thấp nhất của bản gốc) và trượt (chân đang chạm đất mà vẫn dời ngang).
"""
import argparse, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as GA  # noqa: E402
import rig_math as RM  # noqa: E402

ENDS = ("hand_l", "hand_r", "foot_l", "foot_r")
CONTACT = 0.02  # m: chân cách đáy thấp nhất ≤ 2 cm coi là đang chạm đất


def model_height(g, binc):
    ys = [GA.array(g, binc, p["attributes"]["POSITION"])[:, 1] for m in g["meshes"] for p in m["primitives"]]
    return float(max(y.max() for y in ys) - min(y.min() for y in ys))


def anim(g, name):
    return next(a for a in g["animations"] if a.get("name") == name)


def foot_stats(wp, skel, m):
    """wp: (F,B,3) đã đổi ra m. Trả (đáy thấp nhất, trượt trung bình cm/khung khi chạm đất)."""
    low, slide = [], []
    for f in ("foot_l", "foot_r"):
        y = wp[:, skel.by_name[f], 1]
        low.append(y.min())
        on = y <= y.min() + CONTACT
        v = np.linalg.norm(np.diff(wp[:, skel.by_name[f], [0, 2]], axis=0), axis=1)
        both = on[1:] & on[:-1]
        slide.append(v[both].mean() * 100 if both.any() else 0.0)
    return min(low), float(np.mean(slide))


def copy_sampled(ss, ds, t, r):
    """Như apply_anims.copy_anim nhưng trên mảng đã lấy mẫu: chép xoay theo tên, dời = nguồn + (nghỉ đích − nghỉ nguồn)."""
    out_t, out_r = ds.rest(len(t))
    out_t, out_r = out_t.copy(), out_r.copy()
    for k, name in enumerate(ds.name):
        sk = ss.by_name.get(name)
        if sk is None or k == 0:
            continue
        out_r[:, k] = r[:, sk]
        if name in ("root", "pelvis"):
            out_t[:, k] = ds.rest_t[k] + (t[:, sk] - ss.rest_t[sk])
    return out_t, out_r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--anims", required=True); ap.add_argument("--height", type=float, required=True)
    ap.add_argument("--method", choices=("copy", "world"), default="copy")
    a = ap.parse_args()
    sg, sb = GA.read(a.src)
    dg, db = GA.read(a.dst)
    ss, ds = RM.Skeleton(sg), RM.Skeleton(dg)
    m = a.height / model_height(dg, db)  # m trên một đơn vị xương (cảnh không có tỉ lệ trên nút)
    print(f"{os.path.basename(a.src)} → {os.path.basename(a.dst)}: tỉ lệ hông {RM.hip_height(ds) / RM.hip_height(ss):.3f}, "
          f"1 đơn vị = {m:.3f} m")
    print("| hoạt ảnh | lệch tay TB / max cm | lệch chân TB / max cm | lún chân cm (gốc → kho) | trượt chân cm/khung (gốc → kho) |")
    for name in a.anims.split(","):
        times, t, r = RM.sample(sg, lambda i: GA.array(sg, sb, i), anim(sg, name), ss)
        lt, lr = copy_sampled(ss, ds, t, r) if a.method == "copy" else RM.retarget(ss, ds, t, r, scale=1.0)[:2]
        _, ot, orr = RM.sample(dg, lambda i: GA.array(dg, db, i), anim(dg, name), ds)
        n = min(len(ot), len(lt))
        wl, _ = ds.fk(lt[:n], lr[:n])
        wo, _ = ds.fk(ot[:n], orr[:n])
        wl, wo = wl * m, wo * m
        d = {e: np.linalg.norm(wl[:, ds.by_name[e]] - wo[:, ds.by_name[e]], axis=1) * 100 for e in ENDS}
        hand = np.concatenate([d["hand_l"], d["hand_r"]]); foot = np.concatenate([d["foot_l"], d["foot_r"]])
        lo_o, sl_o = foot_stats(wo, ds, m)
        lo_l, sl_l = foot_stats(wl, ds, m)
        print(f"| {name} | {hand.mean():.1f} / {hand.max():.1f} | {foot.mean():.1f} / {foot.max():.1f} | "
              f"{0.0:.1f} → {(lo_o - lo_l) * 100:+.1f} | {sl_o:.2f} → {sl_l:.2f} |")


if __name__ == "__main__":
    main()
